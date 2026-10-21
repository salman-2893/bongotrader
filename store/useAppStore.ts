'use client';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type Theme = 'light' | 'dark'; type Lang = 'en' | 'bn'; type ChartType = 'candlestick' | 'line' | 'area' | 'bar';
export type IndicatorInstance = { id: string; type: string; period: number; color: string; };

interface AppState {
  theme: Theme; lang: Lang; activeSymbol: string;
  timeframe: 'D' | 'W' | 'M' | 'Q' | 'Y';
  chartType: ChartType;
  feePct: number;
  indicators: IndicatorInstance[];
  paperCash: number;
  paperHoldings: Record<string, { qty: number; avg: number }>;
  setTheme: (t: Theme) => void;
  toggleTheme: () => void;
  setLang: (l: Lang) => void;
  setSymbol: (s: string) => void;
  setTimeframe: (t: AppState['timeframe']) => void;
  setChartType: (t: ChartType) => void;
  setFee: (f: number) => void;
  addIndicator: (ind: IndicatorInstance) => void;
  removeIndicator: (id: string) => void;
  updateIndicator: (id: string, updates: Partial<IndicatorInstance>) => void; // New action
  executeTrade: (type: 'BUY'|'SELL', price: number, qty: number) => void;
  resetPaperAccount: (cash: number, fee: number) => void;
}

export const useAppStore = create<AppState>()(persist((set, get) => ({
  theme: 'dark', lang: 'en', activeSymbol: 'AIBL', timeframe: 'D', chartType: 'candlestick', feePct: 0.15,
  indicators: [], paperCash: 100000, paperHoldings: {},
  
  setTheme: (t) => set({ theme: t }),
  toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
  setLang: (l) => set({ lang: l }),
  setSymbol: (s) => set({ activeSymbol: s }),
  setTimeframe: (t) => set({ timeframe: t }),
  setChartType: (t) => set({ chartType: t }),
  setFee: (f) => set({ feePct: f }),
  
  addIndicator: (ind) => set((s) => ({ indicators: [...s.indicators, ind] })),
  removeIndicator: (id) => set((s) => ({ indicators: s.indicators.filter(i => i.id !== id) })),
  updateIndicator: (id, updates) => set((s) => ({ indicators: s.indicators.map(i => i.id === id ? { ...i, ...updates } : i) })),
  
  executeTrade: (type, price, qty) => set((s) => {
    const cost = price * qty;
    const fee = cost * (s.feePct / 100);
    if (type === 'BUY') {
      if (s.paperCash < cost + fee) return s;
      const current = s.paperHoldings[s.activeSymbol] || { qty: 0, avg: 0 };
      const newQty = current.qty + qty;
      const newAvg = ((current.qty * current.avg) + cost) / newQty;
      return { paperCash: s.paperCash - cost - fee, paperHoldings: { ...s.paperHoldings, [s.activeSymbol]: { qty: newQty, avg: newAvg } } };
    } else {
      const current = s.paperHoldings[s.activeSymbol] || { qty: 0, avg: 0 };
      if (current.qty < qty) return s;
      const newQty = current.qty - qty;
      const newHoldings = { ...s.paperHoldings };
      if (newQty === 0) delete newHoldings[s.activeSymbol];
      else newHoldings[s.activeSymbol] = { ...current, qty: newQty };
      return { paperCash: s.paperCash + cost - fee, paperHoldings: newHoldings };
    }
  }),
  
  resetPaperAccount: (cash, fee) => set({ paperCash: cash, feePct: fee, paperHoldings: {} }),
}), { name: 'chartbongo-app' }));
