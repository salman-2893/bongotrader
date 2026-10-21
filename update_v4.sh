#!/usr/bin/env bash
set -e

echo "🚀 Updating Chartbongo to V5 (Indicators, Paper Trading, Fixes)..."

write() { echo "📝 Updating $1"; }

# ========== 1. Store (Indicators & Paper Trading) ==========
write "store/useAppStore.ts"
cat > store/useAppStore.ts << 'EOF'
'use client';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Theme = 'light' | 'dark'; type Lang = 'en' | 'bn'; type ChartType = 'candlestick' | 'line' | 'area' | 'bar';
export type IndicatorInstance = { id: string; type: string; period: number; color: string; };

interface AppState {
  theme: Theme; lang: Lang; activeSymbol: string;
  timeframe: 'D' | 'W' | 'M' | 'Q' | 'Y';
  chartType: ChartType;
  feePct: number;
  indicators: IndicatorInstance[];
  paperCash: number;
  paperHoldings: Record<string, { qty: number; avg: number }>;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  setLang: (l: Lang) => void;
  setSymbol: (s: string) => void;
  setTimeframe: (t: AppState['timeframe']) => void;
  setChartType: (t: ChartType) => void;
  setFee: (f: number) => void;
  addIndicator: (ind: IndicatorInstance) => void;
  removeIndicator: (id: string) => void;
  executeTrade: (type: 'BUY'|'SELL', price: number, qty: number) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', chartType: 'candlestick', feePct: 0.15,
  indicators: [], paperCash: 1000000, paperHoldings: {},
  
  setTheme: (t) => set({ theme: t }),
  toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
  setLang: (l) => set({ lang: l }),
  setSymbol: (s) => set({ activeSymbol: s }),
  setTimeframe: (t) => set({ timeframe: t }),
  setChartType: (t) => set({ chartType: t }),
  setFee: (f) => set({ feePct: f }),
  
  addIndicator: (ind) => set((s) => ({ indicators: [...s.indicators, ind] })),
  removeIndicator: (id) => set((s) => ({ indicators: s.indicators.filter(i => i.id !== id) })),
  
  executeTrade: (type, price, qty) => set((s) => {
    const cost = price * qty;
    const fee = cost * (s.feePct / 100);
    if (type === 'BUY') {
      if (s.paperCash < cost + fee) return s; // Insufficient funds
      const current = s.paperHoldings[s.activeSymbol] || { qty: 0, avg: 0 };
      const newQty = current.qty + qty;
      const newAvg = ((current.qty * current.avg) + cost) / newQty;
      return {
        paperCash: s.paperCash - cost - fee,
        paperHoldings: { ...s.paperHoldings, [s.activeSymbol]: { qty: newQty, avg: newAvg } }
      };
    } else {
      const current = s.paperHoldings[s.activeSymbol] || { qty: 0, avg: 0 };
      if (current.qty < qty) return s; // Not enough shares
      const newQty = current.qty - qty;
      const newHoldings = { ...s.paperHoldings };
      if (newQty === 0) delete newHoldings[s.activeSymbol];
      else newHoldings[s.activeSymbol] = { ...current, qty: newQty };
      return { paperCash: s.paperCash + cost - fee, paperHoldings: newHoldings };
    }
  }),
}), { name: 'chartbongo-app' }));
EOF

# ========== 2. Indicator Engine (Dynamic) ==========
write "lib/indicators/engine.ts"
cat > lib/indicators/engine.ts << 'EOF'
import * as ti from 'technicalindicators';

export const INDICATOR_DEFS = [
  { type: 'SMA', name: 'Simple Moving Average', defaultPeriod: 20, isOscillator: false, color: '#F59E0B' },
  { type: 'EMA', name: 'Exponential Moving Average', defaultPeriod: 20, isOscillator: false, color: '#8B5CF6' },
  { type: 'WMA', name: 'Weighted Moving Average', defaultPeriod: 20, isOscillator: false, color: '#EC4899' },
  { type: 'BB', name: 'Bollinger Bands', defaultPeriod: 20, isOscillator: false, color: '#3B82F6' },
  { type: 'RSI', name: 'Relative Strength Index', defaultPeriod: 14, isOscillator: true, color: '#06B6D4' },
  { type: 'MACD', name: 'MACD', defaultPeriod: 26, isOscillator: true, color: '#10B981' },
  { type: 'OBV', name: 'On Balance Volume', defaultPeriod: 0, isOscillator: true, color: '#F43F5E' },
  { type: 'STOCH', name: 'Stochastic', defaultPeriod: 14, isOscillator: true, color: '#D946EF' },
  { type: 'ADX', name: 'ADX', defaultPeriod: 14, isOscillator: true, color: '#64748B' },
  { type: 'ATR', name: 'Average True Range', defaultPeriod: 14, isOscillator: true, color: '#EAB308' },
  { type: 'CCI', name: 'Commodity Channel Index', defaultPeriod: 20, isOscillator: true, color: '#14B8A6' },
  { type: 'MFI', name: 'Money Flow Index', defaultPeriod: 14, isOscillator: true, color: '#F97316' },
];

export function calcIndicator(candles: any[], type: string, period: number) {
  const c = candles.map(x => x.close);
  const h = candles.map(x => x.high);
  const l = candles.map(x => x.low);
  const o = candles.map(x => x.open);
  const v = candles.map(x => x.volume || 0);
  
  let res: any[] = [];
  try {
    switch(type) {
      case 'SMA': res = ti.sma({ period, values: c }); break;
      case 'EMA': res = ti.ema({ period, values: c }); break;
      case 'WMA': res = ti.wma({ period, values: c }); break;
      case 'RSI': res = ti.rsi({ period, values: c }); break;
      case 'BB': 
        const bb = ti.bollingerbands({ period, stdDev: 2, values: c });
        return { upper: pad(bb.map(b=>b.upper), candles.length), mid: pad(bb.map(b=>b.middle), candles.length), lower: pad(bb.map(b=>b.lower), candles.length) };
      case 'MACD': res = ti.macd({ values: c, fastPeriod: 12, slowPeriod: 26, signalPeriod: 9 }).map(m => m.histogram); break;
      case 'OBV': res = ti.obv({ close: c, volume: v }); break;
      case 'STOCH': res = ti.stochastic({ high: h, low: l, close: c, period, signalPeriod: 3 }).map(s => s.k); break;
      case 'ADX': res = ti.adx({ high: h, low: l, close: c, period }).map(a => a.adx); break;
      case 'ATR': res = ti.atr({ high: h, low: l, close: c, period }); break;
      case 'CCI': res = ti.cci({ high: h, low: l, close: c, period }); break;
      case 'MFI': res = ti.mfi({ high: h, low: l, close: c, volume: v, period }); break;
      default: res = [];
    }
  } catch (e) { console.error(e); return []; }
  
  return pad(res, candles.length);
}

function pad(arr: any[], len: number) {
  if (arr.length >= len) return arr.slice(-len);
  return Array(len - arr.length).fill(null).concat(arr);
}
EOF

# ========== 3. Chart Toolbar (Indicator Search & Add) ==========
write "components/ChartToolbar.tsx"
cat > components/ChartToolbar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { CandlestickChart, LineChart, AreaChart, BarChart3, Layers, X, Search, Trash } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';
import { INDICATOR_DEFS } from '@/lib/indicators/engine';

const TFS = [{ v: 'D', l: 'D' }, { v: 'W', l: 'W' }, { v: 'M', l: 'M' }, { v: 'Q', l: 'Q' }, { v: 'Y', l: 'Y' }] as const;

export default function ChartToolbar() {
  const { timeframe, setTimeframe, chartType, setChartType, indicators, addIndicator, removeIndicator } = useAppStore();
  const [showModal, setShowModal] = useState(false);
  const [search, setSearch] = useState('');

  const filtered = INDICATOR_DEFS.filter(i => i.name.toLowerCase().includes(search.toLowerCase()) || i.type.toLowerCase().includes(search.toLowerCase()));

  const handleAdd = (def: any) => {
    addIndicator({ id: Math.random().toString(36).slice(2,8), type: def.type, period: def.defaultPeriod, color: def.color });
    setShowModal(false);
  };

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

      {/* Active Indicators List */}
      <div className="flex gap-2 ml-4 overflow-x-auto max-w-[40%] no-scrollbar">
        {indicators.map(ind => (
           <div key={ind.id} className="flex items-center gap-1 text-[10px] px-2 py-1 rounded-full border border-[color:var(--border)] bg-[color:var(--bg)]/50 whitespace-nowrap">
             <span style={{color: ind.color}}>{ind.type}({ind.period})</span>
             <button onClick={() => removeIndicator(ind.id)} className="text-[color:var(--muted)] hover:text-red-500"><X size={10}/></button>
           </div>
        ))}
      </div>

      <div className="flex gap-1 ml-auto">
        <button onClick={() => setShowModal(true)} className="flex items-center gap-1 px-2 py-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">
          <Layers size={14} /> <span className="text-xs font-medium">Indicators</span>
        </button>
      </div>

      {showModal && (
        <div className="absolute right-2 top-full mt-1 w-72 card p-0 z-50 shadow-2xl flex flex-col max-h-[60vh]">
          <div className="p-3 border-b border-[color:var(--border)] flex justify-between items-center">
            <h3 className="font-semibold text-sm">Add Indicator</h3>
            <button onClick={() => setShowModal(false)}><X size={16} /></button>
          </div>
          <div className="p-2 border-b border-[color:var(--border)] relative">
             <Search size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-[color:var(--muted)]"/>
             <input autoFocus value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search indicators..." className="w-full bg-transparent border border-[color:var(--border)] rounded pl-8 pr-2 py-1.5 text-xs outline-none focus:border-[color:var(--accent)]"/>
          </div>
          <div className="overflow-y-auto p-1">
            {filtered.map(ind => (
              <button key={ind.type} onClick={() => handleAdd(ind)} className="w-full text-left px-3 py-2 text-xs hover:bg-[color:var(--muted)]/10 rounded flex justify-between items-center group">
                <span>{ind.name}</span>
                <span className="text-[10px] text-[color:var(--muted)] group-hover:text-[color:var(--accent)]">+ Add</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
EOF

# ========== 4. Chart Panel (OHLC Hover, Multi-Indicators, Fixed Scales) ==========
write "components/ChartPanel.tsx"
cat > components/ChartPanel.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType, MouseEventParams } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';
import { calcIndicator } from '@/lib/indicators/engine';
import { bdt } from '@/lib/format';

export default function ChartPanel() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const mainSeriesRef = useRef<ISeriesApi<any> | null>(null);
  const indSeriesRef = useRef<ISeriesApi<any>[]>([]);
  const [hoverData, setHoverData] = useState<any>(null);
  
  const { activeSymbol: symbol, timeframe: tf, theme, chartType, indicators } = useAppStore();

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

  // Init Chart & Crosshair
  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: { background: { type: ColorType.Solid, color: 'transparent' }, textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540', fontFamily: 'ui-sans-serif' },
      grid: { vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' }, horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' } },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 5, barSpacing: 8 },
      autoSize: true,
      crosshair: { mode: 0, vertLine: { visible: true, labelVisible: true }, horzLine: { visible: true } }
    });
    
    chart.subscribeCrosshairMove((param: MouseEventParams) => {
      if (param.point === undefined || !param.time || param.point.x < 0 || param.point.y < 0) {
        setHoverData(null);
      } else if (param.seriesData.size > 0) {
        const data = param.seriesData.get(mainSeriesRef.current!) as any;
        if (data) setHoverData(data);
      }
    });

    chartRef.current = chart;
    chartRefs.chart = chart;
    return () => { chart.remove(); chartRefs.chart = null; chartRefs.series = null; };
  }, []);

  // Render Data & Indicators
  useEffect(() => {
    if (!chartRef.current || !data) return;
    const chart = chartRef.current;
    
    if (mainSeriesRef.current) chart.removeSeries(mainSeriesRef.current);
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
    mainSeriesRef.current = series;
    chartRefs.series = series as any;

    // Render Indicators
    indicators.forEach(ind => {
      const values = calcIndicator(data, ind.type, ind.period);
      const def = INDICATOR_DEFS.find(d => d.type === ind.type);
      if (!def || !values) return;

      const priceScaleId = def.isOscillator ? `osc_${ind.id}` : 'right';
      const scaleMargins = def.isOscillator ? { top: 0.7, bottom: 0 } : undefined;

      if (ind.type === 'BB' && (values as any).upper) {
        const v = values as any;
        const bbU = chart.addLineSeries({ color: ind.color, lineWidth: 1, priceScaleId });
        bbU.setData(data.map((d, i) => ({ time: d.time, value: v.upper[i] })).filter(d => d.value != null));
        const bbL = chart.addLineSeries({ color: ind.color, lineWidth: 1, priceScaleId });
        bbL.setData(data.map((d, i) => ({ time: d.time, value: v.lower[i] })).filter(d => d.value != null));
        const bbM = chart.addLineSeries({ color: ind.color, lineWidth: 1, lineStyle: 2, priceScaleId });
        bbM.setData(data.map((d, i) => ({ time: d.time, value: v.mid[i] })).filter(d => d.value != null));
        indSeriesRef.current.push(bbU, bbL, bbM);
      } else {
        const s = chart.addLineSeries({ color: ind.color, lineWidth: 2, priceScaleId });
        if (scaleMargins) s.priceScale().applyOptions({ scaleMargins });
        s.setData(data.map((d, i) => ({ time: d.time, value: (values as any[])[i] })).filter(d => d.value != null));
        indSeriesRef.current.push(s);
      }
    });

    // Volume
    const volSeries = chart.addHistogramSeries({ priceFormat: { type: 'volume' }, priceScaleId: 'vol', color: '#26a69a' });
    volSeries.priceScale().applyOptions({ scaleMargins: { top: 0.8, bottom: 0 } });
    volSeries.setData(data.map(d => ({ time: d.time, value: d.volume, color: d.close >= d.open ? '#16A34A' : '#DC2626' })));
    indSeriesRef.current.push(volSeries);

    chart.timeScale().scrollToRealTime();
  }, [data, chartType, indicators]);

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
      
      {/* OHLC Legend */}
      {hoverData && !isLoading && !error && (
        <div className="absolute top-2 left-2 z-20 flex gap-3 text-[10px] font-mono bg-[color:var(--bg)]/80 px-2 py-1 rounded backdrop-blur border border-[color:var(--border)]">
          <span className="text-[color:var(--muted)]">O <span className={hoverData.close >= hoverData.open ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{hoverData.open.toFixed(2)}</span></span>
          <span className="text-[color:var(--muted)]">H <span className="text-[color:var(--bull)]">{hoverData.high.toFixed(2)}</span></span>
          <span className="text-[color:var(--muted)]">L <span className="text-[color:var(--bear)]">{hoverData.low.toFixed(2)}</span></span>
          <span className="text-[color:var(--muted)]">C <span className={hoverData.close >= hoverData.open ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{hoverData.close.toFixed(2)}</span></span>
        </div>
      )}

      <div ref={containerRef} className="w-full h-full" />
      <DrawingCanvas />
    </div>
  );
}
EOF

# ========== 5. Drawing Canvas (Text Fix & Panning) ==========
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
    else if (typeof time === 'object' && 'year' in time) t = Math.floor(Date.UTC((time as any).year, (time as any).month - 1, (time as any).day) / 1000);
    else return null;
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

  useEffect(() => {
    let animId: number;
    const loop = () => { render(); animId = requestAnimationFrame(loop); };
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
      
      if (t === 'text') {
        e.preventDefault(); e.stopPropagation();
        const tp = toTimePrice(x, y);
        if (!tp || isNaN(tp.time) || isNaN(tp.price)) return;
        setPendingTextPos(tp);
        setInputText('');
        setShowTextModal(true);
        return;
      }

      e.preventDefault(); e.stopPropagation();
      const tp = toTimePrice(x, y);
      if (!tp || isNaN(tp.time) || isNaN(tp.price)) return;
      
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

# ========== 6. Strategy Builder (Dark Dropdowns & AND/OR) ==========
write "components/StrategyBuilder.tsx"
cat > components/StrategyBuilder.tsx << 'EOF'
'use client';
import { Plus, Trash2, Save } from 'lucide-react';
import { useStrategyStore } from '@/store/useStrategyStore';
import type { Comparator, Condition, ConditionGroup, Operand, Strategy } from '@/lib/strategy/types';

const OPERAND_TYPES = [
  { v: 'close', label: 'Price Close' }, { v: 'open', label: 'Price Open' },
  { v: 'high', label: 'Price High' }, { v: 'low', label: 'Price Low' },
  { v: 'SMA', label: 'SMA' }, { v: 'EMA', label: 'EMA' }, { v: 'WMA', label: 'WMA' },
  { v: 'RSI', label: 'RSI' }, { v: 'volume', label: 'Volume' }, { v: 'constant', label: 'Constant' },
];

const OPS: { v: Comparator; label: string }[] = [
  { v: 'crossesAbove', label: 'crosses above' }, { v: 'crossesBelow', label: 'crosses below' },
  { v: '>', label: '>' }, { v: '<', label: '<' }, { v: '>=', label: '≥' }, { v: '<=', label: '≤' },
];

function fromType(v: string, period = 20, value = 0): Operand {
  if (['close','open','high','low'].includes(v)) return { kind: 'price', field: v as any };
  if (v === 'volume') return { kind: 'volume' };
  if (v === 'constant') return { kind: 'constant', value };
  return { kind: 'indicator', name: v as any, period };
}
function toType(op: Operand): string {
  if (op.kind === 'price') return op.field;
  if (op.kind === 'volume') return 'volume';
  if (op.kind === 'constant') return 'constant';
  return op.name;
}

// Reusable dark-mode select
const DarkSelect = ({ value, onChange, options, className="" }: any) => (
  <select value={value} onChange={onChange} 
    className={`bg-[#1E2A44] text-[#E6EDF7] border border-[#3B4A6B] rounded px-2 py-1 text-xs outline-none focus:border-[color:var(--accent)] ${className}`}>
    {options.map((o: any) => <option key={o.v} value={o.v} className="bg-[#111A2C] text-[#E6EDF7]">{o.label}</option>)}
  </select>
);

export default function StrategyBuilder() {
  const { current, setCurrent, save, strategies, load, createNew } = useStrategyStore();
  const update = (patch: Partial<Strategy>) => setCurrent({ ...current, ...patch });

  const setCondition = (side: 'buy' | 'sell', idx: number, patch: Partial<Condition>) => {
    const g: ConditionGroup = { ...current[side] };
    g.conditions = g.conditions.map((c, i) => i === idx ? { ...c, ...patch } : c);
    update({ [side]: g } as any);
  };
  const addCondition = (side: 'buy' | 'sell') => {
    const g: ConditionGroup = { ...current[side] };
    g.conditions = [...g.conditions, { id: Math.random().toString(36).slice(2, 8), left: { kind: 'indicator', name: 'EMA', period: 20 }, op: 'crossesAbove', right: { kind: 'indicator', name: 'EMA', period: 50 } }];
    update({ [side]: g } as any);
  };
  const removeCondition = (side: 'buy' | 'sell', idx: number) => {
    const g: ConditionGroup = { ...current[side] };
    g.conditions = g.conditions.filter((_, i) => i !== idx);
    update({ [side]: g } as any);
  };

  const Group = ({ side, label }: { side: 'buy' | 'sell'; label: string }) => (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <span className={`font-semibold ${side === 'buy' ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>{label}</span>
        <DarkSelect value={current[side].op} onChange={(e: any) => update({ [side]: { ...current[side], op: e.target.value } } as any)} options={[{v:'AND',label:'AND (All must trigger)'},{v:'OR',label:'OR (Any triggers)'}]} />
      </div>
      {current[side].conditions.map((c, i) => (
        <div key={c.id} className="grid grid-cols-1 md:grid-cols-[1fr_auto_1fr_auto] gap-2 items-center p-2 rounded-lg border border-[color:var(--border)]">
          
          {/* Left Operand */}
          <div className="flex gap-1 items-center">
            <DarkSelect value={toType(c.left)} onChange={(e: any) => setCondition(side, i, { left: fromType(e.target.value) })} options={OPERAND_TYPES} className="flex-1" />
            {c.left.kind === 'indicator' && <input type="number" value={c.left.period} onChange={e => setCondition(side, i, { left: { ...c.left, period: Number(e.target.value) } as any })} className="w-12 bg-[#1E2A44] text-[#E6EDF7] border border-[#3B4A6B] rounded px-1 py-1 text-xs" />}
          </div>

          <DarkSelect value={c.op} onChange={(e: any) => setCondition(side, i, { op: e.target.value })} options={OPS} />

          {/* Right Operand */}
          <div className="flex gap-1 items-center">
            <DarkSelect value={toType(c.right)} onChange={(e: any) => setCondition(side, i, { right: fromType(e.target.value) })} options={OPERAND_TYPES} className="flex-1" />
            {c.right.kind === 'indicator' && <input type="number" value={c.right.period} onChange={e => setCondition(side, i, { right: { ...c.right, period: Number(e.target.value) } as any })} className="w-12 bg-[#1E2A44] text-[#E6EDF7] border border-[#3B4A6B] rounded px-1 py-1 text-xs" />}
          </div>

          <button onClick={() => removeCondition(side, i)} className="p-1.5 rounded border border-[color:var(--border)] hover:text-red-500"><Trash2 size={12} /></button>
        </div>
      ))}
      <button onClick={() => addCondition(side)} className="flex items-center gap-1 text-xs px-2 py-1 rounded border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">
        <Plus size={12} /> Add condition
      </button>
    </div>
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 flex-wrap">
        <input value={current.name} onChange={(e) => update({ name: e.target.value })} className="px-2 py-1 rounded border border-[color:var(--border)] bg-transparent text-sm font-medium" placeholder="Strategy name" />
        <DarkSelect onChange={(e: any) => e.target.value && load(e.target.value)} defaultValue="" options={[{v:'',label:'Load saved...'}, ...strategies.map(s => ({ v: s.id, label: s.name }))]} />
        <button onClick={createNew} className="text-xs px-2 py-1 rounded border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">New</button>
        <button onClick={save} className="flex items-center gap-1 text-xs px-2 py-1 rounded bg-[color:var(--accent)] text-white"><Save size={12} /> Save</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Group side="buy" label="BUY when" />
        <Group side="sell" label="SELL when" />
      </div>
    </div>
  );
}
EOF

# ========== 7. Chart Page (Bottom Tabs for Movers/Paper Trading) ==========
write "app/chart/page.tsx"
cat > app/chart/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import ChartToolbar from '@/components/ChartToolbar';
import ChartPanel from '@/components/ChartPanel';
import DrawingToolbar from '@/components/DrawingToolbar';
import InstrumentPicker from '@/components/InstrumentPicker';
import { useAppStore } from '@/store/useAppStore';
import { bdt } from '@/lib/format';

export default function ChartPage() {
  const [activeTab, setActiveTab] = useState<'trading'|'movers'>('trading');
  
  return (
    <>
      <TopBar />
      <main className="grid grid-cols-1 md:grid-cols-[280px_1fr] gap-3 p-3 pb-20">
        <aside className="card p-2 order-2 md:order-1 h-[calc(100vh-140px)] overflow-hidden">
          <InstrumentPicker />
        </aside>
        <section className="order-1 md:order-2 flex flex-col gap-3">
          <div className="card overflow-hidden flex-shrink-0">
            <ChartToolbar />
            <DrawingToolbar />
            <ChartPanel />
          </div>
          
          {/* Bottom Panel */}
          <div className="card flex-1 flex flex-col min-h-[250px]">
            <div className="flex border-b border-[color:var(--border)] px-2">
              <button onClick={()=>setActiveTab('trading')} className={`px-4 py-2 text-xs font-semibold border-b-2 ${activeTab === 'trading' ? 'border-[color:var(--accent)] text-[color:var(--accent)]' : 'border-transparent text-[color:var(--muted)]'}`}>Paper Trading</button>
              <button onClick={()=>setActiveTab('movers')} className={`px-4 py-2 text-xs font-semibold border-b-2 ${activeTab === 'movers' ? 'border-[color:var(--accent)] text-[color:var(--accent)]' : 'border-transparent text-[color:var(--muted)]'}`}>Market Movers</button>
            </div>
            
            <div className="p-3 flex-1 overflow-y-auto">
              {activeTab === 'trading' ? <PaperTradingPanel /> : <div className="text-center text-xs text-[color:var(--muted)] mt-10">Movers & Heatmap coming in next update...</div>}
            </div>
          </div>
        </section>
      </main>
      <BottomTabs />
    </>
  );
}

function PaperTradingPanel() {
  const { activeSymbol, paperCash, paperHoldings, executeTrade } = useAppStore();
  const [qty, setQty] = useState(10);
  // Fake price for demo (in a real app, use the current chart price)
  const price = 120.50; 
  const holding = paperHoldings[activeSymbol] || { qty: 0, avg: 0 };

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div className="col-span-2 space-y-2">
         <div className="flex justify-between text-xs mb-2">
           <span className="text-[color:var(--muted)]">Cash Balance</span>
           <span className="font-mono font-bold text-[color:var(--text)]">{bdt(paperCash)}</span>
         </div>
         <div className="flex justify-between text-xs mb-4">
           <span className="text-[color:var(--muted)]">Position ({activeSymbol})</span>
           <span className="font-mono font-bold text-[color:var(--accent)]">{holding.qty} shares @ {bdt(holding.avg)}</span>
         </div>
      </div>
      
      <div className="flex flex-col gap-2">
        <div className="flex gap-1">
          <input type="number" value={qty} onChange={e=>setQty(Number(e.target.value))} className="w-full bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-sm text-center" placeholder="Qty" />
        </div>
        <div className="grid grid-cols-2 gap-2">
          <button onClick={() => executeTrade('BUY', price, qty)} className="py-1.5 rounded bg-[color:var(--bull)] text-white text-xs font-bold">BUY</button>
          <button onClick={() => executeTrade('SELL', price, qty)} className="py-1.5 rounded bg-[color:var(--bear)] text-white text-xs font-bold">SELL</button>
        </div>
      </div>
    </div>
  );
}
EOF

echo ""
echo "✅ V5 Update applied successfully!"
echo "1. Run: npm run dev"
echo "2. Refresh your browser."