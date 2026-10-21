'use client';
import { bdt, pct } from '@/lib/format';

interface Props {
  time: number | null;
  equity: number;
  cash: number;
  position: number;
  realised: number;
  unrealised: number;
  drawdown: number;
  winRate: number;
  sharpe: number;
  trades: number;
}

export default function ReplayMetrics(p: Props) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-xs">
      <Cell label="Bar date" value={p.time ? new Date(p.time * 1000).toISOString().slice(0, 10) : '—'} />
      <Cell label="Equity" value={bdt(p.equity)} />
      <Cell label="Cash" value={bdt(p.cash)} />
      <Cell label="Position" value={`${p.position} sh`} />
      <Cell label="Realised PnL" value={bdt(p.realised)} tone={p.realised >= 0 ? 'up' : 'down'} />
      <Cell label="Unrealised PnL" value={bdt(p.unrealised)} tone={p.unrealised >= 0 ? 'up' : 'down'} />
      <Cell label="Drawdown" value={pct(-p.drawdown)} tone="down" />
      <Cell label="Win rate" value={`${p.winRate.toFixed(1)}%`} />
      <Cell label="Sharpe" value={p.sharpe.toFixed(2)} />
      <Cell label="Trades" value={String(p.trades)} />
    </div>
  );
}

function Cell({ label, value, tone }: { label: string; value: string; tone?: 'up' | 'down' }) {
  const color = tone === 'up' ? 'text-[color:var(--bull)]' : tone === 'down' ? 'text-[color:var(--bear)]' : '';
  return (
    <div className="p-2 rounded-lg border border-[color:var(--border)]">
      <div className="text-[10px] uppercase text-[color:var(--muted)]">{label}</div>
      <div className={`font-mono tabular-nums ${color}`}>{value}</div>
    </div>
  );
}
