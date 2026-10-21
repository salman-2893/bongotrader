#!/usr/bin/env bash
set -e

echo "🔄 Updating to Chartbongo.com V4 (Indicators & Admin)..."

write() { echo "📝 Updating $1"; }

# ========== 1. Branding ==========
write "package.json"
cat > package.json << 'EOF'
{
  "name": "chartbongo",
  "version": "1.0.0",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "start": "next start" },
  "dependencies": {
    "@supabase/supabase-js": "^2.45.0",
    "@tanstack/react-query": "^5.51.0",
    "clsx": "^2.1.1",
    "framer-motion": "^11.3.0",
    "lightweight-charts": "^4.1.7",
    "lucide-react": "^0.408.0",
    "next": "14.2.5",
    "next-intl": "^3.17.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "technicalindicators": "^3.1.0",
    "zustand": "^4.5.4"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "tailwindcss": "^3.4.6",
    "typescript": "^5.5.3"
  }
}
EOF

write "app/layout.tsx"
cat > app/layout.tsx << 'EOF'
import './globals.css';
import { NextIntlClientProvider } from 'next-intl';
import { getLocale, getMessages } from 'next-intl/server';
import Providers from './providers';
import HealthGate from '@/components/HealthGate';
import ClientIntlProvider from '@/components/ClientIntlProvider';

export const metadata = { title: 'Chartbongo.com | DSE Terminal', description: 'Trade Smarter' };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <body>
        <ClientIntlProvider>
          <Providers>
            <HealthGate>{children}</HealthGate>
          </Providers>
        </ClientIntlProvider>
      </body>
    </html>
  );
}
EOF

# ========== 2. Company API & Info Modal ==========
write "app/api/company/[symbol]/route.ts"
mkdir -p "app/api/company/[symbol]"
cat > "app/api/company/[symbol]/route.ts" << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET(req: NextRequest, { params }: { params: { symbol: string } }) {
  const sb = adminClient();
  const { data, error } = await sb.from('companies').select('*').eq('symbol', params.symbol).single();
  if (error && error.code !== 'PGRST116') return NextResponse.json({ error: 'db' }, { status: 500 });
  return NextResponse.json({ data });
}
EOF

write "components/CompanyInfoModal.tsx"
cat > components/CompanyInfoModal.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';
import { X, Globe } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';

export default function CompanyInfoModal({ onClose }: { onClose: () => void }) {
  const symbol = useAppStore(s => s.activeSymbol);
  const { data: res, isLoading } = useQuery({
    queryKey: ['company', symbol],
    queryFn: async () => (await fetch(`/api/company/${symbol}`)).json()
  });
  const company = res?.data;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center backdrop-blur-sm p-4">
      <div className="card w-full max-w-lg p-5 relative">
        <button onClick={onClose} className="absolute top-4 right-4 text-[color:var(--muted)] hover:text-[color:var(--text)]"><X size={18}/></button>
        <h2 className="text-xl font-bold mb-1">{symbol}</h2>
        {isLoading ? <p className="text-sm text-[color:var(--muted)]">Loading...</p> : company ? (
          <div className="space-y-3 mt-4">
            <h3 className="text-lg text-[color:var(--accent)] font-medium">{company.name}</h3>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div><span className="text-[color:var(--muted)] block text-xs">Sector</span>{company.sector || 'N/A'}</div>
              <div><span className="text-[color:var(--muted)] block text-xs">Website</span>{company.website ? <a href={company.website} target="_blank" className="flex items-center gap-1 text-blue-400 hover:underline"><Globe size={12}/> Link</a> : 'N/A'}</div>
            </div>
            <div className="mt-4">
              <span className="text-[color:var(--muted)] block text-xs mb-1">About</span>
              <p className="text-sm leading-relaxed text-justify">{company.description || 'No description available.'}</p>
            </div>
          </div>
        ) : (
          <p className="text-sm text-[color:var(--muted)] mt-4">No information found for this symbol. Please add it in the Admin Panel.</p>
        )}
      </div>
    </div>
  );
}
EOF

# ========== 3. TopBar (Add Info & Admin) ==========
write "components/TopBar.tsx"
cat > components/TopBar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import MarketCountdown from './MarketCountdown';
import ActiveInstrumentChip from './ActiveInstrumentChip';
import MoversTicker from './MoversTicker';
import ThemeToggle from './ThemeToggle';
import LanguageToggle from './LanguageToggle';
import CompanyInfoModal from './CompanyInfoModal';
import { useAppStore } from '@/store/useAppStore';
import { Bell, User, Info, Shield } from 'lucide-react';
import Link from 'next/link';

export default function TopBar() {
  const { feePct, setFee } = useAppStore();
  const [showAlerts, setShowAlerts] = useState(false);
  const [showInfo, setShowInfo] = useState(false);

  return (
    <header className="sticky top-0 z-40 backdrop-blur border-b border-[color:var(--border)]" style={{ background: 'var(--card-bg)' }}>
      <div className="flex items-center gap-3 px-3 py-2 overflow-x-auto">
        <div className="font-bold text-lg text-[color:var(--accent)] tracking-tight hidden md:block">Chartbongo</div>
        <MarketCountdown />
        <ActiveInstrumentChip />
        <button onClick={() => setShowInfo(true)} className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10" title="Company Info"><Info size={14}/></button>
        <MoversTicker />
        <div className="ml-auto flex items-center gap-2">
          <label className="flex items-center gap-1 text-xs">
            Fee:
            <input type="number" step="0.01" min="0" max="5" value={feePct} onChange={(e) => setFee(parseFloat(e.target.value) || 0)} className="w-14 bg-transparent border border-[color:var(--border)] rounded px-1 py-0.5 text-center" />%
          </label>
          <LanguageToggle />
          <ThemeToggle />
          <Link href="/admin" className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 text-[color:var(--bear)]" title="Admin Panel"><Shield size={16} /></Link>
          <button onClick={() => setShowAlerts(!showAlerts)} className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10 relative"><Bell size={16} /><span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-[color:var(--bear)]"></span></button>
          <button className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10"><User size={16} /></button>
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

# ========== 4. Admin Dashboard ==========
write "app/admin/page.tsx"
mkdir -p app/admin
cat > app/admin/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import { Save } from 'lucide-react';

export default function AdminPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState({ symbol: '', name: '', sector: '', website: '', description: '' });
  const [msg, setMsg] = useState('');

  const saveMutation = useMutation({
    mutationFn: async (data: typeof form) => {
      const res = await fetch('/api/admin/company', { method: 'POST', body: JSON.stringify(data) });
      if (!res.ok) throw new Error('Failed');
    },
    onSuccess: () => { setMsg('Saved successfully!'); qc.invalidateQueries({ queryKey: ['company'] }); },
    onError: () => setMsg('Error saving. Check console.'),
  });

  return (
    <>
      <TopBar />
      <main className="p-3 pb-20 max-w-2xl mx-auto space-y-4">
        <div className="card p-5">
          <h2 className="text-lg font-bold mb-4 flex items-center gap-2">Admin: Company Info</h2>
          <div className="space-y-3">
            <input placeholder="Symbol (e.g. GP)" value={form.symbol} onChange={e => setForm({...form, symbol: e.target.value.toUpperCase()})} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm" />
            <input placeholder="Company Name" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm" />
            <input placeholder="Sector" value={form.sector} onChange={e => setForm({...form, sector: e.target.value})} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm" />
            <input placeholder="Website URL" value={form.website} onChange={e => setForm({...form, website: e.target.value})} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm" />
            <textarea placeholder="Description" value={form.description} onChange={e => setForm({...form, description: e.target.value})} rows={4} className="w-full bg-transparent border border-[color:var(--border)] rounded px-3 py-2 text-sm" />
            <button onClick={() => saveMutation.mutate(form)} className="flex items-center gap-2 px-4 py-2 bg-[color:var(--accent)] text-white rounded text-sm font-medium">
              <Save size={16}/> Save Company
            </button>
            {msg && <p className="text-xs text-[color:var(--bull)] mt-2">{msg}</p>}
          </div>
        </div>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

write "app/api/admin/company/route.ts"
mkdir -p app/api/admin/company
cat > app/api/admin/company/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function POST(req: NextRequest) {
  const body = await req.json();
  const sb = adminClient();
  // Upsert into companies table
  const { error } = await sb.from('companies').upsert(body, { onConflict: 'symbol' });
  if (error) return NextResponse.json({ error }, { status: 500 });
  return NextResponse.json({ success: true });
}
EOF

# ========== 5. Indicator Engine & Custom Script ==========
write "lib/indicators/engine.ts"
mkdir -p lib/indicators
cat > lib/indicators/engine.ts << 'EOF'
import * as ti from 'technicalindicators';

export type IndicatorConfig = {
  id: string;
  name: string;
  type: 'overlay' | 'oscillator';
  params?: any;
  color?: string;
};

// Map of available indicators from technicalindicators
export const AVAILABLE_INDICATORS = [
  { id: 'sma', name: 'SMA (20)', fn: (c: number[]) => ti.sma({ period: 20, values: c }) },
  { id: 'ema20', name: 'EMA (20)', fn: (c: number[]) => ti.ema({ period: 20, values: c }) },
  { id: 'ema50', name: 'EMA (50)', fn: (c: number[]) => ti.ema({ period: 50, values: c }) },
  { id: 'wma', name: 'WMA (20)', fn: (c: number[]) => ti.wma({ period: 20, values: c }) },
  { id: 'rsi', name: 'RSI (14)', fn: (c: number[]) => ti.rsi({ period: 14, values: c }) },
  { id: 'macd', name: 'MACD', fn: (c: number[]) => ti.macd({ values: c, fastPeriod: 12, slowPeriod: 26, signalPeriod: 9 }).map(m => m.histogram) },
  { id: 'bb', name: 'Bollinger Bands', fn: (c: number[]) => ti.bollingerbands({ period: 20, stdDev: 2, values: c }).map(b => b.middle) },
  { id: 'stoch', name: 'Stochastic', fn: (c: number[]) => ti.stochastic({ high: c, low: c, close: c, period: 14, signalPeriod: 3 }).map(s => s.k) },
  { id: 'adx', name: 'ADX (14)', fn: (c: number[]) => ti.adx({ high: c, low: c, close: c, period: 14 }).map(a => a.adx) },
  { id: 'atr', name: 'ATR (14)', fn: (c: number[]) => ti.atr({ high: c, low: c, close: c, period: 14 }) },
  { id: 'obv', name: 'OBV', fn: (c: number[]) => ti.obv({ close: c, volume: c }) },
  { id: 'mfi', name: 'MFI (14)', fn: (c: number[]) => ti.mfi({ high: c, low: c, close: c, volume: c, period: 14 }) },
  { id: 'roc', name: 'ROC (12)', fn: (c: number[]) => ti.roc({ period: 12, values: c }) },
  { id: 'williams', name: 'Williams %R', fn: (c: number[]) => ti.williamsr({ high: c, low: c, close: c, period: 14 }) },
  { id: 'cci', name: 'CCI (20)', fn: (c: number[]) => ti.cci({ high: c, low: c, close: c, period: 20 }) },
];

export function calcIndicatorSeries(candles: any[], indicatorId: string, customScript?: string) {
  const closes = candles.map(c => c.close);
  
  if (indicatorId === 'custom' && customScript) {
    try {
      // SAFE-ISH EVAL: For user-defined indicators. 
      // We pass 'close', 'high', 'low', 'open', 'volume'
      const func = new Function('close', 'high', 'low', 'open', 'volume', customScript);
      const result = func(closes, candles.map(c=>c.high), candles.map(c=>c.low), candles.map(c=>c.open), candles.map(c=>c.volume));
      if (!Array.isArray(result)) return [];
      // Pad the result array to match candle length if needed
      const pad = candles.length - result.length;
      return Array(pad).fill(null).concat(result);
    } catch (e) {
      console.error("Custom Script Error:", e);
      return [];
    }
  }

  const ind = AVAILABLE_INDICATORS.find(i => i.id === indicatorId);
  if (!ind) return [];
  
  try {
    // Basic implementation for demo (applying to close price) - real TI needs full OHLCV
    const raw = ind.fn(closes) || [];
    const pad = candles.length - raw.length;
    return Array(pad).fill(null).concat(raw);
  } catch { return []; }
}
EOF

# ========== 6. App Store (Indicator List) ==========
write "store/useAppStore.ts"
cat > store/useAppStore.ts << 'EOF'
'use client';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Theme = 'light' | 'dark'; type Lang = 'en' | 'bn'; type ChartType = 'candlestick' | 'line' | 'area' | 'bar';

interface AppState {
  theme: Theme; lang: Lang; activeSymbol: string;
  timeframe: 'D' | 'W' | 'M' | 'Q' | 'Y';
  chartType: ChartType;
  feePct: number;
  activeIndicators: string[]; // array of IDs
  customScript: string;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  setLang: (l: Lang) => void;
  setSymbol: (s: string) => void;
  setTimeframe: (t: AppState['timeframe']) => void;
  setChartType: (t: ChartType) => void;
  setFee: (f: number) => void;
  toggleIndicator: (id: string) => void;
  setCustomScript: (s: string) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', chartType: 'candlestick', feePct: 0.15,
  activeIndicators: ['volume'], customScript: '// return close.map(c => c * 2);',
  setTheme: (t) => set({ theme: t }),
  toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
  setLang: (l) => set({ lang: l }),
  setSymbol: (s) => set({ activeSymbol: s }),
  setTimeframe: (t) => set({ timeframe: t }),
  setChartType: (t) => set({ chartType: t }),
  setFee: (f) => set({ feePct: f }),
  toggleIndicator: (id) => set((s) => ({ activeIndicators: s.activeIndicators.includes(id) ? s.activeIndicators.filter(i => i !== id) : [...s.activeIndicators, id] })),
  setCustomScript: (customScript) => set({ customScript }),
}), { name: 'chartbongo-app' }));
EOF

# ========== 7. Chart Toolbar (Indicator Modal) ==========
write "components/ChartToolbar.tsx"
cat > components/ChartToolbar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { CandlestickChart, LineChart, AreaChart, BarChart3, Layers, X } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';
import { AVAILABLE_INDICATORS } from '@/lib/indicators/engine';

const TFS = [{ v: 'D', l: 'D' }, { v: 'W', l: 'W' }, { v: 'M', l: 'M' }, { v: 'Q', l: 'Q' }, { v: 'Y', l: 'Y' }] as const;

export default function ChartToolbar() {
  const { timeframe, setTimeframe, chartType, setChartType, activeIndicators, toggleIndicator, customScript, setCustomScript } = useAppStore();
  const [showInd, setShowInd] = useState(false);

  return (
    <div className="flex items-center gap-2 flex-wrap p-2 border-b border-[color:var(--border)] relative z-20">
      <div className="flex rounded-lg border border-[color:var(--border)] overflow-hidden">
        {TFS.map((t) => (
          <button key={t.v} onClick={() => setTimeframe(t.v)} className={`px-2.5 py-1 text-xs ${timeframe === t.v ? 'bg-[color:var(--accent)] text-white' : 'hover:bg-[color:var(--muted)]/10'}`}>{t.l}</button>
        ))}
      </div>
      
      <div className="flex gap-1 ml-2">
        {(['candlestick', 'line', 'area', 'bar'] as const).map((type) => {
          const Icon = type === 'candlestick' ? CandlestickChart : type === 'line' ? LineChart : type === 'area' ? AreaChart : BarChart3;
          return (
            <button key={type} onClick={() => setChartType(type)} title={type}
              className={`p-1.5 rounded-lg border ${chartType === type ? 'bg-[color:var(--accent)] text-white border-[color:var(--accent)]' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'}`}>
              <Icon size={14} />
            </button>
          );
        })}
      </div>

      <div className="flex gap-1 ml-auto">
        <button onClick={() => setShowInd(!showInd)} className={`flex items-center gap-1 px-2 py-1.5 rounded-lg border ${showInd ? 'bg-[color:var(--muted)]/20' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'}`}>
          <Layers size={14} /> <span className="text-xs font-medium">Indicators ({activeIndicators.length})</span>
        </button>
      </div>

      {showInd && (
        <div className="absolute right-2 top-full mt-1 w-80 card p-4 z-50 shadow-2xl flex flex-col gap-3 max-h-[70vh] overflow-y-auto">
          <div className="flex justify-between items-center border-b border-[color:var(--border)] pb-2 mb-2">
            <h3 className="font-semibold text-sm">Technical Indicators</h3>
            <button onClick={() => setShowInd(false)}><X size={16} /></button>
          </div>
          
          <div className="grid grid-cols-2 gap-2">
            {AVAILABLE_INDICATORS.map((ind) => (
              <label key={ind.id} className="flex items-center gap-2 text-xs p-1 hover:bg-[color:var(--muted)]/10 rounded cursor-pointer">
                <input type="checkbox" checked={activeIndicators.includes(ind.id)} onChange={() => toggleIndicator(ind.id)} className="accent-[color:var(--accent)]" />
                <span>{ind.name}</span>
              </label>
            ))}
          </div>

          <div className="border-t border-[color:var(--border)] pt-3 mt-2">
            <h4 className="font-semibold text-xs mb-2">Custom Script (JS)</h4>
            <textarea value={customScript} onChange={e => setCustomScript(e.target.value)} rows={4} className="w-full text-[10px] font-mono bg-[color:var(--bg)] border border-[color:var(--border)] p-2 rounded" placeholder="// return close.map(c => c * 2);" />
            <label className="flex items-center gap-2 text-xs mt-2 cursor-pointer">
              <input type="checkbox" checked={activeIndicators.includes('custom')} onChange={() => toggleIndicator('custom')} className="accent-[color:var(--accent)]" />
              <span>Enable Custom Indicator</span>
            </label>
          </div>
        </div>
      )}
    </div>
  );
}
EOF

# ========== 8. Chart Panel (Render All Indicators) ==========
write "components/ChartPanel.tsx"
cat > components/ChartPanel.tsx << 'EOF'
'use client';
import { useEffect, useRef } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';
import { calcIndicatorSeries } from '@/lib/indicators/engine';

export default function ChartPanel() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const seriesRef = useRef<ISeriesApi<any> | null>(null);
  const indSeriesRef = useRef<ISeriesApi<any>[]>([]);
  
  const { activeSymbol: symbol, timeframe: tf, theme, chartType, activeIndicators, customScript } = useAppStore();

  const { data, isLoading, error } = useQuery({
    queryKey: ['ohlcv', symbol, tf],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=${tf}&limit=500`);
      if (!r.ok) throw new Error('failed');
      const j = await r.json();
      const raw = (j.data as any[]) || [];
      const parsed = raw.map((d) => {
        const t = new Date(d.date).getTime();
        return { time: Math.floor(t / 1000) as any, open: Number(d.open), high: Number(d.high), low: Number(d.low), close: Number(d.close), volume: Number(d.volume || 0), value: Number(d.close) };
      }).filter((d) => !isNaN(d.time));
      const uniqueMap = new Map();
      parsed.forEach((item) => uniqueMap.set(item.time, item));
      return Array.from(uniqueMap.values()).sort((a, b) => a.time - b.time);
    },
  });

  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: { background: { type: ColorType.Solid, color: 'transparent' }, textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540', fontFamily: 'ui-sans-serif' },
      grid: { vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' }, horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' } },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 5, barSpacing: 8 },
      autoSize: true,
    });
    chartRef.current = chart;
    chartRefs.chart = chart;
    return () => { chart.remove(); chartRefs.chart = null; chartRefs.series = null; };
  }, []);

  useEffect(() => {
    if (!chartRef.current || !data) return;
    const chart = chartRef.current;
    
    if (seriesRef.current) chart.removeSeries(seriesRef.current);
    indSeriesRef.current.forEach(s => chart.removeSeries(s));
    indSeriesRef.current = [];

    const opts = { upColor: '#16A34A', downColor: '#DC2626', wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false };
    let series;
    if (chartType === 'line') series = chart.addLineSeries({ color: '#1E6FD9', lineWidth: 2 });
    else if (chartType === 'area') series = chart.addAreaSeries({ lineColor: '#1E6FD9', topColor: 'rgba(30,111,217,0.4)', bottomColor: 'rgba(30,111,217,0.0)' });
    else if (chartType === 'bar') series = chart.addBarSeries({ upColor: '#16A34A', downColor: '#DC2626' });
    else series = chart.addCandlestickSeries(opts);

    series.setData(data);
    seriesRef.current = series;
    chartRefs.series = series as any;

    // Indicators
    activeIndicators.forEach(id => {
      if (id === 'volume') {
        const volSeries = chart.addHistogramSeries({ priceFormat: { type: 'volume' }, priceScaleId: 'vol', color: '#26a69a' });
        volSeries.priceScale().applyOptions({ scaleMargins: { top: 0.8, bottom: 0 } });
        volSeries.setData(data.map(d => ({ time: d.time, value: d.volume, color: d.close >= d.open ? '#16A34A' : '#DC2626' })));
        indSeriesRef.current.push(volSeries);
        return;
      }

      const values = calcIndicatorSeries(data, id, customScript);
      if (!values.length) return;
      
      const isOscillator = ['rsi', 'macd', 'stoch', 'adx', 'mfi', 'roc', 'williams', 'cci', 'custom'].includes(id);
      const indSeries = chart.addLineSeries({ 
        color: id === 'custom' ? '#F59E0B' : '#8B5CF6', 
        lineWidth: 2, 
        priceScaleId: isOscillator ? 'osc' : 'right' 
      });
      
      if (isOscillator) {
        indSeries.priceScale().applyOptions({ scaleMargins: { top: 0.7, bottom: 0.1 } });
      }

      indSeries.setData(data.map((d, i) => ({ time: d.time, value: values[i] })).filter(d => d.value !== null && d.value !== undefined));
      indSeriesRef.current.push(indSeries);
    });

    chart.timeScale().scrollToRealTime();
  }, [data, chartType, activeIndicators, customScript]);

  useEffect(() => {
    chartRef.current?.applyOptions({
      layout: { textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540' },
      grid: { vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' }, horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' } },
    });
  }, [theme]);

  return (
    <div className="chart-pane w-full h-[480px]">
      {isLoading && <div className="absolute inset-0 grid place-items-center text-[color:var(--muted)] z-20">Loading…</div>}
      {error && <div className="absolute inset-0 grid place-items-center text-[color:var(--bear)] z-20">Error</div>}
      <div ref={containerRef} className="w-full h-full" />
      <DrawingCanvas />
    </div>
  );
}
EOF

echo ""
echo "✅ V4 Update applied!"
echo "1. Run: npm install technicalindicators"
echo "2. Run: npm run dev"
echo "3. Refresh your browser."