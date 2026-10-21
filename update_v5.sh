#!/usr/bin/env bash
set -e

echo "🚀 Updating Chartbongo to V5 (Dropdown, Portfolio, Text Fix, Tabs)..."

write() { echo "📝 Updating $1"; }

# ========== 1. App Store (Portfolio Settings) ==========
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
  resetPaperAccount: (cash: number, fee: number) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', chartType: 'candlestick', feePct: 0.15,
  indicators: [], paperCash: 100000, paperHoldings: {},
  
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
      if (s.paperCash < cost + fee) return s;
      const current = s.paperHoldings[s.activeSymbol] || { qty: 0, avg: 0 };
      const newQty = current.qty + qty;
      const newAvg = ((current.qty * current.avg) + cost) / newQty;
      return { paperCash: s.paperCash - cost - fee, paperHoldings: { ...s.paperHoldings, [s.activeSymbol]: { qty: newQty, avg: newAvg } } };
    } else {
      const current = s.paperHoldings[s.activeSymbol] || { qty: 0, avg: 0 };
      if (current.qty < qty) return s;
      const newQty = current.qty - qty;
      const newHoldings = { ...s.paperHoldings };
      if (newQty === 0) delete newHoldings[s.activeSymbol];
      else newHoldings[s.activeSymbol] = { ...current, qty: newQty };
      return { paperCash: s.paperCash + cost - fee, paperHoldings: newHoldings };
    }
  }),
  
  resetPaperAccount: (cash, fee) => set({ paperCash: cash, feePct: fee, paperHoldings: {} }),
}), { name: 'chartbongo-app' }));
EOF

# ========== 2. Active Instrument Chip (Working Dropdown) ==========
write "components/ActiveInstrumentChip.tsx"
cat > components/ActiveInstrumentChip.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { ChevronDown, Search, X } from 'lucide-react';
import { bdt } from '@/lib/format';
import { useState, useRef, useEffect } from 'react';

export default function ActiveInstrumentChip() {
  const { activeSymbol: symbol, setSymbol } = useAppStore();
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const dropRef = useRef<HTMLDivElement>(null);

  const { data } = useQuery({
    queryKey: ['summary', symbol],
    queryFn: async () => {
      const r = await fetch(`/api/symbols?q=${symbol}&size=20`);
      const j = await r.json();
      return (j.data ?? []).find((x: any) => x.symbol === symbol) ?? null;
    },
  });

  const { data: searchResults } = useQuery({
    queryKey: ['symbolSearch', search],
    queryFn: async () => {
      const r = await fetch(`/api/symbols?q=${search}&size=20`);
      return (await r.json()).data || [];
    },
    enabled: isOpen,
  });

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (dropRef.current && !dropRef.current.contains(e.target as Node)) setIsOpen(false);
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const up = (data?.pct_change ?? 0) >= 0;

  return (
    <div className="relative" ref={dropRef}>
      <button onClick={() => setIsOpen(!isOpen)} className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10 transition">
        <span className="font-semibold">{symbol}</span>
        {!data?.is_active && <span className="text-[10px] px-1.5 py-0.5 rounded bg-[color:var(--muted)]/20 text-[color:var(--muted)]">Inactive</span>}
        {data && (
          <>
            <span className="font-mono tabular-nums">{bdt(Number(data.last_close ?? 0))}</span>
            <span className={up ? 'text-[color:var(--bull)] text-xs' : 'text-[color:var(--bear)] text-xs'}>{up ? '▲' : '▼'} {Math.abs(data.pct_change ?? 0).toFixed(2)}%</span>
          </>
        )}
        <ChevronDown size={14} className="text-[color:var(--muted)]" />
      </button>

      {isOpen && (
        <div className="absolute top-full left-0 mt-2 w-64 card p-2 z-50 shadow-2xl">
          <div className="flex items-center gap-2 px-2 py-1.5 border-b border-[color:var(--border)] mb-2">
            <Search size={14} className="text-[color:var(--muted)]" />
            <input autoFocus value={search} onChange={e => setSearch(e.target.value)} placeholder="Search symbol..." className="w-full bg-transparent text-sm outline-none" />
            <button onClick={() => setIsOpen(false)}><X size={14} className="text-[color:var(--muted)]" /></button>
          </div>
          <div className="max-h-60 overflow-y-auto">
            {searchResults?.map((s: any) => (
              <button key={s.symbol} onClick={() => { setSymbol(s.symbol); setIsOpen(false); }} className="w-full text-left px-2 py-1.5 flex items-center justify-between text-xs hover:bg-[color:var(--muted)]/10 rounded">
                <span className="font-medium">{s.symbol}</span>
                <span className={(s.pct_change ?? 0) >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{(s.pct_change ?? 0).toFixed(2)}%</span>
              </button>
            ))}
            {searchResults?.length === 0 && <div className="text-center text-xs text-[color:var(--muted)] p-2">No results</div>}
          </div>
        </div>
      )}
    </div>
  );
}
EOF

# ========== 3. Drawing Canvas (Text Fix) ==========
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
        if (!hit) { select(null); return; }
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

# ========== 4. Account Page (Portfolio & Settings) ==========
write "app/account/page.tsx"
cat > app/account/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import { useAppStore } from '@/store/useAppStore';
import { bdt, pct } from '@/lib/format';
import { Settings, ArrowUpRight, ArrowDownRight } from 'lucide-react';

export default function AccountPage() {
  const { paperCash, paperHoldings, executeTrade, resetPaperAccount, feePct } = useAppStore();
  const [showSettings, setShowSettings] = useState(false);
  const [newCash, setNewCash] = useState(100000);
  const [newFee, setNewFee] = useState(feePct);
  const [tradeQty, setTradeQty] = useState<Record<string, number>>({});

  const holdingsList = Object.entries(paperHoldings).map(([sym, h]) => ({ symbol: sym, ...h }));
  const totalCost = holdingsList.reduce((s, h) => s + (h.avg * h.qty), 0);
  const totalEquity = paperCash + totalCost; // Simplified for demo (assuming avg = market price)

  return (
    <>
      <TopBar />
      <main className="p-3 pb-20 max-w-4xl mx-auto space-y-4">
        <div className="flex justify-between items-center">
          <h2 className="text-lg font-bold">Paper Trading Account</h2>
          <button onClick={() => setShowSettings(!showSettings)} className="p-2 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10"><Settings size={16}/></button>
        </div>

        {showSettings && (
          <div className="card p-4 border border-[color:var(--accent)]">
            <h3 className="font-semibold mb-3 text-sm">Account Settings</h3>
            <div className="flex gap-4 items-end">
              <label className="text-xs flex flex-col gap-1">
                Initial Cash (৳)
                <input type="number" value={newCash} onChange={e=>setNewCash(Number(e.target.value))} className="bg-transparent border border-[color:var(--border)] rounded px-2 py-1" />
              </label>
              <label className="text-xs flex flex-col gap-1">
                Fee (%)
                <input type="number" step="0.01" value={newFee} onChange={e=>setNewFee(Number(e.target.value))} className="bg-transparent border border-[color:var(--border)] rounded px-2 py-1" />
              </label>
              <button onClick={() => { resetPaperAccount(newCash, newFee); setShowSettings(false); }} className="px-4 py-1.5 bg-[color:var(--accent)] text-white text-xs rounded">Reset Account</button>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="card p-5">
            <h3 className="text-xs text-[color:var(--muted)] uppercase mb-1">Available Cash</h3>
            <div className="text-2xl font-bold font-mono">{bdt(paperCash)}</div>
          </div>
          <div className="card p-5">
            <h3 className="text-xs text-[color:var(--muted)] uppercase mb-1">Total Equity (Approx)</h3>
            <div className="text-2xl font-bold font-mono">{bdt(totalEquity)}</div>
          </div>
        </div>

        <div className="card overflow-hidden">
          <div className="p-4 border-b border-[color:var(--border)]"><h3 className="font-semibold text-sm">Your Holdings</h3></div>
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-[color:var(--muted)] uppercase bg-[color:var(--muted)]/5">
              <tr><th className="px-4 py-3">Symbol</th><th className="px-4 py-3 text-right">Qty</th><th className="px-4 py-3 text-right">Avg Price</th><th className="px-4 py-3 text-center">Trade</th></tr>
            </thead>
            <tbody>
              {holdingsList.map(h => (
                <tr key={h.symbol} className="border-b border-[color:var(--border)] last:border-0">
                  <td className="px-4 py-3 font-medium">{h.symbol}</td>
                  <td className="px-4 py-3 text-right font-mono">{h.qty}</td>
                  <td className="px-4 py-3 text-right font-mono">{bdt(h.avg)}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-center gap-2">
                       <input type="number" placeholder="Qty" onChange={e=>setTradeQty({...tradeQty, [h.symbol]: Number(e.target.value)})} className="w-16 bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-xs" />
                       <button onClick={() => executeTrade('BUY', h.avg, tradeQty[h.symbol] || 10)} className="p-1.5 bg-[color:var(--bull)] text-white rounded"><ArrowUpRight size={12}/></button>
                       <button onClick={() => executeTrade('SELL', h.avg, tradeQty[h.symbol] || 10)} className="p-1.5 bg-[color:var(--bear)] text-white rounded"><ArrowDownRight size={12}/></button>
                    </div>
                  </td>
                </tr>
              ))}
              {!holdingsList.length && <tr><td colSpan={4} className="p-8 text-center text-[color:var(--muted)]">No holdings. Go to chart to buy.</td></tr>}
            </tbody>
          </table>
        </div>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

# ========== 5. Chart Page (Bottom Tabs & Heatmap) ==========
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
import CompanyInfoModal from '@/components/CompanyInfoModal';
import { useAppStore } from '@/store/useAppStore';
import { useQuery } from '@tanstack/react-query';
import { bdt } from '@/lib/format';

export default function ChartPage() {
  const [activeTab, setActiveTab] = useState<'trading'|'gainers'|'losers'|'heatmap'|'info'>('trading');
  
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
          
          <div className="card flex-1 flex flex-col min-h-[250px]">
            <div className="flex border-b border-[color:var(--border)] px-2 overflow-x-auto no-scrollbar">
              {['trading', 'gainers', 'losers', 'heatmap', 'info'].map(tab => (
                <button key={tab} onClick={()=>setActiveTab(tab as any)} className={`px-4 py-2 text-xs font-semibold capitalize border-b-2 whitespace-nowrap ${activeTab === tab ? 'border-[color:var(--accent)] text-[color:var(--accent)]' : 'border-transparent text-[color:var(--muted)]'}`}>{tab === 'info' ? 'Company Info' : tab}</button>
              ))}
            </div>
            
            <div className="p-3 flex-1 overflow-y-auto">
              {activeTab === 'trading' && <PaperTradingPanel />}
              {activeTab === 'gainers' && <MoversList type="gainers" />}
              {activeTab === 'losers' && <MoversList type="losers" />}
              {activeTab === 'heatmap' && <Heatmap />}
              {activeTab === 'info' && <div className="text-center pt-8"><CompanyInfoInline /></div>}
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
  const holding = paperHoldings[activeSymbol] || { qty: 0, avg: 0 };
  
  // Get latest price (mock from store or fetch)
  const { data: summary } = useQuery({ queryKey: ['summary', activeSymbol], queryFn: async () => (await (await fetch(`/api/symbols?q=${activeSymbol}`)).json()).data?.[0] });
  const price = summary?.last_close || 0;

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-center">
      <div className="space-y-2">
         <div className="flex justify-between text-xs border-b border-[color:var(--border)] pb-1"><span className="text-[color:var(--muted)]">Cash</span><span className="font-mono font-bold">{bdt(paperCash)}</span></div>
         <div className="flex justify-between text-xs border-b border-[color:var(--border)] pb-1"><span className="text-[color:var(--muted)]">Position</span><span className="font-mono font-bold">{holding.qty} shares @ {bdt(holding.avg)}</span></div>
         <div className="flex justify-between text-xs"><span className="text-[color:var(--muted)]">LTP</span><span className="font-mono font-bold text-[color:var(--accent)]">{bdt(price)}</span></div>
      </div>
      <div className="flex flex-col gap-2">
        <input type="number" value={qty} onChange={e=>setQty(Number(e.target.value))} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm text-center font-mono" placeholder="Qty" />
        <div className="grid grid-cols-2 gap-2">
          <button onClick={() => executeTrade('BUY', price, qty)} className="py-2 rounded bg-[color:var(--bull)] text-white text-sm font-bold">BUY</button>
          <button onClick={() => executeTrade('SELL', price, qty)} className="py-2 rounded bg-[color:var(--bear)] text-white text-sm font-bold">SELL</button>
        </div>
      </div>
    </div>
  );
}

function MoversList({ type }: { type: 'gainers'|'losers' }) {
  const { data } = useQuery({ queryKey: ['movers'], queryFn: async () => (await fetch('/api/movers')).json() });
  const list = data?.[type] || [];
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
      {list.map((s: any) => (
        <div key={s.symbol} className="p-2 border border-[color:var(--border)] rounded flex justify-between items-center bg-[color:var(--bg)]/50">
          <span className="text-xs font-bold">{s.symbol}</span>
          <span className={`text-xs font-mono ${s.pct_change >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>{s.pct_change?.toFixed(2)}%</span>
        </div>
      ))}
    </div>
  );
}

function Heatmap() {
  const { data } = useQuery({ queryKey: ['symbols-all'], queryFn: async () => (await (await fetch('/api/symbols?size=100')).json()).data || [] });
  return (
    <div className="grid grid-cols-3 md:grid-cols-5 gap-1">
      {data?.map((s: any) => {
        const pct = s.pct_change || 0;
        const bg = pct > 0 ? `rgba(22,163,74,${Math.min(Math.abs(pct)/5, 0.8)})` : pct < 0 ? `rgba(220,38,38,${Math.min(Math.abs(pct)/5, 0.8)})` : 'var(--border)';
        return (
          <div key={s.symbol} style={{ backgroundColor: bg }} className="p-2 rounded text-center border border-black/10">
            <div className="text-[10px] font-bold text-white drop-shadow-md">{s.symbol}</div>
            <div className="text-[9px] text-white/90 drop-shadow-md">{pct.toFixed(2)}%</div>
          </div>
        );
      })}
    </div>
  );
}

function CompanyInfoInline() {
  const symbol = useAppStore(s => s.activeSymbol);
  const { data } = useQuery({ queryKey: ['company', symbol], queryFn: async () => (await (await fetch(`/api/company/${symbol}`)).json()).data });
  if (!data) return <div className="text-xs text-[color:var(--muted)]">No company info found for {symbol}. Add it in Admin.</div>;
  return (
    <div className="text-left max-w-lg mx-auto p-4 border border-[color:var(--border)] rounded bg-[color:var(--bg)]/30">
      <h3 className="font-bold text-lg mb-1">{data.name}</h3>
      <p className="text-xs text-[color:var(--accent)] mb-2">{data.sector}</p>
      <p className="text-xs leading-relaxed text-[color:var(--muted)]">{data.description}</p>
    </div>
  );
}
EOF

echo ""
echo "✅ V5 Update applied successfully!"
echo "1. Run: npm run dev"
echo "2. Refresh your browser."