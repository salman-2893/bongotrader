#!/usr/bin/env bash
set -e

echo "🔄 Updating TopBar with Demo Equity Display..."

write() { echo "📝 Updating $1"; }

write "components/TopBar.tsx"
cat > components/TopBar.tsx << 'EOF'
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
      <div className="flex items-center gap-3 px-3 py-2 overflow-x-auto no-scrollbar">
        <div className="font-bold text-lg text-[color:var(--accent)] tracking-tight hidden md:block">Chartbongo</div>
        
        <MarketCountdown />
        <ActiveInstrumentChip />
        
        {/* Company Info Button */}
        <button onClick={() => setShowInfo(true)} className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10 shrink-0" title="Company Info">
          <Info size={14}/>
        </button>
        
        <MoversTicker />
        
        <div className="ml-auto flex items-center gap-2 shrink-0">
          
          {/* Paper Equity Display */}
          <Link href="/account" className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[color:var(--bull)]/10 border border-[color:var(--bull)]/30 text-[color:var(--bull)] hover:bg-[color:var(--bull)]/20 transition-colors">
            <Wallet size={14} />
            <span className="font-mono text-xs font-bold">{bdt(paperCash)}</span>
          </Link>

          <label className="flex items-center gap-1 text-xs">
            Fee:
            <input type="number" step="0.01" min="0" max="5" value={feePct} onChange={(e) => setFee(parseFloat(e.target.value) || 0)} className="w-12 bg-transparent border border-[color:var(--border)] rounded px-1 py-0.5 text-center" />%
          </label>
          
          <LanguageToggle />
          <ThemeToggle />
          
          <Link href="/admin" className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 text-[color:var(--bear)] hidden md:block" title="Admin Panel">
            <Shield size={16} />
          </Link>
          
          <button onClick={() => setShowAlerts(!showAlerts)} className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 relative">
            <Bell size={16} />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-[color:var(--bear)]"></span>
          </button>
          
          <button className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10">
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
EOF

echo ""
echo "✅ Update applied successfully!"
echo "1. Refresh your browser (Ctrl+R or Cmd+R)."