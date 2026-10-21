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
