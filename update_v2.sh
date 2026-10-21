#!/usr/bin/env bash
set -e

echo "🔄 Updating Bongotrader to V3 (Indicators & Drawing Fixes)..."

write() { echo "📝 Updating $1"; }

# ========== 1. App Store (Indicators State) ==========
write "store/useAppStore.ts"
cat > store/useAppStore.ts << 'EOF'
'use client';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Theme = 'light' | 'dark';
type Lang = 'en' | 'bn';
type ChartType = 'candlestick' | 'line' | 'area' | 'bar';

interface AppState {
  theme: Theme; lang: Lang; activeSymbol: string;
  timeframe: 'D' | 'W' | 'M' | 'Q' | 'Y';
  chartType: ChartType;
  feePct: number;
  activeIndicators: { volume: boolean; ema: boolean; bb: boolean; rsi: boolean };
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  setLang: (l: Lang) => void;
  setSymbol: (s: string) => void;
  setTimeframe: (t: AppState['timeframe']) => void;
  setChartType: (t: ChartType) => void;
  setFee: (f: number) => void;
  toggleIndicator: (ind: keyof AppState['activeIndicators']) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', chartType: 'candlestick', feePct: 0.15,
  activeIndicators: { volume: false, ema: false, bb: false, rsi: false },
  setTheme: (t) => set({ theme: t }),
  toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
  setLang: (l) => set({ lang: l }),
  setSymbol: (s) => set({ activeSymbol: s }),
  setTimeframe: (t) => set({ timeframe: t }),
  setChartType: (t) => set({ chartType: t }),
  setFee: (f) => set({ feePct: f }),
  toggleIndicator: (ind) => set((s) => ({ activeIndicators: { ...s.activeIndicators, [ind]: !s.activeIndicators[ind] } })),
}), { name: 'bongotrader-app' }));
EOF

# ========== 2. Chart Toolbar (Indicator Dropdown) ==========
write "components/ChartToolbar.tsx"
cat > components/ChartToolbar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { CandlestickChart, LineChart, AreaChart, BarChart3, Layers } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';

const TFS = [{ v: 'D', l: 'D' }, { v: 'W', l: 'W' }, { v: 'M', l: 'M' }, { v: 'Q', l: 'Q' }, { v: 'Y', l: 'Y' }] as const;

export default function ChartToolbar() {
  const { timeframe, setTimeframe, chartType, setChartType, activeIndicators, toggleIndicator } = useAppStore();
  const [showInd, setShowInd] = useState(false);

  return (
    <div className="flex items-center gap-2 flex-wrap p-2 border-b border-[color:var(--border)] relative z-20">
      <div className="flex rounded-lg border border-[color:var(--border)] overflow-hidden">
        {TFS.map((t) => (
          <button key={t.v} onClick={() => setTimeframe(t.v)} className={`px-2.5 py-1 text-xs ${timeframe === t.v ? 'bg-[color:var(--accent)] text-white' : 'hover:bg-[color:var(--muted)]/10'}`}>{t.l}</button>
        ))}
      </div>
      
      <div className="flex gap-1 ml-2">
        {(['candlestick', 'line', 'area', 'bar'] as const).map((type) => {
          const Icon = type === 'candlestick' ? CandlestickChart : type === 'line' ? LineChart : type === 'area' ? AreaChart : BarChart3;
          return (
            <button key={type} onClick={() => setChartType(type)} title={type}
              className={`p-1.5 rounded-lg border ${chartType === type ? 'bg-[color:var(--accent)] text-white border-[color:var(--accent)]' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'}`}>
              <Icon size={14} />
            </button>
          );
        })}
      </div>

      <div className="flex gap-1 ml-auto relative">
        <button onClick={() => setShowInd(!showInd)} className={`flex items-center gap-1 px-2 py-1.5 rounded-lg border ${showInd ? 'bg-[color:var(--muted)]/20' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'}`}>
          <Layers size={14} /> <span className="text-xs font-medium">Indicators</span>
        </button>
        
        {showInd && (
          <div className="absolute right-0 top-full mt-2 w-40 card p-2 z-50 shadow-xl flex flex-col gap-1">
            {Object.entries(activeIndicators).map(([key, val]) => (
              <label key={key} className="flex items-center gap-2 text-xs p-1 hover:bg-[color:var(--muted)]/10 rounded cursor-pointer">
                <input type="checkbox" checked={val} onChange={() => toggleIndicator(key as any)} className="accent-[color:var(--accent)]" />
                <span className="uppercase">{key}</span>
              </label>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
EOF

# ========== 3. Chart Panel (Apply Indicators) ==========
write "components/ChartPanel.tsx"
cat > components/ChartPanel.tsx << 'EOF'
'use client';
import { useEffect, useRef } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';
import { ema, bollinger, rsi } from '@/lib/strategy/indicators';

export default function ChartPanel() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const seriesRef = useRef<ISeriesApi<any> | null>(null);
  const indSeriesRef = useRef<ISeriesApi<any>[]>([]);
  
  const { activeSymbol: symbol, timeframe: tf, theme, chartType, activeIndicators } = useAppStore();

  const { data, isLoading, error } = useQuery({
    queryKey: ['ohlcv', symbol, tf],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=${tf}&limit=500`);
      if (!r.ok) throw new Error('failed');
      const j = await r.json();
      const raw = (j.data as any[]) || [];
      const parsed = raw.map((d) => {
        const t = new Date(d.date).getTime();
        return { time: Math.floor(t / 1000) as any, open: Number(d.open), high: Number(d.high), low: Number(d.low), close: Number(d.close), volume: Number(d.volume || 0), value: Number(d.close) };
      }).filter((d) => !isNaN(d.time));
      const uniqueMap = new Map();
      parsed.forEach((item) => uniqueMap.set(item.time, item));
      return Array.from(uniqueMap.values()).sort((a, b) => a.time - b.time);
    },
  });

  // Init Chart
  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: { background: { type: ColorType.Solid, color: 'transparent' }, textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540', fontFamily: 'ui-sans-serif' },
      grid: { vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' }, horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' } },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 5, barSpacing: 8 },
      autoSize: true,
    });
    chartRef.current = chart;
    chartRefs.chart = chart;
    return () => { chart.remove(); chartRefs.chart = null; chartRefs.series = null; };
  }, []);

  // Handle Data, Chart Type & Indicators
  useEffect(() => {
    if (!chartRef.current || !data) return;
    const chart = chartRef.current;
    
    // Cleanup old series
    if (seriesRef.current) chart.removeSeries(seriesRef.current);
    indSeriesRef.current.forEach(s => chart.removeSeries(s));
    indSeriesRef.current = [];

    // Main Series
    const opts = { upColor: '#16A34A', downColor: '#DC2626', wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false };
    let series;
    if (chartType === 'line') series = chart.addLineSeries({ color: '#1E6FD9', lineWidth: 2 });
    else if (chartType === 'area') series = chart.addAreaSeries({ lineColor: '#1E6FD9', topColor: 'rgba(30,111,217,0.4)', bottomColor: 'rgba(30,111,217,0.0)' });
    else if (chartType === 'bar') series = chart.addBarSeries({ upColor: '#16A34A', downColor: '#DC2626' });
    else series = chart.addCandlestickSeries(opts);

    series.setData(data);
    seriesRef.current = series;
    chartRefs.series = series as any;

    // Indicators
    const closes = data.map(d => d.close);

    if (activeIndicators.volume) {
      const volSeries = chart.addHistogramSeries({ priceFormat: { type: 'volume' }, priceScaleId: 'vol', color: '#26a69a' });
      volSeries.priceScale().applyOptions({ scaleMargins: { top: 0.8, bottom: 0 } });
      volSeries.setData(data.map(d => ({ time: d.time, value: d.volume, color: d.close >= d.open ? '#16A34A' : '#DC2626' })));
      indSeriesRef.current.push(volSeries);
    }

    if (activeIndicators.ema) {
      const e20 = ema(closes, 20);
      const e50 = ema(closes, 50);
      const s20 = chart.addLineSeries({ color: '#F59E0B', lineWidth: 2, priceScaleId: 'right' });
      s20.setData(data.map((d, i) => ({ time: d.time, value: e20[i] ?? 0 })).filter(d => d.value > 0));
      const s50 = chart.addLineSeries({ color: '#8B5CF6', lineWidth: 2, priceScaleId: 'right' });
      s50.setData(data.map((d, i) => ({ time: d.time, value: e50[i] ?? 0 })).filter(d => d.value > 0));
      indSeriesRef.current.push(s20, s50);
    }

    if (activeIndicators.bb) {
      const bb = bollinger(closes, 20, 2);
      const bbU = chart.addLineSeries({ color: 'rgba(30,111,217,0.5)', lineWidth: 1, priceScaleId: 'right' });
      bbU.setData(data.map((d, i) => ({ time: d.time, value: bb.upper[i] ?? 0 })).filter(d => d.value > 0));
      const bbL = chart.addLineSeries({ color: 'rgba(30,111,217,0.5)', lineWidth: 1, priceScaleId: 'right' });
      bbL.setData(data.map((d, i) => ({ time: d.time, value: bb.lower[i] ?? 0 })).filter(d => d.value > 0));
      indSeriesRef.current.push(bbU, bbL);
    }

    if (activeIndicators.rsi) {
      const r = rsi(closes, 14);
      const rsiSeries = chart.addLineSeries({ color: '#06B6D4', lineWidth: 2, priceScaleId: 'rsi' });
      rsiSeries.priceScale().applyOptions({ scaleMargins: { top: 0.6, bottom: 0.2 } });
      rsiSeries.setData(data.map((d, i) => ({ time: d.time, value: r[i] ?? 50 })).filter(d => d.value !== null));
      indSeriesRef.current.push(rsiSeries);
    }

    chart.timeScale().scrollToRealTime();
  }, [data, chartType, activeIndicators]);

  // Theme
  useEffect(() => {
    chartRef.current?.applyOptions({
      layout: { textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540' },
      grid: { vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' }, horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' } },
    });
  }, [theme]);

  return (
    <div className="chart-pane w-full h-[480px]">
      {isLoading && <div className="absolute inset-0 grid place-items-center text-[color:var(--muted)] z-20">Loading…</div>}
      {error && <div className="absolute inset-0 grid place-items-center text-[color:var(--bear)] z-20">Error</div>}
      <div ref={containerRef} className="w-full h-full" />
      <DrawingCanvas />
    </div>
  );
}
EOF

# ========== 4. Drawing Canvas (Fix dragging & Text) ==========
write "components/DrawingCanvas.tsx"
cat > components/DrawingCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { chartRefs } from '@/lib/chartInstance';
import { useDrawingsStore } from '@/store/useDrawingsStore';
import { useAppStore } from '@/store/useAppStore';
import type { Drawing } from '@/lib/drawing/types';
import { X } from 'lucide-react';

const COL = { bull: '#16A34A', bear: '#DC2626', accent: '#1E6FD9', select: '#F59E0B' };
const uid = () => Math.random().toString(36).slice(2, 10);

export default function DrawingCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { tool, drawings, add, update, select, selectedId } = useDrawingsStore();
  const theme = useAppStore((s) => s.theme);
  
  const drawingsRef = useRef(drawings); drawingsRef.current = drawings;
  const toolRef = useRef(tool); toolRef.current = tool;
  const dragRef = useRef<{ id: string; a0: any; b0?: any } | null>(null);
  const drawRef = useRef<{ tool: any; a: any; b: any } | null>(null);

  // Modal states
  const [showTextModal, setShowTextModal] = useState(false);
  const [pendingTextPos, setPendingTextPos] = useState<any>(null);
  const [inputText, setInputText] = useState('');

  const toTimePrice = (x: number, y: number) => {
    const { chart, series } = chartRefs;
    if (!chart || !series) return null;
    const time = chart.timeScale().coordinateToTime(x);
    const price = series.coordinateToPrice(y);
    if (time == null || price == null) return null;
    let t = 0;
    if (typeof time === 'number') t = time;
    else if (typeof time === 'object' && 'year' in time) {
      t = Math.floor(Date.UTC((time as any).year, (time as any).month - 1, (time as any).day) / 1000);
    } else return null;
    return { time: t, price };
  };

  const toXY = (time: number, price: number) => {
    const { chart, series } = chartRefs;
    if (!chart || !series) return null;
    const x = chart.timeScale().timeToCoordinate(time as any);
    const y = series.priceToCoordinate(price);
    if (x == null || y == null) return null;
    return { x, y };
  };

  const render = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const parent = canvas.parentElement!;
    const dpr = window.devicePixelRatio || 1;
    const w = parent.clientWidth, h = parent.clientHeight;
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr; canvas.height = h * dpr;
      canvas.style.width = w + 'px'; canvas.style.height = h + 'px';
    }
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const all = drawRef.current ? [...drawingsRef.current, { ...drawRef.current, id: '__tmp__' } as any] : drawingsRef.current;
    for (const d of all) drawOne(ctx, d);
  };

  const drawOne = (ctx: CanvasRenderingContext2D, d: Drawing) => {
    const a = toXY(d.a.time, d.a.price);
    if (!a) return;
    const isSel = d.id === selectedId;
    const stroke = isSel ? COL.select : (d.tool === 'sell' || d.tool === 'redbox' ? COL.bear : d.tool === 'buy' || d.tool === 'greenbox' ? COL.bull : COL.accent);

    if (d.tool === 'hline') {
      ctx.strokeStyle = stroke; ctx.lineWidth = isSel ? 2.5 : 1.5;
      ctx.beginPath(); ctx.moveTo(0, a.y); ctx.lineTo(ctx.canvas.width, a.y); ctx.stroke();
      ctx.fillStyle = stroke; ctx.font = '11px ui-monospace'; ctx.fillText(`৳${d.a.price.toFixed(2)}`, 6, a.y - 4);
      return;
    }
    if (d.tool === 'text') {
      ctx.font = 'bold 13px ui-sans-serif';
      const tw = ctx.measureText(d.text ?? '').width;
      // Yellow background for visibility
      ctx.fillStyle = '#F59E0B'; ctx.fillRect(a.x - 4, a.y - 16, tw + 8, 20);
      ctx.fillStyle = '#000'; ctx.fillText(d.text ?? '', a.x, a.y - 2);
      if (isSel) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 1.5; ctx.strokeRect(a.x - 5, a.y - 17, tw + 10, 22); }
      return;
    }
    if (d.tool === 'buy' || d.tool === 'sell') {
      const txt = `${d.tool === 'buy' ? 'BUY' : 'SELL'} @ ৳${d.a.price.toFixed(2)}`;
      ctx.font = 'bold 11px ui-sans-serif';
      const pw = ctx.measureText(txt).width + 14;
      ctx.fillStyle = d.tool === 'buy' ? COL.bull : COL.bear;
      roundRect(ctx, a.x - pw / 2, a.y - 22, pw, 18, 4); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.fillText(txt, a.x - pw / 2 + 7, a.y - 9);
      if (isSel) { ctx.strokeStyle = COL.select; ctx.lineWidth = 1.5; roundRect(ctx, a.x - pw / 2 - 1, a.y - 23, pw + 2, 20, 4); ctx.stroke(); }
      return;
    }
    if (!d.b) return;
    const b = toXY(d.b.time, d.b.price);
    if (!b) return;
    if (d.tool === 'trendline') {
      ctx.strokeStyle = stroke; ctx.lineWidth = isSel ? 2.5 : 1.5;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      if (isSel) {
        ctx.fillStyle = COL.select;
        ctx.beginPath(); ctx.arc(a.x, a.y, 4, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(b.x, b.y, 4, 0, Math.PI * 2); ctx.fill();
      }
      return;
    }
    if (d.tool === 'greenbox' || d.tool === 'redbox') {
      const x = Math.min(a.x, b.x), y = Math.min(a.y, b.y);
      const w = Math.abs(b.x - a.x), h = Math.abs(b.y - a.y);
      ctx.fillStyle = d.tool === 'greenbox' ? 'rgba(22,163,74,0.18)' : 'rgba(220,38,38,0.18)';
      ctx.strokeStyle = stroke; ctx.lineWidth = isSel ? 2 : 1;
      ctx.fillRect(x, y, w, h); ctx.strokeRect(x, y, w, h);
    }
  };

  // CONTINUOUS RENDERING LOOP (Fixes chart drag issue)
  useEffect(() => {
    let animId: number;
    const loop = () => {
      render();
      animId = requestAnimationFrame(loop);
    };
    animId = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(animId);
  }, []);

  const hitTest = (x: number, y: number): Drawing | null => {
    for (let i = drawingsRef.current.length - 1; i >= 0; i--) {
      const d = drawingsRef.current[i];
      const a = toXY(d.a.time, d.a.price); if (!a) continue;
      if (d.tool === 'hline' && Math.abs(y - a.y) < 8) return d;
      if ((d.tool === 'text' || d.tool === 'buy' || d.tool === 'sell') && Math.abs(x - a.x) < 40 && Math.abs(y - a.y) < 20) return d;
      if (d.b) {
        const b = toXY(d.b.time, d.b.price); if (!b) continue;
        if (d.tool === 'trendline') {
          const dx = b.x - a.x, dy = b.y - a.y, len2 = dx * dx + dy * dy;
          const t = Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / (len2 || 1)));
          if (Math.hypot(x - (a.x + t * dx), y - (a.y + t * dy)) < 8) return d;
        }
        if (d.tool === 'greenbox' || d.tool === 'redbox') {
          if (x >= Math.min(a.x, b.x) && x <= Math.max(a.x, b.x) && y >= Math.min(a.y, b.y) && y <= Math.max(a.y, b.y)) return d;
        }
      }
    }
    return null;
  };

  useEffect(() => {
    const el = canvasRef.current?.parentElement;
    if (!el) return;

    const onDown = (e: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left, y = e.clientY - rect.top;
      const t = toolRef.current;

      if (t === 'select') {
        const hit = hitTest(x, y);
        if (!hit) { select(null); return; } // Let chart pan
        e.preventDefault(); e.stopPropagation();
        select(hit.id);
        dragRef.current = { id: hit.id, a0: { ...hit.a }, b0: hit.b ? { ...hit.b } : undefined };
        el.addEventListener('pointermove', onMove);
        el.addEventListener('pointerup', onUp);
        return;
      }
      
      // Stop chart from panning when using drawing tools
      e.preventDefault(); e.stopPropagation();
      
      const tp = toTimePrice(x, y);
      if (!tp || isNaN(tp.time) || isNaN(tp.price)) return;
      
      if (t === 'text') {
        setPendingTextPos(tp);
        setInputText('');
        setShowTextModal(true);
        return;
      }
      drawRef.current = { tool: t, a: tp, b: tp };
      el.addEventListener('pointermove', onMove);
      el.addEventListener('pointerup', onUp);
    };

    const onMove = (e: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left, y = e.clientY - rect.top;
      if (drawRef.current) {
        const tp = toTimePrice(x, y);
        if (tp) drawRef.current.b = tp;
      } else if (dragRef.current) {
        const tp = toTimePrice(x, y);
        if (!tp) return;
        const { id, a0, b0 } = dragRef.current;
        const dT = tp.time - a0.time, dP = tp.price - a0.price;
        update(id, { a: { time: a0.time + dT, price: a0.price + dP }, b: b0 ? { time: b0.time + dT, price: b0.price + dP } : undefined });
      }
    };

    const onUp = () => {
      if (drawRef.current) {
        const { tool: t, a, b } = drawRef.current;
        if (['trendline', 'greenbox', 'redbox'].includes(t)) {
          if (a.time !== b.time || a.price !== b.price) add({ id: uid(), tool: t, a, b });
        } else { add({ id: uid(), tool: t, a }); }
        drawRef.current = null;
      }
      dragRef.current = null;
      el.removeEventListener('pointermove', onMove);
      el.removeEventListener('pointerup', onUp);
    };

    el.addEventListener('pointerdown', onDown, { capture: true });
    return () => { el.removeEventListener('pointerdown', onDown, { capture: true }); el.removeEventListener('pointermove', onMove); el.removeEventListener('pointerup', onUp); };
  }, [add, update, select]);

  const saveText = () => {
    if (inputText.trim() && pendingTextPos) {
      add({ id: uid(), tool: 'text', a: pendingTextPos, text: inputText.trim() });
    }
    setShowTextModal(false);
  };

  return (
    <>
      <canvas ref={canvasRef} className="absolute inset-0 z-10" style={{ pointerEvents: 'none', cursor: tool === 'select' ? 'default' : 'crosshair' }} />
      
      {showTextModal && (
        <div className="absolute inset-0 z-50 bg-black/50 flex items-center justify-center backdrop-blur-sm">
          <div className="card p-4 w-72 shadow-2xl relative">
            <button onClick={() => setShowTextModal(false)} className="absolute top-2 right-2 text-[color:var(--muted)] hover:text-[color:var(--text)]"><X size={16}/></button>
            <h3 className="font-semibold mb-3">Add Text</h3>
            <input autoFocus value={inputText} onChange={(e) => setInputText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && saveText()} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm mb-3" placeholder="Enter note..." />
            <div className="flex justify-end gap-2">
              <button onClick={() => setShowTextModal(false)} className="px-3 py-1.5 text-xs rounded border border-[color:var(--border)]">Cancel</button>
              <button onClick={saveText} className="px-3 py-1.5 text-xs rounded bg-[color:var(--accent)] text-white">Add</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}
EOF

echo ""
echo "✅ V3 Update applied!"
echo "1. Stop the server (Ctrl+C) and run: npm run dev"
echo "2. Refresh your browser."