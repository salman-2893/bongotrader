'use client';
import { Download } from 'lucide-react';
import { bdt, dt, pct } from '@/lib/format';
import type { Trade } from '@/lib/strategy/types';

export default function TradeLog({ trades }: { trades: Trade[] }) {
  const downloadPDF = () => {
    const win = window.open('', '_blank');
    if (!win) return;
    const rows = trades.map((t, i) => `
      <tr>
        <td>${i + 1}</td><td>${t.strategy}</td><td>${t.symbol}</td><td>${t.side}</td>
        <td>${t.trigger}</td><td>${t.qty}</td><td>${bdt(t.price)}</td><td>${bdt(t.fee)}</td>
        <td>${t.pnl != null ? bdt(t.pnl) : '—'}</td>
        <td>${t.pnlPct != null ? pct(t.pnlPct) : '—'}</td>
        <td>${dt(t.time)}</td>
      </tr>`).join('');
    win.document.write(`
      <html><head><title>Bongotrader — Trade Log</title>
      <style>
        body { font-family: -apple-system, sans-serif; padding: 24px; color: #0A2540; }
        h1 { font-size: 20px; margin-bottom: 4px; }
        .muted { color: #4A6A8A; font-size: 12px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; font-size: 11px; }
        th, td { padding: 6px 8px; border-bottom: 1px solid #BFD9FF; text-align: left; }
        th { background: #EEF5FF; }
      </style></head><body>
        <h1>Bongotrader — Trade Log</h1>
        <div class="muted">${trades.length} trades · generated ${new Date().toLocaleString()}</div>
        <table><thead><tr>
          <th>#</th><th>Strategy</th><th>Symbol</th><th>Side</th><th>Trigger</th>
          <th>Qty</th><th>Price</th><th>Fee</th><th>PnL</th><th>PnL %</th><th>Date</th>
        </tr></thead><tbody>${rows}</tbody></table>
      </body></html>`);
    win.document.close();
    win.onload = () => win.print();
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-2">
        <h3 className="font-semibold">Trade Log <span className="text-xs text-[color:var(--muted)]">({trades.length})</span></h3>
        <button onClick={downloadPDF} disabled={!trades.length}
          className="flex items-center gap-1 text-xs px-2 py-1 rounded bg-[color:var(--accent)] text-white disabled:opacity-50">
          <Download size={12} /> PDF
        </button>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-xs">
          <thead className="text-[10px] uppercase text-[color:var(--muted)]">
            <tr>
              <th className="text-left p-1">#</th><th className="text-left p-1">Strategy</th>
              <th className="text-left p-1">Side</th><th className="text-left p-1">Trigger</th>
              <th className="text-right p-1">Qty</th><th className="text-right p-1">Price</th>
              <th className="text-right p-1">Fee</th><th className="text-right p-1">PnL</th>
              <th className="text-right p-1">PnL%</th><th className="text-left p-1">Date</th>
            </tr>
          </thead>
          <tbody>
            {trades.map((t, i) => (
              <tr key={t.id} className="border-t border-[color:var(--border)]">
                <td className="p-1">{i + 1}</td>
                <td className="p-1">{t.strategy}</td>
                <td className={`p-1 font-medium ${t.side === 'BUY' ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>{t.side}</td>
                <td className="p-1 text-[color:var(--muted)]">{t.trigger}</td>
                <td className="p-1 text-right tabular-nums">{t.qty}</td>
                <td className="p-1 text-right tabular-nums">{bdt(t.price)}</td>
                <td className="p-1 text-right tabular-nums">{bdt(t.fee)}</td>
                <td className={`p-1 text-right tabular-nums ${t.pnl != null ? (t.pnl >= 0 ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]') : ''}`}>
                  {t.pnl != null ? bdt(t.pnl) : '—'}
                </td>
                <td className="p-1 text-right tabular-nums">{t.pnlPct != null ? pct(t.pnlPct) : '—'}</td>
                <td className="p-1">{dt(t.time)}</td>
              </tr>
            ))}
            {!trades.length && (
              <tr><td colSpan={10} className="p-4 text-center text-[color:var(--muted)]">No trades yet — configure a strategy and press Play.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
