'use client';
import { useState } from 'react';
import Link from 'next/link';
import MarketCountdown from './MarketCountdown';
import ActiveInstrumentChip from './ActiveInstrumentChip';
import MoversTicker from './MoversTicker';
import ThemeToggle from './ThemeToggle';
import LanguageToggle from './LanguageToggle';
import CompanyInfoModal from './CompanyInfoModal';
import { useAppStore } from '@/store/useAppStore';
import { bdt } from '@/lib/format';
import { Bell, User, Info, Shield, Wallet } from 'lucide-react';

export default function TopBar() {
  const { feePct, setFee, paperCash } = useAppStore();
  const [showAlerts, setShowAlerts] = useState(false);
  const [showInfo, setShowInfo] = useState(false);

  return (
    <header className="sticky top-0 z-40 backdrop-blur border-b border-[color:var(--border)]" style={{ background: 'var(--card-bg)' }}>
  <div className="flex flex-wrap items-center gap-1.5 md:gap-2 px-2 py-1.5 w-full">
    <div className="font-bold text-base md:text-lg text-[color:var(--accent)] tracking-tight shrink-0 hidden lg:block">Chartbongo</div>

    <div className="shrink-0"><MarketCountdown /></div>
    <div className="shrink-0"><ActiveInstrumentChip /></div>

    <button onClick={() => setShowInfo(true)} className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10 shrink-0" title="Company Info">
      <Info size={14}/>
    </button>

    <div className="order-3 w-full md:order-none md:flex-1 md:min-w-[80px] md:overflow-hidden">
      <MoversTicker />
    </div>

    <div className="ml-auto flex items-center gap-1.5 shrink-0">
      <Link href="/account" className="flex items-center gap-1.5 px-2 py-1.5 rounded-lg bg-[color:var(--bull)]/10 border border-[color:var(--bull)]/30 text-[color:var(--bull)] hover:bg-[color:var(--bull)]/15">
        <Wallet size={14} />
        <span className="font-mono text-xs font-bold hidden sm:block">{bdt(paperCash)}</span>
      </Link>

      <label className="hidden md:flex items-center gap-1 text-xs shrink-0">
        Fee:
        <input type="number" step="0.01" min="0" max="5" value={feePct} onChange={(e) => setFee(parseFloat(e.target.value) || 0)} className="w-12 bg-transparent border border-[color:var(--border)] rounded px-1 text-[color:var(--text)]" />
      </label>

      <div className="hidden sm:block shrink-0"><LanguageToggle /></div>
      <div className="shrink-0"><ThemeToggle /></div>

      <Link href="/admin" className="p-1.5 md:p-2 rounded-lg hover:bg-[color:var(--muted)]/10 text-[color:var(--bear)] hidden md:block shrink-0" title="Admin Panel">
        <Shield size={16} />
      </Link>

      <button onClick={() => setShowAlerts(!showAlerts)} className="p-1.5 md:p-2 rounded-lg hover:bg-[color:var(--muted)]/10 relative shrink-0">
        <Bell size={16} />
        <span className="absolute top-1 right-1 w-2 h-2 rounded-full bg-[color:var(--bear)]"></span>
      </button>

      <button className="p-1.5 md:p-2 rounded-lg hover:bg-[color:var(--muted)]/10 shrink-0">
        <User size={16} />
      </button>
    </div>
  </div> 

      {showAlerts && (
        <div className="absolute right-2 top-14 w-80 card p-0 overflow-hidden shadow-2xl z-50">
          <div className="p-3 border-b border-[color:var(--border)] bg-[color:var(--bg)]/50 font-semibold text-sm">Notifications</div>
          <div className="p-4 text-center text-xs text-[color:var(--muted)]">No new notifications</div>
        </div>
      )}
      
      {showInfo && <CompanyInfoModal onClose={() => setShowInfo(false)} />}
    </header>
  );
}
