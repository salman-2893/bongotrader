'use client';
import { useEffect, useState } from 'react';
import { AlertTriangle } from 'lucide-react';

export default function HealthGate({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<'checking' | 'ok' | 'down'>('checking');
  const check = async () => {
    setState('checking');
    try {
      const r = await fetch('/api/health', { cache: 'no-store' });
      const j = await r.json();
      setState(j.db === 'ok' ? 'ok' : 'down');
    } catch { setState('down'); }
  };
  useEffect(() => { check(); }, []);
  if (state === 'checking')
    return <div className="min-h-screen flex items-center justify-center">
      <div className="animate-pulse text-[color:var(--muted)]">Loading…</div></div>;
  if (state === 'down')
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4 text-center p-6">
        <AlertTriangle size={48} className="text-[color:var(--bear)]" />
        <div className="text-lg font-semibold">Network error — could not reach market data.</div>
        <button onClick={check} className="px-4 py-2 rounded-lg bg-[color:var(--accent)] text-white font-medium">Retry</button>
      </div>
    );
  return <>{children}</>;
}
