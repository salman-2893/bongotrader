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
