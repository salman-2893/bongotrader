'use client';
import { useState } from 'react';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import { useAppStore } from '@/store/useAppStore';
import { bdt, pct } from '@/lib/format';
import { Settings, ArrowUpRight, ArrowDownRight } from 'lucide-react';

export default function AccountPage() {
  const { paperCash, paperHoldings, executeTrade, resetPaperAccount, feePct } = useAppStore();
  const [showSettings, setShowSettings] = useState(false);
  const [newCash, setNewCash] = useState(100000);
  const [newFee, setNewFee] = useState(feePct);
  const [tradeQty, setTradeQty] = useState<Record<string, number>>({});

  const holdingsList = Object.entries(paperHoldings).map(([sym, h]) => ({ symbol: sym, ...h }));
  const totalCost = holdingsList.reduce((s, h) => s + (h.avg * h.qty), 0);
  const totalEquity = paperCash + totalCost; // Simplified for demo (assuming avg = market price)

  return (
    <>
      <TopBar />
      <main className="p-3 pb-20 max-w-4xl mx-auto space-y-4">
        <div className="flex justify-between items-center">
          <h2 className="text-lg font-bold">Paper Trading Account</h2>
          <button onClick={() => setShowSettings(!showSettings)} className="p-2 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10"><Settings size={16}/></button>
        </div>

        {showSettings && (
          <div className="card p-4 border border-[color:var(--accent)]">
            <h3 className="font-semibold mb-3 text-sm">Account Settings</h3>
            <div className="flex gap-4 items-end">
              <label className="text-xs flex flex-col gap-1">
                Initial Cash (৳)
                <input type="number" value={newCash} onChange={e=>setNewCash(Number(e.target.value))} className="bg-transparent border border-[color:var(--border)] rounded px-2 py-1" />
              </label>
              <label className="text-xs flex flex-col gap-1">
                Fee (%)
                <input type="number" step="0.01" value={newFee} onChange={e=>setNewFee(Number(e.target.value))} className="bg-transparent border border-[color:var(--border)] rounded px-2 py-1" />
              </label>
              <button onClick={() => { resetPaperAccount(newCash, newFee); setShowSettings(false); }} className="px-4 py-1.5 bg-[color:var(--accent)] text-white text-xs rounded">Reset Account</button>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="card p-5">
            <h3 className="text-xs text-[color:var(--muted)] uppercase mb-1">Available Cash</h3>
            <div className="text-2xl font-bold font-mono">{bdt(paperCash)}</div>
          </div>
          <div className="card p-5">
            <h3 className="text-xs text-[color:var(--muted)] uppercase mb-1">Total Equity (Approx)</h3>
            <div className="text-2xl font-bold font-mono">{bdt(totalEquity)}</div>
          </div>
        </div>

        <div className="card overflow-hidden">
          <div className="p-4 border-b border-[color:var(--border)]"><h3 className="font-semibold text-sm">Your Holdings</h3></div>
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-[color:var(--muted)] uppercase bg-[color:var(--muted)]/5">
              <tr><th className="px-4 py-3">Symbol</th><th className="px-4 py-3 text-right">Qty</th><th className="px-4 py-3 text-right">Avg Price</th><th className="px-4 py-3 text-center">Trade</th></tr>
            </thead>
            <tbody>
              {holdingsList.map(h => (
                <tr key={h.symbol} className="border-b border-[color:var(--border)] last:border-0">
                  <td className="px-4 py-3 font-medium">{h.symbol}</td>
                  <td className="px-4 py-3 text-right font-mono">{h.qty}</td>
                  <td className="px-4 py-3 text-right font-mono">{bdt(h.avg)}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center justify-center gap-2">
                       <input type="number" placeholder="Qty" onChange={e=>setTradeQty({...tradeQty, [h.symbol]: Number(e.target.value)})} className="w-16 bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-xs" />
                       <button onClick={() => executeTrade('BUY', h.avg, tradeQty[h.symbol] || 10)} className="p-1.5 bg-[color:var(--bull)] text-white rounded"><ArrowUpRight size={12}/></button>
                       <button onClick={() => executeTrade('SELL', h.avg, tradeQty[h.symbol] || 10)} className="p-1.5 bg-[color:var(--bear)] text-white rounded"><ArrowDownRight size={12}/></button>
                    </div>
                  </td>
                </tr>
              ))}
              {!holdingsList.length && <tr><td colSpan={4} className="p-8 text-center text-[color:var(--muted)]">No holdings. Go to chart to buy.</td></tr>}
            </tbody>
          </table>
        </div>
      </main>
      <BottomTabs />
    </>
  );
}
