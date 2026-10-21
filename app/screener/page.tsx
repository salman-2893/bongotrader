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
