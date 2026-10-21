#!/usr/bin/env bash
set -e

echo "🚀 Bongotrader setup starting..."
echo ""

# ---------- Folders ----------
mkdir -p lib/strategy lib/drawing store messages \
  app/api/health app/api/symbols app/api/movers app/api/ohlcv \
  app/chart app/account app/backtest components sql

write() { echo "📝 Writing $1"; }
N=0
total=52

# ========== ROOT CONFIG ==========
N=$((N+1)); write "$N/$total package.json"
cat > package.json << 'EOF'
{
  "name": "bongotrader",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
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

N=$((N+1)); write "$N/$total .env.local"
cat > .env.local << 'EOF'
# ====== EDIT THESE TWO KEYS BEFORE RUNNING ======
# Get them from: supabase.com/dashboard → your project → Settings → API
# First rotate the leaked service_role key: Settings → API → Roll service_role
SUPABASE_URL=https://aukkepferyltekvoctpu.supabase.co
SUPABASE_SERVICE_ROLE_KEY=PASTE_YOUR_NEW_SERVICE_ROLE_KEY_HERE
NEXT_PUBLIC_SUPABASE_URL=https://aukkepferyltekvoctpu.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=PASTE_YOUR_ANON_KEY_HERE
EOF

N=$((N+1)); write "$N/$total .gitignore"
cat > .gitignore << 'EOF'
node_modules
.next
.env
.env.local
.DS_Store
EOF

N=$((N+1)); write "$N/$total next.config.js"
cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const withIntl = require('next-intl/plugin')('./lib/i18n.ts');
module.exports = withIntl({ reactStrictMode: true });
EOF

N=$((N+1)); write "$N/$total tsconfig.json"
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020", "lib": ["dom","dom.iterable","esnext"],
    "allowJs": true, "skipLibCheck": true, "strict": true,
    "noEmit": true, "esModuleInterop": true, "module": "esnext",
    "moduleResolution": "bundler", "resolveJsonModule": true,
    "isolatedModules": true, "jsx": "preserve", "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts","**/*.ts","**/*.tsx",".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

N=$((N+1)); write "$N/$total postcss.config.js"
cat > postcss.config.js << 'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

N=$((N+1)); write "$N/$total tailwind.config.ts"
cat > tailwind.config.ts << 'EOF'
import type { Config } from 'tailwindcss';
const config: Config = {
  content: ['./app/**/*.{ts,tsx}','./components/**/*.{ts,tsx}'],
  darkMode: ['class','[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        bg: 'var(--bg)', panel: 'var(--panel)', border: 'var(--border)',
        text: 'var(--text)', muted: 'var(--muted)', accent: 'var(--accent)',
        bull: 'var(--bull)', bear: 'var(--bear)',
      },
    },
  },
  plugins: [],
};
export default config;
EOF

N=$((N+1)); write "$N/$total README.md"
cat > README.md << 'EOF'
# Bongotrader

DSE trading & backtesting terminal.

## Setup

1. Fill `.env.local` with your Supabase keys (rotate the service_role key first!).
2. Run `sql/schema.sql` in Supabase SQL editor.
3. `npm install && npm run dev`
4. Open http://localhost:3000

## Routes

- `/chart` — candlestick chart + drawing tools
- `/backtest` — strategy builder + replay engine
- `/account` — portfolio (stub)
EOF

# ========== LIB ==========
N=$((N+1)); write "$N/$total lib/supabase-admin.ts"
cat > lib/supabase-admin.ts << 'EOF'
import { createClient } from '@supabase/supabase-js';

export const adminClient = () =>
  createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  );
EOF

N=$((N+1)); write "$N/$total lib/supabase-browser.ts"
cat > lib/supabase-browser.ts << 'EOF'
'use client';
import { createClient } from '@supabase/supabase-js';
export const browserClient = () =>
  createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
EOF

N=$((N+1)); write "$N/$total lib/i18n.ts"
cat > lib/i18n.ts << 'EOF'
import { getRequestConfig } from 'next-intl/server';

export default getRequestConfig(async ({ locale }) => ({
  messages: (await import(`../messages/${locale}.json`)).default,
}));
EOF

N=$((N+1)); write "$N/$total lib/dse.ts"
cat > lib/dse.ts << 'EOF'
const OPEN_MIN = 10 * 60;
const CLOSE_MIN = 14 * 60 + 30;

export function nextDseEvent(now = new Date()) {
  const bstMs = now.getTime() + 6 * 60 * 60 * 1000;
  const d = new Date(bstMs);
  const dow = d.getUTCDay();
  const mins = d.getUTCHours() * 60 + d.getUTCMinutes() + d.getUTCSeconds() / 60;
  const tradingDay = dow >= 0 && dow <= 4;

  if (tradingDay && mins < OPEN_MIN) {
    return { label: 'OPEN' as const, targetMs: bstMs + (OPEN_MIN - mins) * 60000 };
  }
  if (tradingDay && mins >= OPEN_MIN && mins < CLOSE_MIN) {
    return { label: 'CLOSE' as const, targetMs: bstMs + (CLOSE_MIN - mins) * 60000 };
  }
  let add = 1;
  while (true) {
    const n = new Date(bstMs + add * 86400000);
    const nd = n.getUTCDay();
    if (nd >= 0 && nd <= 4) {
      return { label: 'OPEN' as const, targetMs: n.getTime() + OPEN_MIN * 60000 };
    }
    add++;
  }
}

export function fmtCountdown(ms: number) {
  if (ms <= 0) return '00d 00h 00m 00s';
  const s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  return `${String(d).padStart(2,'0')}d ${String(h).padStart(2,'0')}h ${String(m).padStart(2,'0')}m ${String(ss).padStart(2,'0')}s`;
}
EOF

N=$((N+1)); write "$N/$total lib/format.ts"
cat > lib/format.ts << 'EOF'
export const bdt = (n: number) => {
  const s = new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: 2, maximumFractionDigits: 2,
  }).format(n);
  return `৳${s}`;
};
export const pct = (n: number) => `${n >= 0 ? '+' : ''}${n.toFixed(2)}%`;
export const num = (n: number) => new Intl.NumberFormat('en-IN').format(n);
export const dt = (t: number) => new Date(t * 1000).toISOString().slice(0, 10);
EOF

N=$((N+1)); write "$N/$total lib/chartInstance.ts"
cat > lib/chartInstance.ts << 'EOF'
'use client';
import type { IChartApi, ISeriesApi } from 'lightweight-charts';

export const chartRefs: {
  chart: IChartApi | null;
  series: ISeriesApi<'Candlestick'> | null;
} = { chart: null, series: null };
EOF

N=$((N+1)); write "$N/$total lib/drawing/types.ts"
cat > lib/drawing/types.ts << 'EOF'
export type ToolId = 'select' | 'trendline' | 'hline' | 'text' | 'buy' | 'sell' | 'greenbox' | 'redbox';

export interface BaseDrawing {
  id: string;
  tool: ToolId;
  a: { time: number; price: number };
  b?: { time: number; price: number };
  text?: string;
}

export type Drawing = BaseDrawing;
EOF

N=$((N+1)); write "$N/$total lib/strategy/types.ts"
cat > lib/strategy/types.ts << 'EOF'
export type Operand =
  | { kind: 'price'; field: 'open' | 'high' | 'low' | 'close' }
  | { kind: 'indicator'; name: 'SMA' | 'EMA' | 'WMA' | 'RSI' | 'BB_upper' | 'BB_mid' | 'BB_lower'; period: number; stdDev?: number }
  | { kind: 'volume' }
  | { kind: 'constant'; value: number };

export type Comparator = 'crossesAbove' | 'crossesBelow' | '>' | '<' | '>=' | '<=';

export interface Condition {
  id: string;
  left: Operand;
  op: Comparator;
  right: Operand;
}

export interface ConditionGroup {
  op: 'AND' | 'OR';
  conditions: Condition[];
}

export interface Strategy {
  id: string;
  name: string;
  buy: ConditionGroup;
  sell: ConditionGroup;
  capital: number;
  sizing: { type: 'pct' | 'fixedBDT' | 'shares'; value: number };
  feePct: number;
  stopLoss?: number;
  takeProfit?: number;
}

export interface Trade {
  id: string;
  strategy: string;
  symbol: string;
  side: 'BUY' | 'SELL';
  trigger: string;
  qty: number;
  price: number;
  fee: number;
  pnl?: number;
  pnlPct?: number;
  time: number;
  exitTime?: number;
  exitPrice?: number;
}
EOF

N=$((N+1)); write "$N/$total lib/strategy/indicators.ts"
cat > lib/strategy/indicators.ts << 'EOF'
export function sma(v: number[], p: number): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  let sum = 0;
  for (let i = 0; i < v.length; i++) {
    sum += v[i];
    if (i >= p) sum -= v[i - p];
    if (i >= p - 1) out[i] = sum / p;
  }
  return out;
}

export function ema(v: number[], p: number): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  const k = 2 / (p + 1);
  let prev: number | null = null;
  for (let i = 0; i < v.length; i++) {
    if (i === p - 1) {
      let s = 0; for (let j = 0; j < p; j++) s += v[j];
      prev = s / p; out[i] = prev;
    } else if (prev !== null) {
      prev = v[i] * k + prev * (1 - k); out[i] = prev;
    }
  }
  return out;
}

export function wma(v: number[], p: number): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  const denom = (p * (p + 1)) / 2;
  for (let i = p - 1; i < v.length; i++) {
    let s = 0;
    for (let j = 0; j < p; j++) s += v[i - p + 1 + j] * (j + 1);
    out[i] = s / denom;
  }
  return out;
}

export function rsi(v: number[], p = 14): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  if (v.length <= p) return out;
  let gain = 0, loss = 0;
  for (let i = 1; i <= p; i++) {
    const d = v[i] - v[i - 1];
    if (d >= 0) gain += d; else loss -= d;
  }
  let ag = gain / p, al = loss / p;
  out[p] = 100 - 100 / (1 + ag / (al || 1e-9));
  for (let i = p + 1; i < v.length; i++) {
    const d = v[i] - v[i - 1];
    const g = d > 0 ? d : 0, l = d < 0 ? -d : 0;
    ag = (ag * (p - 1) + g) / p; al = (al * (p - 1) + l) / p;
    out[i] = 100 - 100 / (1 + ag / (al || 1e-9));
  }
  return out;
}

export function bollinger(v: number[], p = 20, k = 2) {
  const mid = sma(v, p);
  const upper: (number | null)[] = new Array(v.length).fill(null);
  const lower: (number | null)[] = new Array(v.length).fill(null);
  for (let i = p - 1; i < v.length; i++) {
    let s = 0;
    for (let j = i - p + 1; j <= i; j++) s += (v[j] - (mid[i] ?? 0)) ** 2;
    const sd = Math.sqrt(s / p);
    upper[i] = (mid[i] ?? 0) + k * sd;
    lower[i] = (mid[i] ?? 0) - k * sd;
  }
  return { upper, mid, lower };
}
EOF

N=$((N+1)); write "$N/$total lib/strategy/evaluator.ts"
cat > lib/strategy/evaluator.ts << 'EOF'
import { Condition, ConditionGroup, Operand, Strategy, Trade } from './types';
import { bollinger, ema, rsi, sma, wma } from './indicators';

export interface Bar { time: number; open: number; high: number; low: number; close: number; volume: number; }

function seriesFor(op: Operand, bars: Bar[]): (number | null)[] {
  const closes = bars.map((b) => b.close);
  if (op.kind === 'price') return bars.map((b) => b[op.field]);
  if (op.kind === 'volume') return bars.map((b) => b.volume);
  if (op.kind === 'constant') return bars.map(() => op.value);
  switch (op.name) {
    case 'SMA': return sma(closes, op.period);
    case 'EMA': return ema(closes, op.period);
    case 'WMA': return wma(closes, op.period);
    case 'RSI': return rsi(closes, op.period);
    case 'BB_upper': return bollinger(closes, op.period, op.stdDev ?? 2).upper;
    case 'BB_mid': return bollinger(closes, op.period, op.stdDev ?? 2).mid;
    case 'BB_lower': return bollinger(closes, op.period, op.stdDev ?? 2).lower;
    default: return new Array(bars.length).fill(null);
  }
}

function operandLabel(op: Operand): string {
  if (op.kind === 'price') return `Price(${op.field})`;
  if (op.kind === 'volume') return 'Volume';
  if (op.kind === 'constant') return `${op.value}`;
  return `${op.name}(${op.period})`;
}

export function conditionLabel(c: Condition): string {
  const opSym = { crossesAbove: 'crossed above', crossesBelow: 'crossed below', '>': '>', '<': '<', '>=': '≥', '<=': '≤' }[c.op];
  return `${operandLabel(c.left)} ${opSym} ${operandLabel(c.right)}`;
}

export function evaluateStrategy(strategy: Strategy, symbol: string, bars: Bar[]): { trades: Trade[]; equity: number[] } {
  const cache = new Map<string, (number | null)[]>();
  const getSeries = (op: Operand) => {
    const key = JSON.stringify(op);
    if (!cache.has(key)) cache.set(key, seriesFor(op, bars));
    return cache.get(key)!;
  };

  const evalCond = (c: Condition, i: number): boolean => {
    if (i < 1) return false;
    const L = getSeries(c.left), R = getSeries(c.right);
    const l0 = L[i], l1 = L[i - 1], r0 = R[i], r1 = R[i - 1];
    if (l0 == null || l1 == null || r0 == null || r1 == null) return false;
    switch (c.op) {
      case 'crossesAbove': return l1 <= r1 && l0 > r0;
      case 'crossesBelow': return l1 >= r1 && l0 < r0;
      case '>': return l0 > r0;
      case '<': return l0 < r0;
      case '>=': return l0 >= r0;
      case '<=': return l0 <= r0;
    }
  };

  const evalGroup = (g: ConditionGroup, i: number): boolean => {
    if (!g.conditions.length) return false;
    return g.op === 'AND' ? g.conditions.every((c) => evalCond(c, i)) : g.conditions.some((c) => evalCond(c, i));
  };

  const trades: Trade[] = [];
  const equity: number[] = [];
  let cash = strategy.capital;
  let qty = 0;
  let entryPrice = 0, entryTime = 0, entryFee = 0;
  const fee = (amt: number) => amt * (strategy.feePct / 100);

  for (let i = 0; i < bars.length; i++) {
    const b = bars[i];
    const inPos = qty > 0;

    if (inPos && strategy.stopLoss != null && b.low <= entryPrice * (1 - strategy.stopLoss / 100)) {
      const exit = entryPrice * (1 - strategy.stopLoss / 100);
      cash += qty * exit; const f = fee(qty * exit); cash -= f;
      const pnl = qty * (exit - entryPrice) - f - entryFee;
      trades.push({
        id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'SELL',
        trigger: `Stop-loss at ${strategy.stopLoss}%`, qty, price: exit, fee: f,
        pnl, pnlPct: (pnl / (qty * entryPrice)) * 100, time: entryTime,
        exitTime: b.time, exitPrice: exit,
      });
      qty = 0;
    } else if (inPos && strategy.takeProfit != null && b.high >= entryPrice * (1 + strategy.takeProfit / 100)) {
      const exit = entryPrice * (1 + strategy.takeProfit / 100);
      cash += qty * exit; const f = fee(qty * exit); cash -= f;
      const pnl = qty * (exit - entryPrice) - f - entryFee;
      trades.push({
        id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'SELL',
        trigger: `Take-profit at ${strategy.takeProfit}%`, qty, price: exit, fee: f,
        pnl, pnlPct: (pnl / (qty * entryPrice)) * 100, time: entryTime,
        exitTime: b.time, exitPrice: exit,
      });
      qty = 0;
    }

    if (!inPos && evalGroup(strategy.buy, i)) {
      const budget = strategy.sizing.type === 'pct' ? cash * (strategy.sizing.value / 100)
                   : strategy.sizing.type === 'fixedBDT' ? Math.min(cash, strategy.sizing.value)
                   : Math.min(cash, b.close * strategy.sizing.value);
      const buyQty = Math.floor(budget / b.close);
      if (buyQty > 0) {
        qty = buyQty;
        entryPrice = b.close;
        entryTime = b.time;
        entryFee = fee(qty * b.close);
        cash -= qty * b.close + entryFee;
        trades.push({
          id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'BUY',
          trigger: strategy.buy.conditions.map(conditionLabel).join(` ${strategy.buy.op} `),
          qty, price: b.close, fee: entryFee, time: b.time,
        });
      }
    } else if (inPos && evalGroup(strategy.sell, i)) {
      const exit = b.close;
      cash += qty * exit;
      const f = fee(qty * exit); cash -= f;
      const pnl = qty * (exit - entryPrice) - f - entryFee;
      trades.push({
        id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'SELL',
        trigger: strategy.sell.conditions.map(conditionLabel).join(` ${strategy.sell.op} `),
        qty, price: exit, fee: f, pnl, pnlPct: (pnl / (qty * entryPrice)) * 100,
        time: entryTime, exitTime: b.time, exitPrice: exit,
      });
      qty = 0;
    }

    equity.push(cash + qty * b.close);
  }
  return { trades, equity };
}
EOF

# ========== STORE ==========
N=$((N+1)); write "$N/$total store/useAppStore.ts"
cat > store/useAppStore.ts << 'EOF'
'use client';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Theme = 'light' | 'dark';
type Lang = 'en' | 'bn';

interface AppState {
  theme: Theme; lang: Lang;
  activeSymbol: string;
  timeframe: 'D' | 'W' | 'M' | 'Q' | 'Y';
  feePct: number;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  setLang: (l: Lang) => void;
  setSymbol: (s: string) => void;
  setTimeframe: (t: AppState['timeframe']) => void;
  setFee: (f: number) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', feePct: 0.15,
  setTheme: (t) => set({ theme: t }),
  toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
  setLang: (l) => set({ lang: l }),
  setSymbol: (s) => set({ activeSymbol: s }),
  setTimeframe: (t) => set({ timeframe: t }),
  setFee: (f) => set({ feePct: f }),
}), { name: 'bongotrader-app' }));
EOF

N=$((N+1)); write "$N/$total store/useDrawingsStore.ts"
cat > store/useDrawingsStore.ts << 'EOF'
'use client';
import { create } from 'zustand';
import type { Drawing, ToolId } from '@/lib/drawing/types';

interface S {
  tool: ToolId;
  drawings: Drawing[];
  selectedId: string | null;
  setTool: (t: ToolId) => void;
  add: (d: Drawing) => void;
  remove: (id: string) => void;
  select: (id: string | null) => void;
  update: (id: string, patch: Partial<Drawing>) => void;
  clearAll: () => void;
}

export const useDrawingsStore = create<S>((set) => ({
  tool: 'select',
  drawings: [],
  selectedId: null,
  setTool: (tool) => set({ tool }),
  add: (d) => set((s) => ({ drawings: [...s.drawings, d] })),
  remove: (id) => set((s) => ({ drawings: s.drawings.filter((x) => x.id !== id), selectedId: null })),
  select: (selectedId) => set({ selectedId }),
  update: (id, patch) => set((s) => ({ drawings: s.drawings.map((d) => d.id === id ? { ...d, ...patch } : d) })),
  clearAll: () => set({ drawings: [], selectedId: null }),
}));
EOF

N=$((N+1)); write "$N/$total store/useStrategyStore.ts"
cat > store/useStrategyStore.ts << 'EOF'
'use client';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Strategy } from '@/lib/strategy/types';

const defaultStrategy = (): Strategy => ({
  id: 'default',
  name: 'EMA Crossover',
  buy: {
    op: 'AND',
    conditions: [{
      id: 'c1',
      left: { kind: 'indicator', name: 'EMA', period: 20 },
      op: 'crossesAbove',
      right: { kind: 'indicator', name: 'EMA', period: 50 },
    }],
  },
  sell: {
    op: 'AND',
    conditions: [{
      id: 'c2',
      left: { kind: 'indicator', name: 'EMA', period: 20 },
      op: 'crossesBelow',
      right: { kind: 'indicator', name: 'EMA', period: 50 },
    }],
  },
  capital: 100000,
  sizing: { type: 'pct', value: 100 },
  feePct: 0.15,
});

const blank = (name = 'New strategy'): Strategy => ({
  id: Math.random().toString(36).slice(2, 10),
  name,
  buy: { op: 'AND', conditions: [] },
  sell: { op: 'AND', conditions: [] },
  capital: 100000,
  sizing: { type: 'pct', value: 100 },
  feePct: 0.15,
});

interface S {
  strategies: Strategy[];
  current: Strategy;
  setCurrent: (s: Strategy) => void;
  save: () => void;
  remove: (id: string) => void;
  load: (id: string) => void;
  createNew: () => void;
}

export const useStrategyStore = create<S>()(persist((set) => ({
  strategies: [],
  current: defaultStrategy(),
  setCurrent: (current) => set({ current }),
  save: () => set((s) => {
    const idx = s.strategies.findIndex((x) => x.id === s.current.id);
    const strategies = idx >= 0 ? s.strategies.map((x, i) => i === idx ? s.current : x) : [...s.strategies, s.current];
    return { strategies };
  }),
  remove: (id) => set((s) => ({ strategies: s.strategies.filter((x) => x.id !== id) })),
  load: (id) => set((s) => ({ current: s.strategies.find((x) => x.id === id) ?? s.current })),
  createNew: () => set({ current: blank() }),
}), { name: 'bongotrader-strategies' }));
EOF

# ========== MESSAGES ==========
N=$((N+1)); write "$N/$total messages/en.json"
cat > messages/en.json << 'EOF'
{
  "nav": { "account": "Account", "chart": "Chart", "backtesting": "Backtesting" },
  "market": { "openIn": "OPEN in", "closeIn": "CLOSE in", "closed": "Market Closed" },
  "chart": { "inactive": "Inactive", "saveImage": "Save as image" },
  "actions": { "retry": "Retry", "connect": "Connect Telegram" },
  "errors": { "network": "Network error — could not reach market data." }
}
EOF

N=$((N+1)); write "$N/$total messages/bn.json"
cat > messages/bn.json << 'EOF'
{
  "nav": { "account": "অ্যাকাউন্ট", "chart": "চার্ট", "backtesting": "ব্যাকটেস্টিং" },
  "market": { "openIn": "খুলবে", "closeIn": "বন্ধ হবে", "closed": "মার্কেট বন্ধ" },
  "chart": { "inactive": "নিষ্ক্রিয়", "saveImage": "ছবি সংরক্ষণ" },
  "actions": { "retry": "আবার চেষ্টা", "connect": "টেলিগ্রাম সংযুক্ত" },
  "errors": { "network": "নেটওয়ার্ক ত্রুটি — মার্কেট ডেটা লোড হয়নি।" }
}
EOF

# ========== API ==========
N=$((N+1)); write "$N/$total app/api/health/route.ts"
cat > app/api/health/route.ts << 'EOF'
import { NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const sb = adminClient();
    const { error } = await sb.from('mv_symbols').select('symbol').limit(1);
    if (error) throw error;
    return NextResponse.json({ db: 'ok' });
  } catch (e) {
    console.error('[health]', e);
    return NextResponse.json({ db: 'down' }, { status: 503 });
  }
}
EOF

N=$((N+1)); write "$N/$total app/api/symbols/route.ts"
cat > app/api/symbols/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get('q') ?? '';
  const page = parseInt(req.nextUrl.searchParams.get('page') ?? '0');
  const size = Math.min(parseInt(req.nextUrl.searchParams.get('size') ?? '50'), 200);
  const sb = adminClient();
  let query = sb
    .from('mv_daily_summary')
    .select('symbol,display_name,is_active,last_close,pct_change,last_volume', { count: 'exact' })
    .order('display_name', { ascending: true })
    .range(page * size, page * size + size - 1);
  if (q) query = query.ilike('display_name', `%${q}%`);
  const { data, count, error } = await query;
  if (error) return NextResponse.json({ error: 'db' }, { status: 500 });
  return NextResponse.json({ data, total: count ?? 0, page, size });
}
EOF

N=$((N+1)); write "$N/$total app/api/movers/route.ts"
cat > app/api/movers/route.ts << 'EOF'
import { NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET() {
  const sb = adminClient();
  const [gain, lose] = await Promise.all([
    sb.from('mv_daily_summary').select('symbol,last_close,pct_change')
      .not('pct_change', 'is', null).gt('pct_change', 0)
      .order('pct_change', { ascending: false }).limit(5),
    sb.from('mv_daily_summary').select('symbol,last_close,pct_change')
      .not('pct_change', 'is', null).lt('pct_change', 0)
      .order('pct_change', { ascending: true }).limit(5),
  ]);
  return NextResponse.json({ gainers: gain.data ?? [], losers: lose.data ?? [] });
}
EOF

N=$((N+1)); write "$N/$total app/api/ohlcv/route.ts"
cat > app/api/ohlcv/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

type TF = 'D' | 'W' | 'M' | 'Q' | 'Y';
const trunc: Record<TF, string> = { D: 'day', W: 'week', M: 'month', Q: 'quarter', Y: 'year' };

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const symbol = sp.get('symbol');
  const tf = (sp.get('tf') ?? 'D') as TF;
  const limit = Math.min(parseInt(sp.get('limit') ?? '500'), 5000);
  if (!symbol) return NextResponse.json({ error: 'symbol' }, { status: 400 });

  const sb = adminClient();

  if (tf === 'D') {
    const { data, error } = await sb.from('daily_ohlcv')
      .select('date,open,high,low,close,volume')
      .eq('symbol', symbol)
      .order('date', { ascending: false })
      .limit(limit);
    if (error) return NextResponse.json({ error: 'db' }, { status: 500 });
    return NextResponse.json({ data: (data ?? []).reverse() });
  }

  const { data: raw } = await sb.from('daily_ohlcv')
    .select('date,open,high,low,close,volume')
    .eq('symbol', symbol)
    .order('date', { ascending: false })
    .limit(limit * 7);

  const buckets = new Map<string, any>();
  for (const r of (raw ?? []).reverse()) {
    const d = new Date(r.date);
    const key = bucketKey(d, tf);
    const cur = buckets.get(key);
    if (!cur) buckets.set(key, { date: key, open: r.open, high: r.high, low: r.low, close: r.close, volume: r.volume });
    else {
      cur.high = Math.max(cur.high, r.high);
      cur.low = Math.min(cur.low, r.low);
      cur.close = r.close;
      cur.volume = (cur.volume ?? 0) + (r.volume ?? 0);
    }
  }
  return NextResponse.json({ data: Array.from(buckets.values()).slice(-limit) });
}

function bucketKey(d: Date, tf: TF) {
  const y = d.getUTCFullYear();
  const m = d.getUTCMonth();
  if (tf === 'W') {
    const onejan = new Date(Date.UTC(y, 0, 1));
    const wk = Math.ceil((((d.getTime() - onejan.getTime()) / 86400000) + onejan.getUTCDay() + 1) / 7);
    return `${y}-W${String(wk).padStart(2, '0')}-01`;
  }
  if (tf === 'M') return `${y}-${String(m + 1).padStart(2, '0')}-01`;
  if (tf === 'Q') return `${y}-Q${Math.floor(m / 3) + 1}-01`;
  return `${y}-01-01`;
}
EOF

# ========== APP ROOT ==========
N=$((N+1)); write "$N/$total app/globals.css"
cat > app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root, [data-theme="dark"] {
  --bg: #0B1220;
  --panel: #111A2C;
  --border: #1E2A44;
  --text: #E6EDF7;
  --muted: #8B9BB4;
  --accent: #22C1A4;
  --bull: #16A34A;
  --bear: #DC2626;
  --card-bg: rgba(17,26,44,0.85);
  --card-shadow: 0 8px 24px rgba(0,0,0,0.5);
}

[data-theme="light"] {
  --bg: #F4F8FF;
  --panel: rgba(200,225,255,0.55);
  --border: #BFD9FF;
  --text: #0A2540;
  --muted: #4A6A8A;
  --accent: #1E6FD9;
  --bull: #0E9F6E;
  --bear: #D92D20;
  --card-bg: rgba(200,225,255,0.55);
  --card-shadow: 0 8px 24px rgba(10,37,64,0.08);
}

html, body { background: var(--bg); color: var(--text); transition: background 300ms ease, color 300ms ease; }

[data-theme="light"] body {
  background: linear-gradient(180deg, #EEF5FF 0%, #DCEBFF 100%);
  min-height: 100vh;
}

.card {
  background: var(--card-bg);
  box-shadow: var(--card-shadow);
  border: 1px solid var(--border);
  border-radius: 12px;
  backdrop-filter: blur(8px);
}

.chart-pane { background: var(--panel); border-radius: 12px; overflow: hidden; position: relative; }
EOF

N=$((N+1)); write "$N/$total app/layout.tsx"
cat > app/layout.tsx << 'EOF'
import './globals.css';
import { NextIntlClientProvider } from 'next-intl';
import { getLocale, getMessages } from 'next-intl/server';
import Providers from './providers';
import HealthGate from '@/components/HealthGate';

export const metadata = { title: 'Bongotrader', description: 'DSE Trading & Backtesting' };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();
  const messages = await getMessages();
  return (
    <html lang={locale} data-theme="dark" suppressHydrationWarning>
      <body>
        <NextIntlClientProvider locale={locale} messages={messages}>
          <Providers>
            <HealthGate>{children}</HealthGate>
          </Providers>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
EOF

N=$((N+1)); write "$N/$total app/providers.tsx"
cat > app/providers.tsx << 'EOF'
'use client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useAppStore } from '@/store/useAppStore';

export default function Providers({ children }: { children: React.ReactNode }) {
  const [qc] = useState(() => new QueryClient({
    defaultOptions: { queries: { staleTime: 5 * 60_000, refetchOnWindowFocus: false } },
  }));
  const theme = useAppStore((s) => s.theme);
  useEffect(() => { document.documentElement.setAttribute('data-theme', theme); }, [theme]);
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>;
}
EOF

N=$((N+1)); write "$N/$total app/page.tsx"
cat > app/page.tsx << 'EOF'
import { redirect } from 'next/navigation';
export default function Home() { redirect('/chart'); }
EOF

N=$((N+1)); write "$N/$total app/chart/page.tsx"
cat > app/chart/page.tsx << 'EOF'
'use client';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import ChartToolbar from '@/components/ChartToolbar';
import ChartPanel from '@/components/ChartPanel';
import DrawingToolbar from '@/components/DrawingToolbar';
import InstrumentPicker from '@/components/InstrumentPicker';

export default function ChartPage() {
  return (
    <>
      <TopBar />
      <main className="grid grid-cols-1 md:grid-cols-[280px_1fr] gap-3 p-3 pb-20">
        <aside className="card p-2 order-2 md:order-1"><InstrumentPicker /></aside>
        <section className="card order-1 md:order-2 overflow-hidden">
          <ChartToolbar />
          <DrawingToolbar />
          <ChartPanel />
        </section>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

N=$((N+1)); write "$N/$total app/account/page.tsx"
cat > app/account/page.tsx << 'EOF'
'use client';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
export default function AccountPage() {
  return (
    <>
      <TopBar />
      <main className="p-3 pb-20">
        <div className="card p-4">
          <h2 className="text-lg font-semibold mb-2">Account & Portfolio</h2>
          <p className="text-sm text-[color:var(--muted)]">Holdings, PnL summary, watchlist — coming soon.</p>
        </div>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

N=$((N+1)); write "$N/$total app/backtest/page.tsx"
cat > app/backtest/page.tsx << 'EOF'
'use client';
import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Play, Pause, StepForward, RotateCcw } from 'lucide-react';
import TopBar from '@/components/TopBar';
import BottomTabs from '@/components/BottomTabs';
import InstrumentPicker from '@/components/InstrumentPicker';
import StrategyBuilder from '@/components/StrategyBuilder';
import ReplayChart from '@/components/ReplayChart';
import ReplayMetrics from '@/components/ReplayMetrics';
import TradeLog from '@/components/TradeLog';
import { useAppStore } from '@/store/useAppStore';
import { useStrategyStore } from '@/store/useStrategyStore';
import { evaluateStrategy } from '@/lib/strategy/evaluator';

const SPEEDS = [0.5, 1, 2, 5, 10, 15, 20, 30, 40, 50] as const;

export default function BacktestPage() {
  const symbol = useAppStore((s) => s.activeSymbol);
  const [cursor, setCursor] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const strategy = useStrategyStore((s) => s.current);

  const { data: bars = [] } = useQuery({
    queryKey: ['ohlcv-replay', symbol],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=D&limit=1500`);
      const j = await r.json();
      return (j.data as any[]).map((d) => ({
        time: Math.floor(new Date(d.date).getTime() / 1000),
        open: Number(d.open), high: Number(d.high), low: Number(d.low),
        close: Number(d.close), volume: Number(d.volume ?? 0),
      }));
    },
  });

  const { trades: allTrades, equity } = useMemo(() => {
    if (!bars.length) return { trades: [], equity: [] };
    return evaluateStrategy(strategy, symbol, bars);
  }, [bars, strategy, symbol]);

  useEffect(() => { setCursor(0); setPlaying(false); }, [symbol, bars.length]);

  useEffect(() => {
    if (!playing) return;
    const intervalMs = 400 / speed;
    const id = setInterval(() => {
      setCursor((c) => {
        if (c >= bars.length - 1) { setPlaying(false); return c; }
        return c + 1;
      });
    }, intervalMs);
    return () => clearInterval(id);
  }, [playing, speed, bars.length]);

  const visibleMarkers = useMemo(() => {
    const cutTime = bars[cursor]?.time ?? 0;
    return allTrades
      .filter((t) => t.time <= cutTime)
      .map((t) => ({
        time: t.time,
        side: t.side,
        text: t.side === 'BUY'
          ? `BUY ${t.qty} @ ৳${t.price.toFixed(2)}`
          : `SELL ${t.qty} @ ৳${t.price.toFixed(2)}${t.pnl != null ? ` (PnL ৳${t.pnl.toFixed(0)})` : ''}`,
      }));
  }, [allTrades, bars, cursor]);

  const liveMetrics = useMemo(() => {
    if (!bars.length) return null;
    const cutTime = bars[cursor].time;
    const closed = allTrades.filter((t) => t.side === 'SELL' && (t.exitTime ?? t.time) <= cutTime);
    const buys = allTrades.filter((t) => t.side === 'BUY' && t.time <= cutTime);
    const open = buys.find((b) => !closed.find((c) => c.time === b.time));
    const positionQty = open ? open.qty : 0;
    const entryPrice = open ? open.price : 0;
    const cash = strategy.capital
      - buys.reduce((s, b) => s + b.qty * b.price + b.fee, 0)
      + closed.reduce((s, c) => s + c.qty * c.price - c.fee, 0);
    const realised = closed.reduce((s, c) => s + (c.pnl ?? 0), 0);
    const unrealised = positionQty ? (bars[cursor].close - entryPrice) * positionQty : 0;
    const equityNow = cash + positionQty * bars[cursor].close;
    const peak = Math.max(...equity.slice(0, cursor + 1), strategy.capital);
    const drawdown = peak > 0 ? ((peak - equityNow) / peak) * 100 : 0;
    const wins = closed.filter((c) => (c.pnl ?? 0) > 0).length;
    const winRate = closed.length ? (wins / closed.length) * 100 : 0;
    const rets = closed.map((c) => c.pnlPct ?? 0);
    const mean = rets.reduce((s, r) => s + r, 0) / (rets.length || 1);
    const std = Math.sqrt(rets.reduce((s, r) => s + (r - mean) ** 2, 0) / (rets.length || 1)) || 1e-9;
    const sharpe = (mean / std) * Math.sqrt(252);
    return {
      time: bars[cursor].time, equity: equityNow, cash, position: positionQty,
      realised, unrealised, drawdown, winRate, sharpe, trades: closed.length,
    };
  }, [bars, cursor, allTrades, equity, strategy.capital]);

  return (
    <>
      <TopBar />
      <main className="grid grid-cols-1 md:grid-cols-[280px_1fr] gap-3 p-3 pb-20">
        <aside className="card p-2 order-2 md:order-1"><InstrumentPicker /></aside>
        <section className="space-y-3 order-1 md:order-2">
          <div className="card p-3"><StrategyBuilder /></div>
          <div className="card p-2">
            <div className="flex items-center gap-2 flex-wrap pb-2 border-b border-[color:var(--border)]">
              <button onClick={() => setPlaying(!playing)} className="p-2 rounded-lg bg-[color:var(--accent)] text-white">
                {playing ? <Pause size={14} /> : <Play size={14} />}
              </button>
              <button onClick={() => setCursor((c) => Math.min(c + 1, bars.length - 1))}
                className="p-2 rounded-lg border border-[color:var(--border)]"><StepForward size={14} /></button>
              <button onClick={() => { setCursor(0); setPlaying(false); }}
                className="p-2 rounded-lg border border-[color:var(--border)]"><RotateCcw size={14} /></button>
              <select value={speed} onChange={(e) => setSpeed(Number(e.target.value))}
                className="bg-transparent border border-[color:var(--border)] rounded-lg px-2 py-1 text-xs">
                {SPEEDS.map((s) => <option key={s} value={s} className="bg-[color:var(--bg)]">{s}×</option>)}
              </select>
              <span className="text-xs text-[color:var(--muted)] tabular-nums">bar {cursor + 1} / {bars.length}</span>
            </div>
            <ReplayChart bars={bars} cursor={cursor} markers={visibleMarkers} />
          </div>
          <div className="card p-3">{liveMetrics && <ReplayMetrics {...liveMetrics} />}</div>
          <div className="card p-3"><TradeLog trades={allTrades} /></div>
        </section>
      </main>
      <BottomTabs />
    </>
  );
}
EOF

# ========== COMPONENTS ==========
N=$((N+1)); write "$N/$total components/HealthGate.tsx"
cat > components/HealthGate.tsx << 'EOF'
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
EOF

N=$((N+1)); write "$N/$total components/MarketCountdown.tsx"
cat > components/MarketCountdown.tsx << 'EOF'
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
EOF

N=$((N+1)); write "$N/$total components/ActiveInstrumentChip.tsx"
cat > components/ActiveInstrumentChip.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { ChevronDown } from 'lucide-react';
import { bdt } from '@/lib/format';

export default function ActiveInstrumentChip() {
  const symbol = useAppStore((s) => s.activeSymbol);
  const { data } = useQuery({
    queryKey: ['summary', symbol],
    queryFn: async () => {
      const r = await fetch(`/api/symbols?q=${symbol}&size=20`);
      const j = await r.json();
      return (j.data ?? []).find((x: any) => x.symbol === symbol) ?? null;
    },
  });
  const up = (data?.pct_change ?? 0) >= 0;
  return (
    <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[color:var(--border)]">
      <span className="font-semibold">{symbol}</span>
      {!data?.is_active && (
        <span className="text-[10px] px-1.5 py-0.5 rounded bg-[color:var(--muted)]/20 text-[color:var(--muted)]">
          Inactive
        </span>
      )}
      {data && (
        <>
          <span className="font-mono tabular-nums">{bdt(Number(data.last_close ?? 0))}</span>
          <span className={up ? 'text-[color:var(--bull)] text-xs' : 'text-[color:var(--bear)] text-xs'}>
            {up ? '▲' : '▼'} {Math.abs(data.pct_change ?? 0).toFixed(2)}%
          </span>
        </>
      )}
      <ChevronDown size={14} className="text-[color:var(--muted)]" />
    </div>
  );
}
EOF

N=$((N+1)); write "$N/$total components/MoversTicker.tsx"
cat > components/MoversTicker.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';
import { TrendingUp, TrendingDown } from 'lucide-react';

export default function MoversTicker() {
  const { data } = useQuery({
    queryKey: ['movers'],
    queryFn: async () => (await fetch('/api/movers')).json(),
  });
  const gainers = data?.gainers ?? [];
  const losers = data?.losers ?? [];
  return (
    <div className="hidden md:flex items-center gap-1 overflow-x-auto max-w-[520px] px-2 py-1.5 rounded-lg border border-[color:var(--border)]">
      {gainers.map((g: any) => (
        <span key={'g' + g.symbol} className="text-xs px-2 whitespace-nowrap">
          <span className="font-medium">{g.symbol}</span>
          <span className="text-[color:var(--bull)] ml-1">+{g.pct_change?.toFixed(2)}%</span>
        </span>
      ))}
      <TrendingUp size={14} className="text-[color:var(--bull)] mx-1" />
      <TrendingDown size={14} className="text-[color:var(--bear)] mx-1" />
      {losers.map((l: any) => (
        <span key={'l' + l.symbol} className="text-xs px-2 whitespace-nowrap">
          <span className="font-medium">{l.symbol}</span>
          <span className="text-[color:var(--bear)] ml-1">{l.pct_change?.toFixed(2)}%</span>
        </span>
      ))}
    </div>
  );
}
EOF

N=$((N+1)); write "$N/$total components/ThemeToggle.tsx"
cat > components/ThemeToggle.tsx << 'EOF'
'use client';
import { Moon, Sun } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';
export default function ThemeToggle() {
  const { theme, toggleTheme } = useAppStore();
  return (
    <button onClick={toggleTheme} className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10" aria-label="theme">
      {theme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
    </button>
  );
}
EOF

N=$((N+1)); write "$N/$total components/LanguageToggle.tsx"
cat > components/LanguageToggle.tsx << 'EOF'
'use client';
import { useAppStore } from '@/store/useAppStore';
export default function LanguageToggle() {
  const { lang, setLang } = useAppStore();
  return (
    <button onClick={() => setLang(lang === 'en' ? 'bn' : 'en')}
      className="px-2 py-1 text-xs rounded-lg border border-[color:var(--border)] font-medium">
      {lang === 'en' ? 'বাংলা' : 'EN'}
    </button>
  );
}
EOF

N=$((N+1)); write "$N/$total components/TopBar.tsx"
cat > components/TopBar.tsx << 'EOF'
'use client';
import MarketCountdown from './MarketCountdown';
import ActiveInstrumentChip from './ActiveInstrumentChip';
import MoversTicker from './MoversTicker';
import ThemeToggle from './ThemeToggle';
import LanguageToggle from './LanguageToggle';
import { useAppStore } from '@/store/useAppStore';
import { Bell, User } from 'lucide-react';

export default function TopBar() {
  const { feePct, setFee } = useAppStore();
  return (
    <header className="sticky top-0 z-40 backdrop-blur border-b border-[color:var(--border)]"
      style={{ background: 'var(--card-bg)' }}>
      <div className="flex items-center gap-3 px-3 py-2 overflow-x-auto">
        <MarketCountdown />
        <ActiveInstrumentChip />
        <MoversTicker />
        <div className="ml-auto flex items-center gap-2">
          <label className="flex items-center gap-1 text-xs">
            Fee:
            <input type="number" step="0.01" min="0" max="5" value={feePct}
              onChange={(e) => setFee(parseFloat(e.target.value) || 0)}
              className="w-14 bg-transparent border border-[color:var(--border)] rounded px-1 py-0.5 text-center" />%
          </label>
          <LanguageToggle />
          <ThemeToggle />
          <button className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10"><Bell size={16} /></button>
          <button className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10"><User size={16} /></button>
        </div>
      </div>
    </header>
  );
}
EOF

N=$((N+1)); write "$N/$total components/BottomTabs.tsx"
cat > components/BottomTabs.tsx << 'EOF'
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Wallet, LineChart, FlaskConical } from 'lucide-react';
import { useTranslations } from 'next-intl';

const tabs = [
  { href: '/account', key: 'account', Icon: Wallet },
  { href: '/chart', key: 'chart', Icon: LineChart },
  { href: '/backtest', key: 'backtesting', Icon: FlaskConical },
] as const;

export default function BottomTabs() {
  const path = usePathname();
  const t = useTranslations('nav');
  return (
    <nav className="fixed bottom-0 inset-x-0 z-40 border-t border-[color:var(--border)] backdrop-blur"
      style={{ background: 'var(--card-bg)' }}>
      <ul className="grid grid-cols-3">
        {tabs.map(({ href, key, Icon }) => {
          const active = path.startsWith(href);
          return (
            <li key={href}>
              <Link href={href}
                className={`flex flex-col items-center py-2 text-xs gap-1 ${active ? 'text-[color:var(--accent)]' : 'text-[color:var(--muted)]'}`}>
                <Icon size={18} />
                {t(key)}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
EOF

N=$((N+1)); write "$N/$total components/InstrumentPicker.tsx"
cat > components/InstrumentPicker.tsx << 'EOF'
'use client';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Search } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';

export default function InstrumentPicker() {
  const [q, setQ] = useState('');
  const { activeSymbol, setSymbol } = useAppStore();
  const { data } = useQuery({
    queryKey: ['symbols', q],
    queryFn: async () => {
      const r = await fetch(`/api/symbols?q=${encodeURIComponent(q)}&size=100`);
      return r.json();
    },
  });
  const items = data?.data ?? [];
  return (
    <div>
      <div className="flex items-center gap-2 px-2 py-1.5 border-b border-[color:var(--border)]">
        <Search size={14} className="text-[color:var(--muted)]" />
        <input value={q} onChange={(e) => setQ(e.target.value)}
          placeholder="Search symbol…" className="w-full bg-transparent text-sm outline-none" />
      </div>
      <div className="text-[10px] text-[color:var(--muted)] px-2 py-1">
        {(data?.total ?? 0).toLocaleString()} instruments
      </div>
      <ul className="max-h-[60vh] overflow-y-auto">
        {items.map((s: any) => {
          const up = (s.pct_change ?? 0) >= 0;
          return (
            <li key={s.symbol}>
              <button onClick={() => setSymbol(s.symbol)}
                className={`w-full text-left px-2 py-1.5 flex items-center justify-between text-xs hover:bg-[color:var(--muted)]/10 ${activeSymbol === s.symbol ? 'bg-[color:var(--accent)]/10' : ''}`}>
                <span className="flex items-center gap-1.5">
                  <span className="font-medium">{s.symbol}</span>
                  {!s.is_active && (
                    <span className="text-[9px] px-1 rounded bg-[color:var(--muted)]/20 text-[color:var(--muted)]">Inactive</span>
                  )}
                </span>
                <span className={up ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>
                  {up ? '+' : ''}{(s.pct_change ?? 0).toFixed(2)}%
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
EOF

N=$((N+1)); write "$N/$total components/ChartToolbar.tsx"
cat > components/ChartToolbar.tsx << 'EOF'
'use client';
import { CandlestickChart, LineChart, AreaChart, BarChart3, Image as ImageIcon, Layers } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';

const TFS = [
  { v: 'D', l: 'D' }, { v: 'W', l: 'W' }, { v: 'M', l: 'M' },
  { v: 'Q', l: 'Q' }, { v: 'Y', l: 'Y' },
] as const;

export default function ChartToolbar() {
  const { timeframe, setTimeframe } = useAppStore();
  return (
    <div className="flex items-center gap-2 flex-wrap p-2 border-b border-[color:var(--border)]">
      <div className="flex rounded-lg border border-[color:var(--border)] overflow-hidden">
        {TFS.map((t) => (
          <button key={t.v} onClick={() => setTimeframe(t.v)}
            className={`px-2.5 py-1 text-xs ${timeframe === t.v ? 'bg-[color:var(--accent)] text-white' : 'hover:bg-[color:var(--muted)]/10'}`}>
            {t.l}
          </button>
        ))}
      </div>
      <div className="flex gap-1 ml-2">
        <IconBtn icon={CandlestickChart} label="Candles" />
        <IconBtn icon={LineChart} label="Line" />
        <IconBtn icon={AreaChart} label="Area" />
        <IconBtn icon={BarChart3} label="Bars" />
      </div>
      <div className="flex gap-1 ml-auto">
        <IconBtn icon={Layers} label="Indicators" />
      </div>
    </div>
  );
}
function IconBtn({ icon: Icon, label }: { icon: any; label: string }) {
  return (
    <button title={label} className="p-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">
      <Icon size={14} />
    </button>
  );
}
EOF

N=$((N+1)); write "$N/$total components/ChartPanel.tsx"
cat > components/ChartPanel.tsx << 'EOF'
'use client';
import { useEffect, useRef } from 'react';
import { createChart, IChartApi, ISeriesApi, CandlestickData, ColorType } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';

export default function ChartPanel() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const seriesRef = useRef<ISeriesApi<'Candlestick'> | null>(null);
  const symbol = useAppStore((s) => s.activeSymbol);
  const tf = useAppStore((s) => s.timeframe);
  const theme = useAppStore((s) => s.theme);

  const { data, isLoading, error } = useQuery({
    queryKey: ['ohlcv', symbol, tf],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=${tf}&limit=500`);
      if (!r.ok) throw new Error('failed');
      const j = await r.json();
      return (j.data as any[]).map((d) => ({
        time: Math.floor(new Date(d.date).getTime() / 1000) as any,
        open: Number(d.open), high: Number(d.high), low: Number(d.low),
        close: Number(d.close),
      })) as CandlestickData[];
    },
  });

  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: {
        background: { type: ColorType.Solid, color: 'transparent' },
        textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540',
        fontFamily: 'ui-sans-serif',
      },
      grid: {
        vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
        horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 5, barSpacing: 8 },
      autoSize: true,
    });
    const series = chart.addCandlestickSeries({
      upColor: '#16A34A', downColor: '#DC2626',
      wickUpColor: '#16A34A', wickDownColor: '#DC2626',
      borderVisible: false,
    });
    chart.timeScale().subscribeVisibleLogicalRangeChange((r) => {
      if (!r) return;
      if (r.to - r.from < 5) {
        chart.timeScale().setVisibleLogicalRange({ from: r.from, to: r.from + 5 });
      }
    });
    chartRef.current = chart;
    seriesRef.current = series;
    chartRefs.chart = chart;
    chartRefs.series = series;
    return () => { chart.remove(); chartRefs.chart = null; chartRefs.series = null; };
  }, []);

  useEffect(() => {
    chartRef.current?.applyOptions({
      layout: {
        textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540',
        background: { type: ColorType.Solid, color: 'transparent' },
      },
      grid: {
        vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
        horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      },
    });
  }, [theme]);

  useEffect(() => {
    if (!seriesRef.current || !data) return;
    seriesRef.current.setData(data);
    chartRef.current?.timeScale().scrollToRealTime();
  }, [data]);

  return (
    <div className="chart-pane w-full h-[480px]">
      {isLoading && <div className="absolute inset-0 grid place-items-center text-[color:var(--muted)] z-20">Loading chart…</div>}
      {error && <div className="absolute inset-0 grid place-items-center text-[color:var(--bear)] z-20">Failed to load data</div>}
      <div ref={containerRef} className="w-full h-full" />
      <DrawingCanvas />
    </div>
  );
}
EOF

N=$((N+1)); write "$N/$total components/DrawingCanvas.tsx"
cat > components/DrawingCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef } from 'react';
import { chartRefs } from '@/lib/chartInstance';
import { useDrawingsStore } from '@/store/useDrawingsStore';
import { useAppStore } from '@/store/useAppStore';
import type { Drawing, ToolId } from '@/lib/drawing/types';

const COL = { bull: '#16A34A', bear: '#DC2626', accent: '#1E6FD9', select: '#F59E0B' };
const uid = () => Math.random().toString(36).slice(2, 10);

export default function DrawingCanvas() {
  const ref = useRef<HTMLCanvasElement>(null);
  const { tool, drawings, add, update, select, selectedId } = useDrawingsStore();
  const theme = useAppStore((s) => s.theme);
  const drawingsRef = useRef(drawings); drawingsRef.current = drawings;
  const toolRef = useRef(tool); toolRef.current = tool;
  const dragRef = useRef<{ id: string; a0: any; b0?: any } | null>(null);
  const drawRef = useRef<{ tool: ToolId; a: any; b: any } | null>(null);

  const toTimePrice = (x: number, y: number) => {
    const { chart, series } = chartRefs;
    if (!chart || !series) return null;
    const time = chart.timeScale().coordinateToTime(x);
    const price = series.coordinateToPrice(y);
    if (time == null || price == null) return null;
    const t = typeof time === 'number' ? time
      : Math.floor(Date.UTC((time as any).year, (time as any).month - 1, (time as any).day) / 1000);
    return { time: t, price };
  };
  const toXY = (time: number, price: number) => {
    const { chart, series } = chartRefs;
    if (!chart || !series) return null;
    const x = chart.timeScale().timeToCoordinate(time as any);
    const y = series.priceToCoordinate(price);
    if (x == null || y == null) return null;
    return { x, y };
  };

  const render = () => {
    const canvas = ref.current;
    const container = canvas?.parentElement;
    if (!canvas || !container) return;
    const dpr = window.devicePixelRatio || 1;
    const w = container.clientWidth, h = container.clientHeight;
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr; canvas.height = h * dpr;
      canvas.style.width = w + 'px'; canvas.style.height = h + 'px';
    }
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const all = drawRef.current ? [...drawingsRef.current, { ...drawRef.current, id: '__tmp__' } as any] : drawingsRef.current;
    for (const d of all) drawOne(ctx, d);
  };

  const drawOne = (ctx: CanvasRenderingContext2D, d: Drawing) => {
    const a = toXY(d.a.time, d.a.price);
    if (!a) return;
    const isSel = d.id === selectedId;
    const stroke = isSel ? COL.select : (d.tool === 'sell' || d.tool === 'redbox' ? COL.bear : d.tool === 'buy' || d.tool === 'greenbox' ? COL.bull : COL.accent);

    if (d.tool === 'hline') {
      ctx.strokeStyle = stroke; ctx.lineWidth = isSel ? 2.5 : 1.5;
      ctx.beginPath(); ctx.moveTo(0, a.y); ctx.lineTo(ctx.canvas.width, a.y); ctx.stroke();
      ctx.fillStyle = stroke; ctx.font = '11px ui-monospace';
      ctx.fillText(`৳${d.a.price.toFixed(2)}`, 6, a.y - 4);
      return;
    }
    if (d.tool === 'text') {
      ctx.font = '13px ui-sans-serif';
      const tw = ctx.measureText(d.text ?? '').width;
      ctx.fillStyle = stroke; ctx.fillRect(a.x - 4, a.y - 16, tw + 8, 20);
      ctx.fillStyle = '#fff'; ctx.fillText(d.text ?? '', a.x, a.y - 2);
      if (isSel) { ctx.strokeStyle = COL.select; ctx.lineWidth = 1.5; ctx.strokeRect(a.x - 5, a.y - 17, tw + 10, 22); }
      return;
    }
    if (d.tool === 'buy' || d.tool === 'sell') {
      const label = d.tool === 'buy' ? 'BUY' : 'SELL';
      const txt = `${label} @ ৳${d.a.price.toFixed(2)}`;
      ctx.font = 'bold 11px ui-sans-serif';
      const pw = ctx.measureText(txt).width + 14;
      ctx.fillStyle = d.tool === 'buy' ? COL.bull : COL.bear;
      roundRect(ctx, a.x - pw / 2, a.y - 22, pw, 18, 4); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.fillText(txt, a.x - pw / 2 + 7, a.y - 9);
      if (isSel) { ctx.strokeStyle = COL.select; ctx.lineWidth = 1.5; roundRect(ctx, a.x - pw / 2 - 1, a.y - 23, pw + 2, 20, 4); ctx.stroke(); }
      return;
    }
    if (!d.b) return;
    const b = toXY(d.b.time, d.b.price);
    if (!b) return;
    if (d.tool === 'trendline') {
      ctx.strokeStyle = stroke; ctx.lineWidth = isSel ? 2.5 : 1.5;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
      if (isSel) {
        ctx.fillStyle = COL.select;
        ctx.beginPath(); ctx.arc(a.x, a.y, 4, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(b.x, b.y, 4, 0, Math.PI * 2); ctx.fill();
      }
      return;
    }
    if (d.tool === 'greenbox' || d.tool === 'redbox') {
      const x = Math.min(a.x, b.x), y = Math.min(a.y, b.y);
      const w = Math.abs(b.x - a.x), h = Math.abs(b.y - a.y);
      ctx.fillStyle = d.tool === 'greenbox' ? 'rgba(22,163,74,0.18)' : 'rgba(220,38,38,0.18)';
      ctx.strokeStyle = stroke; ctx.lineWidth = isSel ? 2 : 1;
      ctx.fillRect(x, y, w, h); ctx.strokeRect(x, y, w, h);
    }
  };

  useEffect(() => { render(); }, [drawings, selectedId, theme]);

  useEffect(() => {
    const { chart } = chartRefs;
    if (!chart) return;
    const onRange = () => render();
    chart.timeScale().subscribeVisibleLogicalRangeChange(onRange);
    const ro = new ResizeObserver(() => render());
    if (ref.current?.parentElement) ro.observe(ref.current.parentElement);
    const id = requestAnimationFrame(render);
    return () => {
      chart.timeScale().unsubscribeVisibleLogicalRangeChange(onRange);
      ro.disconnect();
      cancelAnimationFrame(id);
    };
  }, []);

  const hitTest = (x: number, y: number): Drawing | null => {
    for (let i = drawingsRef.current.length - 1; i >= 0; i--) {
      const d = drawingsRef.current[i];
      const a = toXY(d.a.time, d.a.price); if (!a) continue;
      if (d.tool === 'hline' && Math.abs(y - a.y) < 8) return d;
      if ((d.tool === 'text' || d.tool === 'buy' || d.tool === 'sell') && Math.abs(x - a.x) < 40 && Math.abs(y - a.y) < 20) return d;
      if (d.b) {
        const b = toXY(d.b.time, d.b.price); if (!b) continue;
        if (d.tool === 'trendline') {
          const dx = b.x - a.x, dy = b.y - a.y, len2 = dx * dx + dy * dy;
          const t = Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / (len2 || 1)));
          const px = a.x + t * dx, py = a.y + t * dy;
          if (Math.hypot(x - px, y - py) < 8) return d;
        }
        if (d.tool === 'greenbox' || d.tool === 'redbox') {
          if (x >= Math.min(a.x, b.x) && x <= Math.max(a.x, b.x) && y >= Math.min(a.y, b.y) && y <= Math.max(a.y, b.y)) return d;
        }
      }
    }
    return null;
  };

  useEffect(() => {
    const el = ref.current?.parentElement;
    if (!el) return;

    const onDown = (e: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left, y = e.clientY - rect.top;
      const t = toolRef.current;

      if (t === 'select') {
        const hit = hitTest(x, y);
        if (!hit) return;
        e.preventDefault(); e.stopPropagation();
        select(hit.id);
        dragRef.current = { id: hit.id, a0: { ...hit.a }, b0: hit.b ? { ...hit.b } : undefined };
        el.addEventListener('pointermove', onMove);
        el.addEventListener('pointerup', onUp);
        return;
      }

      e.preventDefault(); e.stopPropagation();
      const tp = toTimePrice(x, y);
      if (!tp) return;
      if (t === 'text') {
        const txt = window.prompt('Text:');
        if (txt) add({ id: uid(), tool: t, a: tp, text: txt });
        return;
      }
      drawRef.current = { tool: t, a: tp, b: tp };
      el.addEventListener('pointermove', onMove);
      el.addEventListener('pointerup', onUp);
    };

    const onMove = (e: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      const x = e.clientX - rect.left, y = e.clientY - rect.top;
      if (drawRef.current) {
        const tp = toTimePrice(x, y);
        if (tp) drawRef.current.b = tp;
        render();
      } else if (dragRef.current) {
        const tp = toTimePrice(x, y);
        if (!tp) return;
        const { id, a0, b0 } = dragRef.current;
        const dT = tp.time - a0.time, dP = tp.price - a0.price;
        update(id, {
          a: { time: a0.time + dT, price: a0.price + dP },
          b: b0 ? { time: b0.time + dT, price: b0.price + dP } : undefined,
        });
      }
    };

    const onUp = () => {
      if (drawRef.current) {
        const { tool: t, a, b } = drawRef.current;
        if (['trendline', 'greenbox', 'redbox'].includes(t)) {
          if (a.time !== b.time || a.price !== b.price) add({ id: uid(), tool: t, a, b });
        } else {
          add({ id: uid(), tool: t, a });
        }
        drawRef.current = null;
      }
      dragRef.current = null;
      el.removeEventListener('pointermove', onMove);
      el.removeEventListener('pointerup', onUp);
    };

    el.addEventListener('pointerdown', onDown, { capture: true });
    return () => {
      el.removeEventListener('pointerdown', onDown, { capture: true });
      el.removeEventListener('pointermove', onMove);
      el.removeEventListener('pointerup', onUp);
    };
  }, [add, update, select]);

  return (
    <canvas ref={ref} className="overlay absolute inset-0 z-10"
      style={{ pointerEvents: 'none', cursor: tool === 'select' ? 'default' : 'crosshair' }} />
  );
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
EOF

N=$((N+1)); write "$N/$total components/DrawingToolbar.tsx"
cat > components/DrawingToolbar.tsx << 'EOF'
'use client';
import { MousePointer2, Minus, Type, ArrowUpRight, ArrowDownRight, Square, Trash2, Image as ImageIcon } from 'lucide-react';
import { useDrawingsStore } from '@/store/useDrawingsStore';
import type { ToolId } from '@/lib/drawing/types';

const TOOLS: { id: ToolId; Icon: any; label: string }[] = [
  { id: 'select', Icon: MousePointer2, label: 'Select' },
  { id: 'trendline', Icon: ArrowUpRight, label: 'Trendline' },
  { id: 'hline', Icon: Minus, label: 'Horizontal' },
  { id: 'text', Icon: Type, label: 'Text' },
  { id: 'buy', Icon: ArrowUpRight, label: 'Buy badge' },
  { id: 'sell', Icon: ArrowDownRight, label: 'Sell badge' },
  { id: 'greenbox', Icon: Square, label: 'Green box' },
  { id: 'redbox', Icon: Square, label: 'Red box' },
];

export default function DrawingToolbar() {
  const { tool, setTool, drawings, selectedId, remove, clearAll } = useDrawingsStore();

  const saveImage = () => {
    const container = document.querySelector('.chart-pane') as HTMLElement;
    if (!container) return;
    const canvases = Array.from(container.querySelectorAll('canvas')) as HTMLCanvasElement[];
    if (!canvases.length) return;
    const rect = container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const combined = document.createElement('canvas');
    combined.width = rect.width * dpr;
    combined.height = rect.height * dpr;
    const ctx = combined.getContext('2d')!;
    ctx.scale(dpr, dpr);
    const bg = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim() || '#fff';
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, rect.width, rect.height);
    for (const c of canvases) {
      const cRect = c.getBoundingClientRect();
      try { ctx.drawImage(c, cRect.left - rect.left, cRect.top - rect.top, cRect.width, cRect.height); } catch {}
    }
    const link = document.createElement('a');
    link.download = `bongotrader-${Date.now()}.png`;
    link.href = combined.toDataURL('image/png');
    link.click();
  };

  return (
    <div className="flex items-center gap-1 flex-wrap p-2 border-b border-[color:var(--border)]">
      {TOOLS.map(({ id, Icon, label }) => (
        <button key={id} onClick={() => setTool(id)} title={label}
          className={`p-1.5 rounded-lg border ${tool === id ? 'bg-[color:var(--accent)] text-white border-[color:var(--accent)]' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'}`}>
          <Icon size={14} />
        </button>
      ))}
      <div className="flex-1" />
      {selectedId && (
        <button onClick={() => remove(selectedId)}
          className="p-1.5 rounded-lg border border-[color:var(--bear)] text-[color:var(--bear)]" title="Delete">
          <Trash2 size={14} />
        </button>
      )}
      <button onClick={clearAll} className="px-2 py-1 text-xs rounded-lg border border-[color:var(--border)]" title="Clear all">Clear</button>
      <button onClick={saveImage} className="p-1.5 rounded-lg border border-[color:var(--border)]" title="Save as image">
        <ImageIcon size={14} />
      </button>
    </div>
  );
}
EOF

N=$((N+1)); write "$N/$total components/StrategyBuilder.tsx"
cat > components/StrategyBuilder.tsx << 'EOF'
'use client';
import { Plus, Trash2, Save } from 'lucide-react';
import { useStrategyStore } from '@/store/useStrategyStore';
import type { Comparator, Condition, ConditionGroup, Operand, Strategy } from '@/lib/strategy/types';

const OPERAND_TYPES: { v: string; label: string }[] = [
  { v: 'close', label: 'Price Close' },
  { v: 'open', label: 'Price Open' },
  { v: 'high', label: 'Price High' },
  { v: 'low', label: 'Price Low' },
  { v: 'SMA', label: 'SMA' },
  { v: 'EMA', label: 'EMA' },
  { v: 'WMA', label: 'WMA' },
  { v: 'RSI', label: 'RSI' },
  { v: 'BB_upper', label: 'BB Upper' },
  { v: 'BB_mid', label: 'BB Mid' },
  { v: 'BB_lower', label: 'BB Lower' },
  { v: 'volume', label: 'Volume' },
  { v: 'constant', label: 'Constant' },
];

const OPS: { v: Comparator; label: string }[] = [
  { v: 'crossesAbove', label: 'crosses above' },
  { v: 'crossesBelow', label: 'crosses below' },
  { v: '>', label: '>' },
  { v: '<', label: '<' },
  { v: '>=', label: '≥' },
  { v: '<=', label: '≤' },
];

function fromType(v: string, period = 20, value = 0): Operand {
  if (v === 'close' || v === 'open' || v === 'high' || v === 'low') return { kind: 'price', field: v as any };
  if (v === 'volume') return { kind: 'volume' };
  if (v === 'constant') return { kind: 'constant', value };
  return { kind: 'indicator', name: v as any, period };
}
function toType(op: Operand): string {
  if (op.kind === 'price') return op.field;
  if (op.kind === 'volume') return 'volume';
  if (op.kind === 'constant') return 'constant';
  return op.name;
}

export default function StrategyBuilder() {
  const { current, setCurrent, save, strategies, load, createNew } = useStrategyStore();
  const update = (patch: Partial<Strategy>) => setCurrent({ ...current, ...patch });

  const setCondition = (side: 'buy' | 'sell', idx: number, patch: Partial<Condition>) => {
    const g: ConditionGroup = { ...current[side] };
    g.conditions = g.conditions.map((c, i) => i === idx ? { ...c, ...patch } : c);
    update({ [side]: g } as any);
  };
  const addCondition = (side: 'buy' | 'sell') => {
    const g: ConditionGroup = { ...current[side] };
    g.conditions = [...g.conditions, {
      id: Math.random().toString(36).slice(2, 8),
      left: { kind: 'indicator', name: 'EMA', period: 20 },
      op: 'crossesAbove',
      right: { kind: 'indicator', name: 'EMA', period: 50 },
    }];
    update({ [side]: g } as any);
  };
  const removeCondition = (side: 'buy' | 'sell', idx: number) => {
    const g: ConditionGroup = { ...current[side] };
    g.conditions = g.conditions.filter((_, i) => i !== idx);
    update({ [side]: g } as any);
  };

  const Group = ({ side, label }: { side: 'buy' | 'sell'; label: string }) => (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <span className={`font-semibold ${side === 'buy' ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}`}>{label}</span>
        <select value={current[side].op}
          onChange={(e) => update({ [side]: { ...current[side], op: e.target.value as 'AND' | 'OR' } } as any)}
          className="text-xs bg-transparent border border-[color:var(--border)] rounded px-2 py-1">
          <option value="AND">AND</option>
          <option value="OR">OR</option>
        </select>
      </div>
      {current[side].conditions.map((c, i) => (
        <div key={c.id} className="grid grid-cols-1 md:grid-cols-[1fr_auto_1fr_auto] gap-2 items-center p-2 rounded-lg border border-[color:var(--border)]">
          <OperandPicker value={c.left} onChange={(o) => setCondition(side, i, { left: o })} />
          <select value={c.op} onChange={(e) => setCondition(side, i, { op: e.target.value as Comparator })}
            className="text-xs bg-transparent border border-[color:var(--border)] rounded px-2 py-1">
            {OPS.map((o) => <option key={o.v} value={o.v}>{o.label}</option>)}
          </select>
          <OperandPicker value={c.right} onChange={(o) => setCondition(side, i, { right: o })} />
          <button onClick={() => removeCondition(side, i)} className="p-1.5 rounded border border-[color:var(--border)]">
            <Trash2 size={12} />
          </button>
        </div>
      ))}
      <button onClick={() => addCondition(side)} className="flex items-center gap-1 text-xs px-2 py-1 rounded border border-[color:var(--border)]">
        <Plus size={12} /> Add condition
      </button>
    </div>
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 flex-wrap">
        <input value={current.name} onChange={(e) => update({ name: e.target.value })}
          className="px-2 py-1 rounded border border-[color:var(--border)] bg-transparent text-sm font-medium"
          placeholder="Strategy name" />
        <select onChange={(e) => e.target.value && load(e.target.value)} defaultValue=""
          className="text-xs bg-transparent border border-[color:var(--border)] rounded px-2 py-1">
          <option value="">Load saved…</option>
          {strategies.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <button onClick={createNew} className="text-xs px-2 py-1 rounded border border-[color:var(--border)]">New</button>
        <button onClick={save} className="flex items-center gap-1 text-xs px-2 py-1 rounded bg-[color:var(--accent)] text-white">
          <Save size={12} /> Save
        </button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
        <Field label="Capital (৳)">
          <input type="number" value={current.capital} onChange={(e) => update({ capital: Number(e.target.value) })}
            className="w-full bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-sm" />
        </Field>
        <Field label="Fee %">
          <input type="number" step="0.01" value={current.feePct} onChange={(e) => update({ feePct: Number(e.target.value) })}
            className="w-full bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-sm" />
        </Field>
        <Field label="Sizing">
          <div className="flex gap-1">
            <select value={current.sizing.type}
              onChange={(e) => update({ sizing: { ...current.sizing, type: e.target.value as any } })}
              className="bg-transparent border border-[color:var(--border)] rounded px-1 text-xs">
              <option value="pct">%</option>
              <option value="fixedBDT">৳</option>
              <option value="shares">sh</option>
            </select>
            <input type="number" value={current.sizing.value}
              onChange={(e) => update({ sizing: { ...current.sizing, value: Number(e.target.value) } })}
              className="w-full bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-sm" />
          </div>
        </Field>
        <Field label="SL / TP %">
          <div className="flex gap-1">
            <input type="number" placeholder="SL" value={current.stopLoss ?? ''}
              onChange={(e) => update({ stopLoss: e.target.value ? Number(e.target.value) : undefined })}
              className="w-full bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-sm" />
            <input type="number" placeholder="TP" value={current.takeProfit ?? ''}
              onChange={(e) => update({ takeProfit: e.target.value ? Number(e.target.value) : undefined })}
              className="w-full bg-transparent border border-[color:var(--border)] rounded px-2 py-1 text-sm" />
          </div>
        </Field>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Group side="buy" label="BUY when" />
        <Group side="sell" label="SELL when" />
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block">
      <span className="text-[10px] uppercase tracking-wide text-[color:var(--muted)]">{label}</span>
      {children}
    </label>
  );
}

function OperandPicker({ value, onChange }: { value: Operand; onChange: (o: Operand) => void }) {
  const t = toType(value);
  const period = value.kind === 'indicator' ? value.period : 20;
  const constant = value.kind === 'constant' ? value.value : 0;
  return (
    <div className="flex gap-1 items-center">
      <select value={t} onChange={(e) => onChange(fromType(e.target.value, period, constant))}
        className="text-xs bg-transparent border border-[color:var(--border)] rounded px-1 py-1 flex-1">
        {OPERAND_TYPES.map((o) => <option key={o.v} value={o.v}>{o.label}</option>)}
      </select>
      {value.kind === 'indicator' && (
        <input type="number" value={period}
          onChange={(e) => onChange({ ...(value as any), period: Number(e.target.value) })}
          className="w-14 text-xs bg-transparent border border-[color:var(--border)] rounded px-1 py-1" />
      )}
      {value.kind === 'constant' && (
        <input type="number" value={constant}
          onChange={(e) => onChange({ kind: 'constant', value: Number(e.target.value) })}
          className="w-16 text-xs bg-transparent border border-[color:var(--border)] rounded px-1 py-1" />
      )}
    </div>
  );
}
EOF

N=$((N+1)); write "$N/$total components/ReplayChart.tsx"
cat > components/ReplayChart.tsx << 'EOF'
'use client';
import { useEffect, useRef } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType, SeriesMarker, Time } from 'lightweight-charts';
import { useAppStore } from '@/store/useAppStore';

interface Props {
  bars: { time: number; open: number; high: number; low: number; close: number }[];
  cursor: number;
  markers: { time: number; side: 'BUY' | 'SELL'; text: string }[];
}

export default function ReplayChart({ bars, cursor, markers }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const seriesRef = useRef<ISeriesApi<'Candlestick'> | null>(null);
  const theme = useAppStore((s) => s.theme);

  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: {
        background: { type: ColorType.Solid, color: 'transparent' },
        textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540',
        fontFamily: 'ui-sans-serif',
      },
      grid: {
        vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
        horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 3, barSpacing: 6 },
      autoSize: true,
    });
    const series = chart.addCandlestickSeries({
      upColor: '#16A34A', downColor: '#DC2626',
      wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false,
    });
    chartRef.current = chart; seriesRef.current = series;
    return () => { chart.remove(); };
  }, []);

  useEffect(() => {
    if (!seriesRef.current) return;
    const visible = bars.slice(0, cursor + 1).map((b) => ({
      time: b.time as Time, open: b.open, high: b.high, low: b.low, close: b.close,
    }));
    seriesRef.current.setData(visible);
    const ms: SeriesMarker<Time>[] = markers.map((m) => ({
      time: m.time as Time,
      position: m.side === 'BUY' ? 'belowBar' : 'aboveBar',
      color: m.side === 'BUY' ? '#16A34A' : '#DC2626',
      shape: m.side === 'BUY' ? 'arrowUp' : 'arrowDown',
      text: m.text,
    }));
    seriesRef.current.setMarkers(ms);
  }, [bars, cursor, markers]);

  useEffect(() => {
    chartRef.current?.applyOptions({
      layout: { textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540' },
    });
  }, [theme]);

  return <div ref={containerRef} className="w-full h-[380px]" />;
}
EOF

N=$((N+1)); write "$N/$total components/ReplayMetrics.tsx"
cat > components/ReplayMetrics.tsx << 'EOF'
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
EOF

N=$((N+1)); write "$N/$total components/TradeLog.tsx"
cat > components/TradeLog.tsx << 'EOF'
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
EOF

# ========== SQL ==========
N=$((N+1)); write "$N/$total sql/schema.sql"
cat > sql/schema.sql << 'EOF'
-- ============================================================
-- Bongotrader Supabase schema
-- Run this ONCE in: supabase.com → SQL Editor → New query
-- ============================================================

-- Materialized view: all symbols with last date + active flag
drop materialized view if exists mv_symbols cascade;
create materialized view mv_symbols as
select
  d.symbol,
  d.symbol as display_name,
  min(d.date) as first_date,
  max(d.date) as last_date,
  (max(d.date) >= current_date - interval '7 days') as is_active,
  (select close from daily_ohlcv x where x.symbol = d.symbol order by date desc limit 1) as last_close,
  (select volume from daily_ohlcv x where x.symbol = d.symbol order by date desc limit 1) as last_volume
from daily_ohlcv d
group by d.symbol;
create unique index if not exists mv_symbols_pk on mv_symbols(symbol);
create index if not exists mv_symbols_name on mv_symbols(display_name);

-- Materialized view: per-symbol daily summary (drives movers + picker)
drop materialized view if exists mv_daily_summary cascade;
create materialized view mv_daily_summary as
with ranked as (
  select symbol, date, close, volume,
    row_number() over (partition by symbol order by date desc) as rn
  from daily_ohlcv
)
select
  s.symbol,
  s.display_name,
  s.is_active,
  s.last_date,
  max(case when r.rn = 1 then r.close end) as last_close,
  max(case when r.rn = 2 then r.close end) as prev_close,
  case
    when max(case when r.rn = 2 then r.close end) > 0
    then ((max(case when r.rn = 1 then r.close end)
         - max(case when r.rn = 2 then r.close end))
        / max(case when r.rn = 2 then r.close end)) * 100
    else null
  end as pct_change,
  max(case when r.rn = 1 then r.volume end) as last_volume
from mv_symbols s
left join ranked r on r.symbol = s.symbol and r.rn <= 2
group by s.symbol, s.display_name, s.is_active, s.last_date;
create unique index if not exists mv_daily_summary_pk on mv_daily_summary(symbol);
create index if not exists mv_daily_summary_pct on mv_daily_summary(pct_change desc nulls last);

-- Chart drawings persistence (per user)
create table if not exists chart_drawings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  symbol text not null,
  timeframe text not null,
  payload jsonb not null,
  updated_at timestamptz default now()
);
alter table chart_drawings enable row level security;
drop policy if exists dr_read on chart_drawings;
create policy dr_read on chart_drawings for select using (auth.uid() = user_id);
drop policy if exists dr_write on chart_drawings;
create policy dr_write on chart_drawings for all using (auth.uid() = user_id);

-- RLS on the main table (read-only for public)
alter table daily_ohlcv enable row level security;
drop policy if exists daily_read on daily_ohlcv;
create policy daily_read on daily_ohlcv for select using (true);

-- ============================================================
-- OPTIONAL — nightly auto-refresh of the views at 15:05 BST
-- ============================================================
-- First enable pg_cron: Dashboard → Database → Extensions → pg_cron
-- Then uncomment and run:
--
-- select cron.schedule('refresh-mvs', '5 9 * * *', $$
--   refresh materialized view concurrently mv_symbols;
--   refresh materialized view concurrently mv_daily_summary;
-- $$);
--
-- To refresh manually at any time:
--   refresh materialized view concurrently mv_symbols;
--   refresh materialized view concurrently mv_daily_summary;
EOF

echo ""
echo "✅ All $total files created!"
echo ""
echo "════════════════════════════════════════"
echo "  NEXT STEPS (do these in order)"
echo "════════════════════════════════════════"
echo ""
echo "1. Edit .env.local — replace the two PASTE_YOUR_... placeholders"
echo "   with real keys from supabase.com → Settings → API"
echo "   (⚠️  ROTATE the service_role key first if you leaked it!)"
echo ""
echo "2. Run sql/schema.sql in Supabase SQL Editor (once)"
echo ""
echo "3. npm install"
echo ""
echo "4. npm run dev"
echo ""
echo "5. Open http://localhost:3000"
echo ""
echo "🎉 Done!"