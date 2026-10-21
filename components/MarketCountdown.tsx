'use client';
import { useEffect, useState } from 'react';
import { Clock } from 'lucide-react';
import { nextDseEvent, fmtCountdown } from '@/lib/dse';
import { useAppStore } from '@/store/useAppStore';

export default function MarketCountdown() {
  const [tick, setTick] = useState(Date.now());
  const lang = useAppStore((s) => s.lang);
  useEffect(() => {
    const id = setInterval(() => setTick(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);
  const ev = nextDseEvent(new Date(tick));
  const remaining = ev.targetMs - tick;
  const isOpen = ev.label === 'CLOSE';
  return (
    <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg"
      style={{ background: isOpen ? 'rgba(22,163,74,0.12)' : 'rgba(220,38,38,0.12)' }}>
      <Clock size={14} className={isOpen ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'} />
      <span className="text-xs font-medium">
        {isOpen ? (lang === 'bn' ? 'বন্ধ হবে:' : 'CLOSE in:') : (lang === 'bn' ? 'খুলবে:' : 'OPEN in:')}
      </span>
      <span className="font-mono text-xs tabular-nums">{fmtCountdown(remaining)}</span>
    </div>
  );
}
