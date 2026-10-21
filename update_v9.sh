#!/usr/bin/env bash
set -e

echo "🚀 Updating to V9 (Portal Fixes for Dropdown & Modals)..."

write() { echo "📝 Updating $1"; }

# ========== 1. ActiveInstrumentChip (Portal & Fixed Positioning) ==========
write "components/ActiveInstrumentChip.tsx"
cat > components/ActiveInstrumentChip.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { ChevronDown, Search, X } from 'lucide-react';
import { bdt } from '@/lib/format';
import { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';

export default function ActiveInstrumentChip() {
  const { activeSymbol: symbol, setSymbol } = useAppStore();
  const [isOpen, setIsOpen] = useState(false);
  const [search, setSearch] = useState('');
  const [mounted, setMounted] = useState(false);
  const btnRef = useRef<HTMLButtonElement>(null);
  const dropRef = useRef<HTMLDivElement>(null);

  useEffect(() => { setMounted(true); }, []);

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
      const r = await fetch(`/api/symbols?q=${search}&size=50`);
      return (await r.json()).data || [];
    },
    enabled: isOpen,
  });

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (dropRef.current && !dropRef.current.contains(e.target as Node) && btnRef.current && !btnRef.current.contains(e.target as Node)) setIsOpen(false);
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const up = (data?.pct_change ?? 0) >= 0;

  // Calculate position for portal
  const rect = btnRef.current?.getBoundingClientRect();

  return (
    <>
      <button ref={btnRef} onClick={() => setIsOpen(!isOpen)} className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10 transition shrink-0">
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

      {isOpen && mounted && rect && createPortal(
        <div ref={dropRef} 
          className="fixed w-72 card p-2 z-[9999] shadow-2xl flex flex-col"
          style={{ top: rect.bottom + 8, left: Math.max(10, Math.min(rect.left, window.innerWidth - 300)) }}>
          
          <div className="flex items-center gap-2 px-2 py-1.5 border-b border-[color:var(--border)] mb-2 shrink-0">
            <Search size={14} className="text-[color:var(--muted)]" />
            <input autoFocus value={search} onChange={e => setSearch(e.target.value)} placeholder="Search symbol..." className="w-full bg-transparent text-sm outline-none" />
            <button onClick={() => setIsOpen(false)}><X size={14} className="text-[color:var(--muted)]" /></button>
          </div>
          <div className="overflow-y-auto max-h-[60vh] pr-1">
            {searchResults?.map((s: any) => (
              <button key={s.symbol} onClick={() => { setSymbol(s.symbol); setIsOpen(false); }} className="w-full text-left px-2 py-1.5 flex items-center justify-between text-xs hover:bg-[color:var(--muted)]/10 rounded">
                <span className="font-medium">{s.symbol}</span>
                <span className={(s.pct_change ?? 0) >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{(s.pct_change ?? 0).toFixed(2)}%</span>
              </button>
            ))}
            {searchResults?.length === 0 && <div className="text-center text-xs text-[color:var(--muted)] p-2">No results</div>}
          </div>
        </div>,
        document.body
      )}
    </>
  );
}
EOF

# ========== 2. Drawing Canvas (Portal for Text Modal) ==========
write "components/DrawingCanvas.tsx"
cat > components/DrawingCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
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

  const [mounted, setMounted] = useState(false);
  const [showTextModal, setShowTextModal] = useState(false);
  const [pendingTextPos, setPendingTextPos] = useState<any>(null);
  const [inputText, setInputText] = useState('');

  useEffect(() => { setMounted(true); }, []);

  const toTimePrice = (x: number, y: number) => {
    const { chart, series } = chartRefs;
    if (!chart || !series) return null;
    const time = chart.timeScale().coordinateToTime(x);
    const price = series.coordinateToPrice(y);
    let t = Math.floor(Date.now() / 1000); 
    if (time != null) {
      if (typeof time === 'number') t = time;
      else if (typeof time === 'object' && 'year' in time) t = Math.floor(Date.UTC((time as any).year, (time as any).month - 1, (time as any).day) / 1000);
    }
    return { time: t, price: price ?? 0 };
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
        setPendingTextPos(tp);
        setInputText('');
        setShowTextModal(true);
        return;
      }

      e.preventDefault(); e.stopPropagation();
      const tp = toTimePrice(x, y);
      if (!tp) return;
      
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
      
      {/* TEXT MODAL PORTAL */}
      {showTextModal && mounted && createPortal(
        <div className="fixed inset-0 z-[9999] bg-black/60 flex items-center justify-center backdrop-blur-sm p-4">
          <div className="card p-5 w-full max-w-sm shadow-2xl relative border border-[color:var(--accent)]">
            <button onClick={() => setShowTextModal(false)} className="absolute top-3 right-3 text-[color:var(--muted)] hover:text-[color:var(--text)]"><X size={18}/></button>
            <h3 className="font-semibold mb-4 text-lg">Add Chart Note</h3>
            <input autoFocus value={inputText} onChange={(e) => setInputText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && saveText()} className="w-full bg-[color:var(--bg)] border border-[color:var(--border)] rounded-lg px-4 py-2 text-sm mb-4 outline-none focus:border-[color:var(--accent)]" placeholder="Type your note here..." />
            <div className="flex justify-end gap-2">
              <button onClick={() => setShowTextModal(false)} className="px-4 py-2 text-sm rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">Cancel</button>
              <button onClick={saveText} className="px-4 py-2 text-sm rounded-lg bg-[color:var(--accent)] text-white font-medium hover:opacity-90">Save Note</button>
            </div>
          </div>
        </div>,
        document.body
      )}
    </>
  );
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}
EOF

# ========== 3. TopBar (Remove overflow-x-auto to prevent clipping) ==========
write "components/TopBar.tsx"
cat > components/TopBar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import MarketCountdown from './MarketCountdown';
import ActiveInstrumentChip from './ActiveInstrumentChip';
import MoversTicker from './MoversTicker';
import ThemeToggle from './ThemeToggle';
import LanguageToggle from './LanguageToggle';
import CompanyInfoModal from './CompanyInfoModal';
import { useAppStore } from '@/store/useAppStore';
import { bdt } from '@/lib/format';
import { Bell, User, Info, Shield, Wallet } from 'lucide-react';

export default function TopBar() {
  const { feePct, setFee, paperCash } = useAppStore();
  const [showAlerts, setShowAlerts] = useState(false);
  const [showInfo, setShowInfo] = useState(false);

  return (
    <header className="sticky top-0 z-40 backdrop-blur border-b border-[color:var(--border)]" style={{ background: 'var(--card-bg)' }}>
      <div className="flex flex-wrap items-center gap-2 md:gap-3 px-3 py-2">
        <div className="font-bold text-lg text-[color:var(--accent)] tracking-tight hidden lg:block">Chartbongo</div>
        
        <MarketCountdown />
        <ActiveInstrumentChip />
        
        <button onClick={() => setShowInfo(true)} className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10 shrink-0" title="Company Info">
          <Info size={14}/>
        </button>
        
        <div className="hidden md:block"><MoversTicker /></div>
        
        <div className="ml-auto flex items-center gap-2 shrink-0">
          <Link href="/account" className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[color:var(--bull)]/10 border border-[color:var(--bull)]/30 text-[color:var(--bull)] hover:bg-[color:var(--bull)]/20 transition-colors">
            <Wallet size={14} />
            <span className="font-mono text-xs font-bold">{bdt(paperCash)}</span>
          </Link>

          <label className="hidden sm:flex items-center gap-1 text-xs">
            Fee:
            <input type="number" step="0.01" min="0" max="5" value={feePct} onChange={(e) => setFee(parseFloat(e.target.value) || 0)} className="w-12 bg-transparent border border-[color:var(--border)] rounded px-1 py-0.5 text-center" />%
          </label>
          
          <div className="hidden sm:block"><LanguageToggle /></div>
          <ThemeToggle />
          
          <Link href="/admin" className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 text-[color:var(--bear)] hidden md:block" title="Admin Panel">
            <Shield size={16} />
          </Link>
          
          <button onClick={() => setShowAlerts(!showAlerts)} className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 relative">
            <Bell size={16} />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-[color:var(--bear)]"></span>
          </button>
          
          <button className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10">
            <User size={16} />
          </button>
        </div>
      </div>

      {showAlerts && (
        <div className="absolute right-2 top-14 w-80 card p-0 overflow-hidden shadow-2xl z-50">
          <div className="p-3 border-b border-[color:var(--border)] bg-[color:var(--bg)]/50 font-semibold text-sm">Notifications</div>
          <div className="p-4 text-center text-xs text-[color:var(--muted)]">No new notifications</div>
        </div>
      )}
      
      {showInfo && <CompanyInfoModal onClose={() => setShowInfo(false)} />}
    </header>
  );
}
EOF

# ========== 4. Global CSS (Ensure no overflow clipping) ==========
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

html, body { background: var(--bg); color: var(--text); transition: background 300ms ease, color 300ms ease; overflow-x: hidden; }
[data-theme="light"] body { background: linear-gradient(180deg, #EEF5FF 0%, #DCEBFF 100%); min-height: 100vh; }

.card { background: var(--card-bg); box-shadow: var(--card-shadow); border: 1px solid var(--border); border-radius: 12px; backdrop-filter: blur(8px); }
.chart-pane { background: var(--panel); border-radius: 12px; position: relative; }

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

echo ""
echo "✅ V9 Update applied successfully!"
echo "1. Stop the server (Ctrl+C) and run: npm run dev"
echo "2. Refresh your browser."