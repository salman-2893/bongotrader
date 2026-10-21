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
