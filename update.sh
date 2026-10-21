#!/usr/bin/env bash
set -e

echo "🔄 Updating Bongotrader to V2..."

write() { echo "📝 Updating $1"; }

# ========== FIX 1: Scrollbar & Marquee CSS ==========
write "app/globals.css"
cat > app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root, [data-theme="dark"] {
  --bg: #0B1220; --panel: #111A2C; --border: #1E2A44; --text: #E6EDF7;
  --muted: #8B9BB4; --accent: #22C1A4; --bull: #16A34A; --bear: #DC2626;
  --card-bg: rgba(17,26,44,0.85); --card-shadow: 0 8px 24px rgba(0,0,0,0.5);
}

[data-theme="light"] {
  --bg: #F4F8FF; --panel: rgba(200,225,255,0.55); --border: #BFD9FF;
  --text: #0A2540; --muted: #4A6A8A; --accent: #1E6FD9; --bull: #0E9F6E;
  --bear: #D92D20; --card-bg: rgba(200,225,255,0.55); --card-shadow: 0 8px 24px rgba(10,37,64,0.08);
}

html, body { background: var(--bg); color: var(--text); transition: background 300ms ease, color 300ms ease; }
[data-theme="light"] body { background: linear-gradient(180deg, #EEF5FF 0%, #DCEBFF 100%); min-height: 100vh; }

.card { background: var(--card-bg); box-shadow: var(--card-shadow); border: 1px solid var(--border); border-radius: 12px; backdrop-filter: blur(8px); }
.chart-pane { background: var(--panel); border-radius: 12px; overflow: hidden; position: relative; }

/* Custom Scrollbar */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }
::-webkit-scrollbar-thumb:hover { background: var(--muted); }

/* Marquee Animation */
.animate-marquee { display: flex; animation: marquee 20s linear infinite; }
.animate-marquee:hover { animation-play-state: paused; }
@keyframes marquee { 0% { transform: translateX(0); } 100% { transform: translateX(-50%); } }
EOF

# ========== FIX 2: App Store (Add Chart Type) ==========
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
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  setLang: (l: Lang) => void;
  setSymbol: (s: string) => void;
  setTimeframe: (t: AppState['timeframe']) => void;
  setChartType: (t: ChartType) => void;
  setFee: (f: number) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', chartType: 'candlestick', feePct: 0.15,
  setTheme: (t) => set({ theme: t }),
  toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
  setLang: (l) => set({ lang: l }),
  setSymbol: (s) => set({ activeSymbol: s }),
  setTimeframe: (t) => set({ timeframe: t }),
  setChartType: (t) => set({ chartType: t }),
  setFee: (f) => set({ feePct: f }),
}), { name: 'bongotrader-app' }));
EOF

# ========== FIX 3: OHLCV API (W & Q Dates) ==========
write "app/api/ohlcv/route.ts"
cat > app/api/ohlcv/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

type TF = 'D' | 'W' | 'M' | 'Q' | 'Y';

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const symbol = sp.get('symbol');
  const tf = (sp.get('tf') ?? 'D') as TF;
  const limit = Math.min(parseInt(sp.get('limit') ?? '500'), 5000);
  if (!symbol) return NextResponse.json({ error: 'symbol' }, { status: 400 });

  const sb = adminClient();

  if (tf === 'D') {
    const { data, error } = await sb.from('daily_ohlcv')
      .select('date,open,high,low,close,volume').eq('symbol', symbol)
      .order('date', { ascending: false }).limit(limit);
    if (error) return NextResponse.json({ error: 'db' }, { status: 500 });
    return NextResponse.json({ data: (data ?? []).reverse() });
  }

  const { data: raw } = await sb.from('daily_ohlcv')
    .select('date,open,high,low,close,volume').eq('symbol', symbol)
    .order('date', { ascending: false }).limit(limit * 7);

  const buckets = new Map<string, any>();
  for (const r of (raw ?? []).reverse()) {
    const d = new Date(r.date);
    const key = bucketKey(d, tf);
    const cur = buckets.get(key);
    if (!cur) buckets.set(key, { date: key, open: r.open, high: r.high, low: r.low, close: r.close, volume: r.volume });
    else {
      cur.high = Math.max(cur.high, r.high); cur.low = Math.min(cur.low, r.low);
      cur.close = r.close; cur.volume = (cur.volume ?? 0) + (r.volume ?? 0);
    }
  }
  return NextResponse.json({ data: Array.from(buckets.values()).slice(-limit) });
}

function bucketKey(d: Date, tf: TF) {
  const y = d.getUTCFullYear();
  const m = d.getUTCMonth();
  if (tf === 'W') {
    // Fix: Return actual valid YYYY-MM-DD format (start of week)
    const day = d.getUTCDay() || 7; 
    d.setUTCDate(d.getUTCDate() - day + 1); 
    return d.toISOString().slice(0, 10);
  }
  if (tf === 'M') return `${y}-${String(m + 1).padStart(2, '0')}-01`;
  if (tf === 'Q') {
    const qm = Math.floor(m / 3) * 3;
    return `${y}-${String(qm + 1).padStart(2, '0')}-01`;
  }
  return `${y}-01-01`;
}
EOF

# ========== FIX 4: Chart Panel (Handle Chart Types) ==========
write "components/ChartPanel.tsx"
cat > components/ChartPanel.tsx << 'EOF'
'use client';
import { useEffect, useRef } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';

export default function ChartPanel() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const seriesRef = useRef<ISeriesApi<any> | null>(null);
  const { activeSymbol: symbol, timeframe: tf, theme, chartType } = useAppStore();

  const { data, isLoading, error } = useQuery({
    queryKey: ['ohlcv', symbol, tf],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=${tf}&limit=500`);
      if (!r.ok) throw new Error('failed');
      const j = await r.json();
      const raw = (j.data as any[]) || [];
      const parsed = raw.map((d) => {
        const t = new Date(d.date).getTime();
        return { time: Math.floor(t / 1000) as any, open: Number(d.open), high: Number(d.high), low: Number(d.low), close: Number(d.close), value: Number(d.close) };
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

  // Handle Chart Type & Data
  useEffect(() => {
    if (!chartRef.current || !data) return;
    const chart = chartRef.current;
    
    if (seriesRef.current) chart.removeSeries(seriesRef.current);

    const opts = { upColor: '#16A34A', downColor: '#DC2626', wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false };
    let series;
    if (chartType === 'line') series = chart.addLineSeries({ color: '#1E6FD9', lineWidth: 2 });
    else if (chartType === 'area') series = chart.addAreaSeries({ lineColor: '#1E6FD9', topColor: 'rgba(30,111,217,0.4)', bottomColor: 'rgba(30,111,217,0.0)' });
    else if (chartType === 'bar') series = chart.addBarSeries({ upColor: '#16A34A', downColor: '#DC2626' });
    else series = chart.addCandlestickSeries(opts);

    series.setData(data);
    seriesRef.current = series;
    chartRefs.series = series as any;
    chart.timeScale().scrollToRealTime();
  }, [data, chartType]);

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

# ========== FIX 5: Drawing Canvas (Draggable, Custom Text Modal) ==========
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
    const t = typeof time === 'number' ? time : Math.floor(Date.UTC((time as any).year, (time as any).month - 1, (time as any).day) / 1000);
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
      ctx.font = '13px ui-sans-serif';
      const tw = ctx.measureText(d.text ?? '').width;
      ctx.fillStyle = stroke; ctx.fillRect(a.x - 4, a.y - 16, tw + 8, 20);
      ctx.fillStyle = '#fff'; ctx.fillText(d.text ?? '', a.x, a.y - 2);
      if (isSel) { ctx.strokeStyle = COL.select; ctx.lineWidth = 1.5; ctx.strokeRect(a.x - 5, a.y - 17, tw + 10, 22); }
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

  useEffect(() => { render(); }, [drawings, selectedId, theme]);

  useEffect(() => {
    const { chart } = chartRefs;
    if (!chart) return;
    const onRange = () => render();
    chart.timeScale().subscribeVisibleLogicalRangeChange(onRange);
    const ro = new ResizeObserver(() => render());
    if (canvasRef.current?.parentElement) ro.observe(canvasRef.current.parentElement);
    const id = requestAnimationFrame(render);
    return () => { chart.timeScale().unsubscribeVisibleLogicalRangeChange(onRange); ro.disconnect(); cancelAnimationFrame(id); };
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
        if (!hit) { select(null); return; }
        e.preventDefault(); e.stopPropagation();
        select(hit.id);
        dragRef.current = { id: hit.id, a0: { ...hit.a }, b0: hit.b ? { ...hit.b } : undefined };
        el.addEventListener('pointermove', onMove);
        el.addEventListener('pointerup', onUp);
        return;
      }
      e.preventDefault(); e.stopPropagation();
      const tp = toTimePrice(x, y);
      if (!tp) return;
      
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
        render();
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
      
      {/* Custom Text Modal */}
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

# ========== FIX 6: Drawing Toolbar (Colored Box Icons) ==========
write "components/DrawingToolbar.tsx"
cat > components/DrawingToolbar.tsx << 'EOF'
'use client';
import { MousePointer2, Minus, Type, ArrowUpRight, ArrowDownRight, Square, Trash2, Image as ImageIcon } from 'lucide-react';
import { useDrawingsStore } from '@/store/useDrawingsStore';
import type { ToolId } from '@/lib/drawing/types';

const TOOLS = [
  { id: 'select' as ToolId, Icon: MousePointer2, label: 'Select', color: '' },
  { id: 'trendline' as ToolId, Icon: ArrowUpRight, label: 'Trendline', color: '' },
  { id: 'hline' as ToolId, Icon: Minus, label: 'Horizontal', color: '' },
  { id: 'text' as ToolId, Icon: Type, label: 'Text', color: '' },
  { id: 'buy' as ToolId, Icon: ArrowUpRight, label: 'Buy Badge', color: 'text-[color:var(--bull)]' },
  { id: 'sell' as ToolId, Icon: ArrowDownRight, label: 'Sell Badge', color: 'text-[color:var(--bear)]' },
  { id: 'greenbox' as ToolId, Icon: Square, label: 'Green Box', color: 'text-[color:var(--bull)]' },
  { id: 'redbox' as ToolId, Icon: Square, label: 'Red Box', color: 'text-[color:var(--bear)]' },
];

export default function DrawingToolbar() {
  const { tool, setTool, selectedId, remove, clearAll } = useDrawingsStore();

  const saveImage = () => {
    const container = document.querySelector('.chart-pane') as HTMLElement;
    if (!container) return;
    const canvases = Array.from(container.querySelectorAll('canvas')) as HTMLCanvasElement[];
    const rect = container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const combined = document.createElement('canvas');
    combined.width = rect.width * dpr; combined.height = rect.height * dpr;
    const ctx = combined.getContext('2d')!;
    ctx.scale(dpr, dpr);
    ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim() || '#fff';
    ctx.fillRect(0, 0, rect.width, rect.height);
    for (const c of canvases) {
      const cRect = c.getBoundingClientRect();
      try { ctx.drawImage(c, cRect.left - rect.left, cRect.top - rect.top, cRect.width, cRect.height); } catch {}
    }
    const link = document.createElement('a'); link.download = `bongotrader-${Date.now()}.png`; link.href = combined.toDataURL('image/png'); link.click();
  };

  return (
    <div className="flex items-center gap-1 flex-wrap p-2 border-b border-[color:var(--border)]">
      {TOOLS.map(({ id, Icon, label, color }) => (
        <button key={id} onClick={() => setTool(id)} title={label}
          className={`p-1.5 rounded-lg border transition-colors ${tool === id ? 'bg-[color:var(--accent)] text-white border-[color:var(--accent)]' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'} ${tool !== id && color ? color : ''}`}>
          <Icon size={14} />
        </button>
      ))}
      <div className="flex-1" />
      {selectedId && <button onClick={() => remove(selectedId)} className="p-1.5 rounded-lg border border-[color:var(--bear)] text-[color:var(--bear)]"><Trash2 size={14} /></button>}
      <button onClick={clearAll} className="px-2 py-1 text-xs rounded-lg border border-[color:var(--border)]">Clear</button>
      <button onClick={saveImage} className="p-1.5 rounded-lg border border-[color:var(--border)]"><ImageIcon size={14} /></button>
    </div>
  );
}
EOF

# ========== FIX 7: Chart Toolbar (Icons Work) ==========
write "components/ChartToolbar.tsx"
cat > components/ChartToolbar.tsx << 'EOF'
'use client';
import { CandlestickChart, LineChart, AreaChart, BarChart3, Layers } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';

const TFS = [{ v: 'D', l: 'D' }, { v: 'W', l: 'W' }, { v: 'M', l: 'M' }, { v: 'Q', l: 'Q' }, { v: 'Y', l: 'Y' }] as const;

export default function ChartToolbar() {
  const { timeframe, setTimeframe, chartType, setChartType } = useAppStore();
  
  return (
    <div className="flex items-center gap-2 flex-wrap p-2 border-b border-[color:var(--border)]">
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

      <div className="flex gap-1 ml-auto">
        <button className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10"><Layers size={14} /></button>
      </div>
    </div>
  );
}
EOF

# ========== FIX 8: Movers Ticker (Auto Scroll) ==========
write "components/MoversTicker.tsx"
cat > components/MoversTicker.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';

export default function MoversTicker() {
  const { data } = useQuery({ queryKey: ['movers'], queryFn: async () => (await fetch('/api/movers')).json() });
  const gainers = data?.gainers ?? [];
  const losers = data?.losers ?? [];
  const items = [...gainers, ...losers, ...gainers, ...losers]; // duplicate for infinite scroll

  return (
    <div className="hidden md:flex overflow-hidden max-w-[520px] px-2 py-1.5 rounded-lg border border-[color:var(--border)] relative bg-[color:var(--card-bg)]">
      <div className="animate-marquee whitespace-nowrap">
        {items.map((m: any, i: number) => {
          const up = (m.pct_change ?? 0) >= 0;
          return (
            <span key={i} className="text-xs px-3 inline-flex items-center">
              <span className="font-medium mr-1">{m.symbol}</span>
              <span className={up ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{up ? '+' : ''}{m.pct_change?.toFixed(2)}%</span>
            </span>
          );
        })}
      </div>
    </div>
  );
}
EOF

# ========== FIX 9: Backtest (Start/End Dates) ==========
write "app/backtest/page.tsx"
cat > app/backtest/page.tsx << 'EOF'
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
EOF

# ========== FIX 10: Top Bar (Notifications) ==========
write "components/TopBar.tsx"
cat > components/TopBar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import MarketCountdown from './MarketCountdown';
import ActiveInstrumentChip from './ActiveInstrumentChip';
import MoversTicker from './MoversTicker';
import ThemeToggle from './ThemeToggle';
import LanguageToggle from './LanguageToggle';
import { useAppStore } from '@/store/useAppStore';
import { Bell, User, X } from 'lucide-react';

export default function TopBar() {
  const { feePct, setFee } = useAppStore();
  const [showAlerts, setShowAlerts] = useState(false);

  return (
    <header className="sticky top-0 z-40 backdrop-blur border-b border-[color:var(--border)]" style={{ background: 'var(--card-bg)' }}>
      <div className="flex items-center gap-3 px-3 py-2 overflow-x-auto">
        <MarketCountdown />
        <ActiveInstrumentChip />
        <MoversTicker />
        <div className="ml-auto flex items-center gap-2">
          <label className="flex items-center gap-1 text-xs">
            Fee:
            <input type="number" step="0.01" min="0" max="5" value={feePct} onChange={(e) => setFee(parseFloat(e.target.value) || 0)} className="w-14 bg-transparent border border-[color:var(--border)] rounded px-1 py-0.5 text-center" />%
          </label>
          <LanguageToggle />
          <ThemeToggle />
          
          <button onClick={() => setShowAlerts(!showAlerts)} className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 relative">
            <Bell size={16} />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-[color:var(--bear)]"></span>
          </button>
          <button className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10"><User size={16} /></button>
        </div>
      </div>

      {showAlerts && (
        <div className="absolute right-2 top-14 w-80 card p-0 overflow-hidden shadow-2xl z-50">
          <div className="flex items-center justify-between p-3 border-b border-[color:var(--border)] bg-[color:var(--bg)]/50">
            <h3 className="font-semibold text-sm">Notifications</h3>
            <button onClick={() => setShowAlerts(false)}><X size={14}/></button>
          </div>
          <div className="max-h-64 overflow-y-auto p-2 space-y-2">
            <div className="p-2 rounded bg-[color:var(--muted)]/10 text-xs border border-[color:var(--border)]">
              <span className="text-[color:var(--bull)] font-semibold">Price Alert:</span> SHARPIND crossed ৳15.00
              <div className="text-[10px] text-[color:var(--muted)] mt-1">2 minutes ago</div>
            </div>
            <div className="p-2 rounded bg-[color:var(--muted)]/10 text-xs border border-[color:var(--border)]">
              <span className="text-[color:var(--accent)] font-semibold">Strategy Signal:</span> EMA Crossover triggered BUY on BEXIMCO
              <div className="text-[10px] text-[color:var(--muted)] mt-1">1 hour ago</div>
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
EOF

# ========== FIX 11: Account Page (Simulated Portfolio) ==========
write "app/account/page.tsx"
cat > app/account/page.tsx << 'EOF'
'use client';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import { useQuery } from '@tanstack/react-query';
import { bdt, pct } from '@/lib/format';

const MOCK_HOLDINGS = [
  { symbol: 'AIBL', qty: 500, avgPrice: 45.00 },
  { symbol: 'BEXIMCO', qty: 1000, avgPrice: 110.50 },
  { symbol: 'GP', qty: 50, avgPrice: 320.00 },
];

export default function AccountPage() {
  const { data: prices } = useQuery({
    queryKey: ['portfolio-prices'],
    queryFn: async () => {
      const res = await fetch(`/api/symbols?size=1000`); // Fetch all to find our mock symbols
      const j = await res.json();
      return (j.data as any[]) || [];
    },
    refetchInterval: 60000,
  });

  const holdings = MOCK_HOLDINGS.map(h => {
    const live = prices?.find(p => p.symbol === h.symbol);
    const currentPrice = live?.last_close ?? h.avgPrice;
    const pnl = (currentPrice - h.avgPrice) * h.qty;
    const pnlPct = ((currentPrice - h.avgPrice) / h.avgPrice) * 100;
    return { ...h, currentPrice, pnl, pnlPct };
  });

  const totalValue = holdings.reduce((s, h) => s + h.currentPrice * h.qty, 0);
  const totalCost = holdings.reduce((s, h) => s + h.avgPrice * h.qty, 0);
  const totalPnl = totalValue - totalCost;

  return (
    <>
      <TopBar />
      <main className="p-3 pb-20 max-w-4xl mx-auto space-y-4">
        <div className="card p-5 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h2 className="text-sm text-[color:var(--muted)] uppercase tracking-wider mb-1">Portfolio Value</h2>
            <div className="text-3xl font-bold font-mono tabular-nums">{bdt(totalValue)}</div>
          </div>
          <div className="flex gap-6">
            <div>
              <div className="text-xs text-[color:var(--muted)] mb-1">Total PnL</div>
              <div className={`text-lg font-mono tabular-nums font-semibold ${totalPnl >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>
                {totalPnl >= 0 ? '+' : ''}{bdt(totalPnl)}
              </div>
            </div>
            <div>
              <div className="text-xs text-[color:var(--muted)] mb-1">Return</div>
              <div className={`text-lg font-mono tabular-nums font-semibold ${totalPnl >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>
                {pct((totalPnl / totalCost) * 100)}
              </div>
            </div>
          </div>
        </div>

        <div className="card overflow-hidden">
          <div className="p-4 border-b border-[color:var(--border)]">
            <h3 className="font-semibold text-sm">Holdings (Simulated)</h3>
          </div>
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-[color:var(--muted)] uppercase bg-[color:var(--muted)]/5">
              <tr>
                <th className="px-4 py-3">Symbol</th>
                <th className="px-4 py-3 text-right">Qty</th>
                <th className="px-4 py-3 text-right">Avg Price</th>
                <th className="px-4 py-3 text-right">LTP</th>
                <th className="px-4 py-3 text-right">PnL</th>
              </tr>
            </thead>
            <tbody>
              {holdings.map(h => (
                <tr key={h.symbol} className="border-b border-[color:var(--border)] last:border-0 hover:bg-[color:var(--muted)]/5">
                  <td className="px-4 py-3 font-medium">{h.symbol}</td>
                  <td className="px-4 py-3 text-right font-mono">{h.qty}</td>
                  <td className="px-4 py-3 text-right font-mono">{bdt(h.avgPrice)}</td>
                  <td className="px-4 py-3 text-right font-mono">{bdt(h.currentPrice)}</td>
                  <td className={`px-4 py-3 text-right font-mono font-medium ${h.pnl >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>
                    {h.pnl >= 0 ? '+' : ''}{bdt(h.pnl)} <br/>
                    <span className="text-[10px]">{pct(h.pnlPct)}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

echo ""
echo "✅ All updates applied successfully!"
echo "🚀 Now restart your server:"
echo "   1. Press Ctrl+C in your terminal to stop the server."
echo "   2. Run: npm run dev"
echo "   3. Refresh your browser."