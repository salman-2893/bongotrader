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
      
      <main className="flex-1 flex flex-col md:flex-row gap-2 p-2 overflow-hidden mb-14">
        
        {/* Sidebar */}
        <aside className="card w-full md:w-[260px] h-full shrink-0 overflow-hidden hidden md:block">
          <InstrumentPicker />
        </aside>

        {/* Right Side (Chart + Tabs) */}
        <section className="flex-1 flex flex-col gap-2 min-h-0">
          
          {/* Chart Area (Takes all remaining space) */}
          <div className="card flex flex-col flex-1 min-h-0 overflow-hidden">
            <ChartToolbar />
            <DrawingToolbar />
            <div className="flex-1 relative min-h-0">
              <ChartPanel />
            </div>
          </div>
          
          {/* Bottom Panel (Fixed compact height) */}
          <div className="card flex flex-col shrink-0 h-[160px] md:h-[180px] overflow-hidden">
            <div className="flex border-b border-[color:var(--border)] px-2 overflow-x-auto no-scrollbar shrink-0">
              {['trading', 'gainers', 'losers', 'heatmap', 'info'].map(tab => (
                <button key={tab} onClick={()=>setActiveTab(tab as any)} className={`px-4 py-2 text-xs font-semibold capitalize border-b-2 whitespace-nowrap ${activeTab === tab ? 'border-[color:var(--accent)] text-[color:var(--accent)]' : 'border-transparent text-[color:var(--muted)]'}`}>{tab === 'info' ? 'Company Info' : tab}</button>
              ))}
            </div>
            
            <div className="p-2 flex-1 overflow-y-auto">
              {activeTab === 'trading' && <PaperTradingPanel />}
              {activeTab === 'gainers' && <MoversList type="gainers" />}
              {activeTab === 'losers' && <MoversList type="losers" />}
              {activeTab === 'heatmap' && <Heatmap />}
              {activeTab === 'info' && <div className="text-center pt-2"><CompanyInfoInline /></div>}
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
    <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 h-full pt-1">
      
      {/* Info Panel */}
      <div className="flex flex-wrap gap-4 text-xs font-mono bg-[color:var(--bg)]/40 p-2 rounded-lg border border-[color:var(--border)] w-full md:w-auto">
         <div className="flex flex-col"><span className="text-[10px] text-[color:var(--muted)] uppercase tracking-wider">Cash</span><span className="font-bold text-sm">{bdt(paperCash)}</span></div>
         <div className="flex flex-col"><span className="text-[10px] text-[color:var(--muted)] uppercase tracking-wider">Position</span><span className="font-bold text-sm">{holding.qty} <span className="text-[10px] font-normal text-[color:var(--muted)]">@ {bdt(holding.avg)}</span></span></div>
         <div className="flex flex-col"><span className="text-[10px] text-[color:var(--muted)] uppercase tracking-wider">LTP</span><span className="font-bold text-sm text-[color:var(--accent)]">{bdt(price)}</span></div>
      </div>
      
      {/* Trade Controls */}
      <div className="flex gap-2 w-full md:w-auto">
        <div className="relative flex-1 md:w-32">
          <input type="number" value={qty} onChange={e=>setQty(Number(e.target.value))} className="w-full bg-[color:var(--bg)] border border-[color:var(--border)] rounded px-3 py-2 text-sm text-center font-mono focus:border-[color:var(--accent)] outline-none" placeholder="Qty" />
          <span className="absolute left-2 top-1/2 -translate-y-1/2 text-[10px] text-[color:var(--muted)]">Qty</span>
        </div>
        <button onClick={() => executeTrade('BUY', price, qty)} className="px-6 py-2 rounded bg-[color:var(--bull)] hover:opacity-90 text-white text-sm font-bold shadow-lg">BUY</button>
        <button onClick={() => executeTrade('SELL', price, qty)} className="px-6 py-2 rounded bg-[color:var(--bear)] hover:opacity-90 text-white text-sm font-bold shadow-lg">SELL</button>
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
    <div className="text-left max-w-lg mx-auto p-2 border border-[color:var(--border)] rounded bg-[color:var(--bg)]/30">
      <h3 className="font-bold text-sm mb-1">{data.name}</h3>
      <p className="text-[10px] text-[color:var(--accent)] mb-1">{data.sector}</p>
      <p className="text-xs leading-relaxed text-[color:var(--muted)] truncate">{data.description}</p>
    </div>
  );
}
