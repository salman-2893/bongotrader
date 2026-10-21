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
