#!/usr/bin/env bash
set -e

echo "🚀 Updating to V7 (Text Fix, Screener, Bottom Tabs)..."

write() { echo "📝 Updating $1"; }

# ========== 1. Bottom Tabs (Add Screener) ==========
write "components/BottomTabs.tsx"
cat > components/BottomTabs.tsx << 'EOF'
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Wallet, LineChart, FlaskConical, Filter } from 'lucide-react';
import { useTranslations } from 'next-intl';

const tabs = [
  { href: '/chart', key: 'chart', Icon: LineChart, label: 'Chart' },
  { href: '/screener', key: 'screener', Icon: Filter, label: 'Screener' },
  { href: '/account', key: 'account', Icon: Wallet, label: 'Account' },
  { href: '/backtest', key: 'backtesting', Icon: FlaskConical, label: 'Backtest' },
] as const;

export default function BottomTabs() {
  const path = usePathname();
  return (
    <nav className="fixed bottom-0 inset-x-0 z-40 border-t border-[color:var(--border)] backdrop-blur"
      style={{ background: 'var(--card-bg)' }}>
      <ul className="grid grid-cols-4">
        {tabs.map(({ href, key, Icon, label }) => {
          const active = path.startsWith(href);
          return (
            <li key={href}>
              <Link href={href}
                className={`flex flex-col items-center py-2 text-xs gap-1 ${active ? 'text-[color:var(--accent)] font-semibold' : 'text-[color:var(--muted)]'}`}>
                <Icon size={18} />
                {label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
EOF

# ========== 2. Screener Page ==========
write "app/screener/page.tsx"
mkdir -p app/screener
cat > app/screener/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import { useAppStore } from '@/store/useAppStore';
import { bdt, num } from '@/lib/format';
import { Search, SlidersHorizontal } from 'lucide-react';

export default function ScreenerPage() {
  const router = useRouter();
  const { setSymbol } = useAppStore();
  const [filters, setFilters] = useState({ minPrice: '', maxPrice: '', minChange: '', maxChange: '', minVol: '' });

  const { data } = useQuery({
    queryKey: ['screener-data'],
    queryFn: async () => {
      const r = await fetch(`/api/symbols?size=1000`);
      return (await r.json()).data || [];
    },
  });

  const filtered = (data || []).filter((s: any) => {
    const price = s.last_close || 0;
    const change = s.pct_change || 0;
    const vol = s.last_volume || 0;
    if (filters.minPrice && price < Number(filters.minPrice)) return false;
    if (filters.maxPrice && price > Number(filters.maxPrice)) return false;
    if (filters.minChange && change < Number(filters.minChange)) return false;
    if (filters.maxChange && change > Number(filters.maxChange)) return false;
    if (filters.minVol && vol < Number(filters.minVol)) return false;
    return true;
  });

  const handleTrade = (sym: string) => {
    setSymbol(sym);
    router.push('/chart');
  };

  return (
    <>
      <TopBar />
      <main className="p-3 pb-20 max-w-6xl mx-auto space-y-3">
        <div className="card p-3">
          <h2 className="text-sm font-bold mb-3 flex items-center gap-2"><SlidersHorizontal size={16}/> Screener Filters</h2>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-2">
            <input type="number" placeholder="Min Price" value={filters.minPrice} onChange={e=>setFilters({...filters, minPrice: e.target.value})} className="bg-[color:var(--bg)] border border-[color:var(--border)] rounded px-2 py-1.5 text-xs" />
            <input type="number" placeholder="Max Price" value={filters.maxPrice} onChange={e=>setFilters({...filters, maxPrice: e.target.value})} className="bg-[color:var(--bg)] border border-[color:var(--border)] rounded px-2 py-1.5 text-xs" />
            <input type="number" placeholder="Min Change %" value={filters.minChange} onChange={e=>setFilters({...filters, minChange: e.target.value})} className="bg-[color:var(--bg)] border border-[color:var(--border)] rounded px-2 py-1.5 text-xs" />
            <input type="number" placeholder="Max Change %" value={filters.maxChange} onChange={e=>setFilters({...filters, maxChange: e.target.value})} className="bg-[color:var(--bg)] border border-[color:var(--border)] rounded px-2 py-1.5 text-xs" />
            <input type="number" placeholder="Min Volume" value={filters.minVol} onChange={e=>setFilters({...filters, minVol: e.target.value})} className="bg-[color:var(--bg)] border border-[color:var(--border)] rounded px-2 py-1.5 text-xs" />
          </div>
        </div>

        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-xs text-left">
              <thead className="bg-[color:var(--muted)]/10 text-[color:var(--muted)] uppercase">
                <tr>
                  <th className="px-3 py-2">Symbol</th>
                  <th className="px-3 py-2 text-right">LTP (৳)</th>
                  <th className="px-3 py-2 text-right">Change %</th>
                  <th className="px-3 py-2 text-right">Volume</th>
                  <th className="px-3 py-2 text-center">Action</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((s: any) => {
                  const up = (s.pct_change || 0) >= 0;
                  return (
                    <tr key={s.symbol} className="border-t border-[color:var(--border)] hover:bg-[color:var(--muted)]/5">
                      <td className="px-3 py-2 font-semibold">{s.symbol} {!s.is_active && <span className="text-[9px] text-[color:var(--muted)]">(Inactive)</span>}</td>
                      <td className="px-3 py-2 text-right font-mono">{bdt(s.last_close || 0)}</td>
                      <td className={`px-3 py-2 text-right font-mono ${up ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>{up ? '+' : ''}{(s.pct_change || 0).toFixed(2)}%</td>
                      <td className="px-3 py-2 text-right font-mono">{num(s.last_volume || 0)}</td>
                      <td className="px-3 py-2 text-center">
                        <button onClick={() => handleTrade(s.symbol)} className="px-2 py-1 bg-[color:var(--accent)]/20 text-[color:var(--accent)] rounded font-medium hover:bg-[color:var(--accent)]/30">Chart</button>
                      </td>
                    </tr>
                  );
                })}
                {filtered.length === 0 && <tr><td colSpan={5} className="p-4 text-center text-[color:var(--muted)]">No instruments match your filters.</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

# ========== 3. API Symbols Limit Fix ==========
write "app/api/symbols/route.ts"
cat > app/api/symbols/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get('q') ?? '';
  const page = parseInt(req.nextUrl.searchParams.get('page') ?? '0');
  const size = Math.min(parseInt(req.nextUrl.searchParams.get('size') ?? '50'), 2000); // Increased limit for screener
  const sb = adminClient();
  
  let query = sb
    .from('mv_daily_summary')
    .select('symbol,display_name,is_active,last_close,pct_change,last_volume', { count: 'exact' })
    .order('display_name', { ascending: true })
    .range(page * size, page * size + size - 1);
    
  if (q) query = query.ilike('display_name', `%${q}%`);
  
  const { data, count, error } = await query;
  if (error) return NextResponse.json({ error: 'db' }, { status: 500 });
  return NextResponse.json({ data, total: count ?? 0, page, size });
}
EOF

# ========== 4. Chart Page (Ensure Tabs Render) ==========
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
    <div className="grid grid-cols-3 md:grid-cols-6 gap-1">
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

# ========== 5. Drawing Canvas (Ultimate Text Fix) ==========
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
    
    // Fallback if clicked in empty space
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
      {showTextModal && (
        <div className="absolute inset-0 z-[100] bg-black/50 flex items-center justify-center backdrop-blur-sm">
          <div className="card p-4 w-72 shadow-2xl relative">
            <button onClick={() => setShowTextModal(false)} className="absolute top-2 right-2 text-[color:var(--muted)] hover:text-[color:var(--text)]"><X size={16}/></button>
            <h3 className="font-semibold mb-3">Add Text Note</h3>
            <input autoFocus value={inputText} onChange={(e) => setInputText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && saveText()} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm mb-3" placeholder="Type your note here..." />
            <div className="flex justify-end gap-2">
              <button onClick={() => setShowTextModal(false)} className="px-3 py-1.5 text-xs rounded border border-[color:var(--border)]">Cancel</button>
              <button onClick={saveText} className="px-3 py-1.5 text-xs rounded bg-[color:var(--accent)] text-white">Add Note</button>
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

# ========== 6. Update i18n keys ==========
write "messages/en.json"
cat > messages/en.json << 'EOF'
{
  "nav": { "account": "Account", "chart": "Chart", "backtesting": "Backtest", "screener": "Screener" },
  "market": { "openIn": "OPEN in", "closeIn": "CLOSE in", "closed": "Market Closed" },
  "chart": { "inactive": "Inactive", "saveImage": "Save as image" },
  "actions": { "retry": "Retry", "connect": "Connect Telegram" },
  "errors": { "network": "Network error — could not reach market data." }
}
EOF

write "messages/bn.json"
cat > messages/bn.json << 'EOF'
{
  "nav": { "account": "অ্যাকাউন্ট", "chart": "চার্ট", "backtesting": "ব্যাকটেস্ট", "screener": "স্ক্রিনার" },
  "market": { "openIn": "খুলবে", "closeIn": "বন্ধ হবে", "closed": "মার্কেট বন্ধ" },
  "chart": { "inactive": "নিষ্ক্রিয়", "saveImage": "ছবি সংরক্ষণ" },
  "actions": { "retry": "আবার চেষ্টা", "connect": "টেলিগ্রাম সংযুক্ত" },
  "errors": { "network": "নেটওয়ার্ক ত্রুটি — মার্কেট ডেটা লোড হয়নি।" }
}
EOF

echo ""
echo "✅ V7 Update applied successfully!"
echo "1. Stop the server (Ctrl+C) and run: npm run dev"
echo "2. Refresh your browser."