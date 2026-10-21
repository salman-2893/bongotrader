'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Wallet, LineChart, FlaskConical, Filter } from 'lucide-react';

const tabs = [
  { href: '/chart', Icon: LineChart, label: 'Chart' },
  { href: '/screener', Icon: Filter, label: 'Screener' },
  { href: '/account', Icon: Wallet, label: 'Account' },
  { href: '/backtest', Icon: FlaskConical, label: 'Backtest' },
] as const;

export default function BottomTabs() {
  const path = usePathname();
  return (
    <nav className="fixed bottom-0 inset-x-0 z-50 border-t border-[color:var(--border)] backdrop-blur-md" style={{ background: 'var(--card-bg)' }}>
      <ul className="grid grid-cols-4">
        {tabs.map(({ href, Icon, label }) => {
          const active = path.startsWith(href);
          return (
            <li key={href}>
              <Link href={href} className={`flex flex-col items-center py-2 text-[10px] md:text-xs gap-1 ${active ? 'text-[color:var(--accent)] font-bold' : 'text-[color:var(--muted)]'}`}>
                <Icon size={20} />
                {label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
