'use client';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Search } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';

export default function InstrumentPicker() {
  const [q, setQ] = useState('');
  const { activeSymbol, setSymbol } = useAppStore();
  const { data } = useQuery({
    queryKey: ['symbols', q],
    queryFn: async () => {
      const r = await fetch(`/api/symbols?q=${encodeURIComponent(q)}&size=100`);
      return r.json();
    },
  });
  const items = data?.data ?? [];
  return (
    <div>
      <div className="flex items-center gap-2 px-2 py-1.5 border-b border-[color:var(--border)]">
        <Search size={14} className="text-[color:var(--muted)]" />
        <input value={q} onChange={(e) => setQ(e.target.value)}
          placeholder="Search symbol…" className="w-full bg-transparent text-sm outline-none" />
      </div>
      <div className="text-[10px] text-[color:var(--muted)] px-2 py-1">
        {(data?.total ?? 0).toLocaleString()} instruments
      </div>
      <ul className="max-h-[60vh] overflow-y-auto">
        {items.map((s: any) => {
          const up = (s.pct_change ?? 0) >= 0;
          return (
            <li key={s.symbol}>
              <button onClick={() => setSymbol(s.symbol)}
                className={`w-full text-left px-2 py-1.5 flex items-center justify-between text-xs hover:bg-[color:var(--muted)]/10 ${activeSymbol === s.symbol ? 'bg-[color:var(--accent)]/10' : ''}`}>
                <span className="flex items-center gap-1.5">
                  <span className="font-medium">{s.symbol}</span>
                  {!s.is_active && (
                    <span className="text-[9px] px-1 rounded bg-[color:var(--muted)]/20 text-[color:var(--muted)]">Inactive</span>
                  )}
                </span>
                <span className={up ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>
                  {up ? '+' : ''}{(s.pct_change ?? 0).toFixed(2)}%
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
