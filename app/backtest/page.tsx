'use client';
import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Play, Pause, StepForward, RotateCcw } from 'lucide-react';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import InstrumentPicker from '@/components/InstrumentPicker';
import StrategyBuilder from '@/components/StrategyBuilder';
import ReplayChart from '@/components/ReplayChart';
import ReplayMetrics from '@/components/ReplayMetrics';
import TradeLog from '@/components/TradeLog';
import { useAppStore } from '@/store/useAppStore';
import { useStrategyStore } from '@/store/useStrategyStore';
import { evaluateStrategy } from '@/lib/strategy/evaluator';

const SPEEDS = [0.5, 1, 2, 5, 10, 15, 20, 30, 40, 50] as const;

export default function BacktestPage() {
  const symbol = useAppStore((s) => s.activeSymbol);
  const [cursor, setCursor] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const strategy = useStrategyStore((s) => s.current);

  const { data: rawBars = [] } = useQuery({
    queryKey: ['ohlcv-replay', symbol],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=D&limit=2000`);
      const j = await r.json();
      return (j.data as any[]).map((d) => ({ dateStr: d.date, time: Math.floor(new Date(d.date).getTime() / 1000), open: Number(d.open), high: Number(d.high), low: Number(d.low), close: Number(d.close), volume: Number(d.volume ?? 0) })).filter((d) => !isNaN(d.time));
    },
  });

  const bars = useMemo(() => {
    let filtered = rawBars;
    if (startDate) filtered = filtered.filter(b => b.dateStr >= startDate);
    if (endDate) filtered = filtered.filter(b => b.dateStr <= endDate);
    return filtered.sort((a, b) => a.time - b.time);
  }, [rawBars, startDate, endDate]);

  const { trades: allTrades, equity } = useMemo(() => {
    if (!bars.length) return { trades: [], equity: [] };
    return evaluateStrategy(strategy, symbol, bars);
  }, [bars, strategy, symbol]);

  useEffect(() => { setCursor(0); setPlaying(false); }, [symbol, bars.length, startDate, endDate]);

  useEffect(() => {
    if (!playing) return;
    const id = setInterval(() => {
      setCursor((c) => (c >= bars.length - 1 ? (setPlaying(false), c) : c + 1));
    }, 400 / speed);
    return () => clearInterval(id);
  }, [playing, speed, bars.length]);

  const visibleMarkers = useMemo(() => {
    const cutTime = bars[cursor]?.time ?? 0;
    return allTrades.filter((t) => t.time <= cutTime).map((t) => ({
      time: t.time, side: t.side,
      text: t.side === 'BUY' ? `BUY ${t.qty} @ ৳${t.price.toFixed(2)}` : `SELL ${t.qty} @ ৳${t.price.toFixed(2)}${t.pnl != null ? ` (PnL ৳${t.pnl.toFixed(0)})` : ''}`,
    }));
  }, [allTrades, bars, cursor]);

  const liveMetrics = useMemo(() => {
    if (!bars.length) return null;
    const cutTime = bars[cursor].time;
    const closed = allTrades.filter((t) => t.side === 'SELL' && (t.exitTime ?? t.time) <= cutTime);
    const buys = allTrades.filter((t) => t.side === 'BUY' && t.time <= cutTime);
    const open = buys.find((b) => !closed.find((c) => c.time === b.time));
    const posQty = open ? open.qty : 0;
    const cash = strategy.capital - buys.reduce((s, b) => s + b.qty * b.price + b.fee, 0) + closed.reduce((s, c) => s + c.qty * c.price - c.fee, 0);
    const realised = closed.reduce((s, c) => s + (c.pnl ?? 0), 0);
    const eqNow = cash + posQty * bars[cursor].close;
    const peak = Math.max(...equity.slice(0, cursor + 1), strategy.capital);
    const rets = closed.map((c) => c.pnlPct ?? 0);
    const mean = rets.reduce((s, r) => s + r, 0) / (rets.length || 1);
    const std = Math.sqrt(rets.reduce((s, r) => s + (r - mean) ** 2, 0) / (rets.length || 1)) || 1e-9;
    return {
      time: bars[cursor].time, equity: eqNow, cash, position: posQty, realised, unrealised: posQty ? (bars[cursor].close - (open?.price ?? 0)) * posQty : 0,
      drawdown: peak > 0 ? ((peak - eqNow) / peak) * 100 : 0, winRate: closed.length ? (closed.filter(c => (c.pnl ?? 0) > 0).length / closed.length) * 100 : 0,
      sharpe: (mean / std) * Math.sqrt(252), trades: closed.length,
    };
  }, [bars, cursor, allTrades, equity, strategy.capital]);

  return (
    <>
      <TopBar />
      <main className="grid grid-cols-1 md:grid-cols-[280px_1fr] gap-3 p-3 pb-20">
        <aside className="card p-2 order-2 md:order-1"><InstrumentPicker /></aside>
        <section className="space-y-3 order-1 md:order-2">
          <div className="card p-3"><StrategyBuilder /></div>
          
          <div className="card p-2">
            <div className="flex items-center gap-2 flex-wrap pb-2 border-b border-[color:var(--border)]">
              <button onClick={() => setPlaying(!playing)} className="p-2 rounded-lg bg-[color:var(--accent)] text-white">{playing ? <Pause size={14} /> : <Play size={14} />}</button>
              <button onClick={() => setCursor((c) => Math.min(c + 1, bars.length - 1))} className="p-2 rounded-lg border border-[color:var(--border)]"><StepForward size={14} /></button>
              <button onClick={() => { setCursor(0); setPlaying(false); }} className="p-2 rounded-lg border border-[color:var(--border)]"><RotateCcw size={14} /></button>
              <select value={speed} onChange={(e) => setSpeed(Number(e.target.value))} className="bg-transparent border border-[color:var(--border)] rounded-lg px-2 py-1 text-xs">
                {SPEEDS.map((s) => <option key={s} value={s} className="bg-[color:var(--bg)]">{s}×</option>)}
              </select>
              
              <div className="flex gap-2 items-center ml-4 text-xs">
                <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="bg-transparent border border-[color:var(--border)] rounded px-2 py-1" />
                <span>to</span>
                <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="bg-transparent border border-[color:var(--border)] rounded px-2 py-1" />
              </div>

              <span className="text-xs text-[color:var(--muted)] tabular-nums ml-auto">bar {cursor + 1} / {bars.length}</span>
            </div>
            <ReplayChart bars={bars} cursor={cursor} markers={visibleMarkers} />
          </div>
          <div className="card p-3">{liveMetrics && <ReplayMetrics {...liveMetrics} />}</div>
          <div className="card p-3"><TradeLog trades={allTrades} /></div>
        </section>
      </main>
      <BottomTabs />
    </>
  );
}
