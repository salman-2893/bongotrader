#!/usr/bin/env bash
set -e

echo "🚀 Updating Layout (TopBar Single Line & Chart/Bottom Panel Fix)..."

write() { echo "📝 Updating $1"; }

# ========== 1. TopBar (Force single line) ==========
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
      {/* flex-nowrap forces everything into one line. overflow-x-auto handles small screens */}
      <div className="flex flex-nowrap items-center gap-1.5 md:gap-2 px-2 py-1.5 w-full overflow-x-auto no-scrollbar">
        
        <div className="font-bold text-base md:text-lg text-[color:var(--accent)] tracking-tight shrink-0 hidden lg:block">Chartbongo</div>
        
        <div className="shrink-0"><MarketCountdown /></div>
        <div className="shrink-0"><ActiveInstrumentChip /></div>
        
        <button onClick={() => setShowInfo(true)} className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10 shrink-0" title="Company Info">
          <Info size={14}/>
        </button>
        
        {/* MoversTicker will flex to fill the available space */}
        <div className="flex-1 min-w-[80px] overflow-hidden"><MoversTicker /></div>
        
        <div className="flex items-center gap-1.5 shrink-0 ml-auto">
          <Link href="/account" className="flex items-center gap-1.5 px-2 py-1.5 rounded-lg bg-[color:var(--bull)]/10 border border-[color:var(--bull)]/30 text-[color:var(--bull)] hover:bg-[color:var(--bull)]/20 transition-colors shrink-0">
            <Wallet size={14} />
            <span className="font-mono text-xs font-bold hidden sm:block">{bdt(paperCash)}</span>
          </Link>

          <label className="hidden md:flex items-center gap-1 text-xs shrink-0">
            Fee:
            <input type="number" step="0.01" min="0" max="5" value={feePct} onChange={(e) => setFee(parseFloat(e.target.value) || 0)} className="w-12 bg-transparent border border-[color:var(--border)] rounded px-1 py-0.5 text-center" />%
          </label>
          
          <div className="hidden sm:block shrink-0"><LanguageToggle /></div>
          <div className="shrink-0"><ThemeToggle /></div>
          
          <Link href="/admin" className="p-1.5 md:p-2 rounded-lg hover:bg-[color:var(--muted)]/10 text-[color:var(--bear)] hidden md:block shrink-0" title="Admin Panel">
            <Shield size={16} />
          </Link>
          
          <button onClick={() => setShowAlerts(!showAlerts)} className="p-1.5 md:p-2 rounded-lg hover:bg-[color:var(--muted)]/10 relative shrink-0">
            <Bell size={16} />
            <span className="absolute top-1 right-1 w-2 h-2 rounded-full bg-[color:var(--bear)]"></span>
          </button>
          
          <button className="p-1.5 md:p-2 rounded-lg hover:bg-[color:var(--muted)]/10 shrink-0">
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

# ========== 2. MoversTicker (Make it fluid) ==========
write "components/MoversTicker.tsx"
cat > components/MoversTicker.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';

export default function MoversTicker() {
  const { data } = useQuery({ queryKey: ['movers'], queryFn: async () => (await fetch('/api/movers')).json() });
  const gainers = data?.gainers ?? [];
  const losers = data?.losers ?? [];
  const items = [...gainers, ...losers, ...gainers, ...losers];

  return (
    <div className="flex items-center overflow-hidden w-full px-2 py-1 rounded-lg border border-[color:var(--border)] relative bg-[color:var(--bg)]/30">
      <div className="animate-marquee whitespace-nowrap flex items-center">
        {items.map((m: any, i: number) => {
          const up = (m.pct_change ?? 0) >= 0;
          return (
            <span key={i} className="text-[10px] md:text-xs px-2 inline-flex items-center">
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

# ========== 3. Chart Panel (Fit to container) ==========
write "components/ChartPanel.tsx"
cat > components/ChartPanel.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType, MouseEventParams } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';
import { calcIndicator, INDICATOR_DEFS } from '@/lib/indicators/engine';

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
      if (param.point === undefined || !param.time || param.point.x < 0 || param.point.y < 0) setHoverData(null);
      else if (param.seriesData.size > 0) {
        const data = param.seriesData.get(mainSeriesRef.current!) as any;
        if (data) setHoverData(data);
      }
    });

    chartRef.current = chart;
    chartRefs.chart = chart;
    return () => { chart.remove(); chartRefs.chart = null; chartRefs.series = null; };
  }, []);

  useEffect(() => {
    if (!chartRef.current || !data) return;
    const chart = chartRef.current;
    
    if (mainSeriesRef.current) chart.removeSeries(mainSeriesRef.current);
    indSeriesRef.current.forEach(s => chart.removeSeries(s));
    indSeriesRef.current = [];

    const opts = { upColor: '#16A34A', downColor: '#DC2626', wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false };
    let series;
    if (chartType === 'line') series = chart.addLineSeries({ color: '#1E6FD9', lineWidth: 2 });
    else if (chartType === 'area') series = chart.addAreaSeries({ lineColor: '#1E6FD9', topColor: 'rgba(30,111,217,0.4)', bottomColor: 'rgba(30,111,217,0.0)' });
    else if (chartType === 'bar') series = chart.addBarSeries({ upColor: '#16A34A', downColor: '#DC2626' });
    else series = chart.addCandlestickSeries(opts);

    series.setData(data);
    mainSeriesRef.current = series;
    chartRefs.series = series as any;

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
        indSeriesRef.current.push(bbU, bbL);
      } else {
        const s = chart.addLineSeries({ color: ind.color, lineWidth: 2, priceScaleId });
        if (scaleMargins) s.priceScale().applyOptions({ scaleMargins });
        s.setData(data.map((d, i) => ({ time: d.time, value: (values as any[])[i] })).filter(d => d.value != null));
        indSeriesRef.current.push(s);
      }
    });

    chart.timeScale().scrollToRealTime();
  }, [data, chartType, indicators]);

  useEffect(() => {
    chartRef.current?.applyOptions({ layout: { textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540' } });
  }, [theme]);

  return (
    <div className="chart-pane w-full h-full"> {/* CHANGED TO h-full */}
      {hoverData && (
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

# ========== 4. Chart Page (Flex layout to fix heights) ==========
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
    <div className="flex flex-col h-screen overflow-hidden bg-[color:var(--bg)]">
      <TopBar />
      
      {/* Main area fills remaining height */}
      <main className="flex-1 flex flex-col md:flex-row gap-2 p-2 overflow-hidden mb-14">
        
        {/* Sidebar */}
        <aside className="card w-full md:w-[260px] h-[200px] md:h-full shrink-0 overflow-hidden hidden md:block">
          <InstrumentPicker />
        </aside>

        {/* Right Side (Chart + Tabs) */}
        <section className="flex-1 flex flex-col gap-2 min-h-0">
          
          {/* Chart Area (Takes 60% height) */}
          <div className="card flex flex-col flex-[6] min-h-0 overflow-hidden">
            <ChartToolbar />
            <DrawingToolbar />
            <div className="flex-1 relative min-h-0">
              <ChartPanel />
            </div>
          </div>
          
          {/* Bottom Panel (Takes 40% height) */}
          <div className="card flex flex-col flex-[4] min-h-0 overflow-hidden">
            <div className="flex border-b border-[color:var(--border)] px-2 overflow-x-auto no-scrollbar shrink-0">
              {['trading', 'gainers', 'losers', 'heatmap', 'info'].map(tab => (
                <button key={tab} onClick={()=>setActiveTab(tab as any)} className={`px-4 py-2 text-xs font-semibold capitalize border-b-2 whitespace-nowrap ${activeTab === tab ? 'border-[color:var(--accent)] text-[color:var(--accent)]' : 'border-transparent text-[color:var(--muted)]'}`}>{tab === 'info' ? 'Company Info' : tab}</button>
              ))}
            </div>
            
            <div className="p-3 flex-1 overflow-y-auto">
              {activeTab === 'trading' && <PaperTradingPanel />}
              {activeTab === 'gainers' && <MoversList type="gainers" />}
              {activeTab === 'losers' && <MoversList type="losers" />}
              {activeTab === 'heatmap' && <Heatmap />}
              {activeTab === 'info' && <div className="text-center pt-4"><CompanyInfoInline /></div>}
            </div>
          </div>
          
        </section>
      </main>
      
      <BottomTabs />
    </div>
  );
}

function PaperTradingPanel() {
  const { activeSymbol, paperCash, paperHoldings, executeTrade } = useAppStore();
  const [qty, setQty] = useState(10);
  const holding = paperHoldings[activeSymbol] || { qty: 0, avg: 0 };
  
  const { data: summary } = useQuery({ queryKey: ['summary', activeSymbol], queryFn: async () => (await (await fetch(`/api/symbols?q=${activeSymbol}`)).json()).data?.[0] });
  const price = summary?.last_close || 0;

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 items-center">
      <div className="space-y-1">
         <div className="flex justify-between text-xs border-b border-[color:var(--border)] pb-1"><span className="text-[color:var(--muted)]">Cash</span><span className="font-mono font-bold">{bdt(paperCash)}</span></div>
         <div className="flex justify-between text-xs border-b border-[color:var(--border)] pb-1"><span className="text-[color:var(--muted)]">Position</span><span className="font-mono font-bold">{holding.qty} shares @ {bdt(holding.avg)}</span></div>
         <div className="flex justify-between text-xs"><span className="text-[color:var(--muted)]">LTP</span><span className="font-mono font-bold text-[color:var(--accent)]">{bdt(price)}</span></div>
      </div>
      <div className="flex flex-col gap-2">
        <input type="number" value={qty} onChange={e=>setQty(Number(e.target.value))} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-1.5 text-sm text-center font-mono" placeholder="Qty" />
        <div className="grid grid-cols-2 gap-2">
          <button onClick={() => executeTrade('BUY', price, qty)} className="py-1.5 rounded bg-[color:var(--bull)] text-white text-sm font-bold">BUY</button>
          <button onClick={() => executeTrade('SELL', price, qty)} className="py-1.5 rounded bg-[color:var(--bear)] text-white text-sm font-bold">SELL</button>
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
          <div key={s.symbol} style={{ backgroundColor: bg }} className="p-1.5 rounded text-center border border-black/10">
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
    <div className="text-left max-w-lg mx-auto p-3 border border-[color:var(--border)] rounded bg-[color:var(--bg)]/30">
      <h3 className="font-bold text-sm mb-1">{data.name}</h3>
      <p className="text-[10px] text-[color:var(--accent)] mb-1">{data.sector}</p>
      <p className="text-xs leading-relaxed text-[color:var(--muted)]">{data.description}</p>
    </div>
  );
}
EOF

echo ""
echo "✅ Layout Fixed!"
echo "1. Refresh your browser (Ctrl+Shift+R)."