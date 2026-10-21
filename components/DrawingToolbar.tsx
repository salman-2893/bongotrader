'use client';
import { MousePointer2, Minus, Type, ArrowUpRight, ArrowDownRight, Square, Trash2, Image as ImageIcon } from 'lucide-react';
import { useDrawingsStore } from '@/store/useDrawingsStore';
import type { ToolId } from '@/lib/drawing/types';

const TOOLS = [
  { id: 'select' as ToolId, Icon: MousePointer2, label: 'Select', color: '' },
  { id: 'trendline' as ToolId, Icon: ArrowUpRight, label: 'Trendline', color: '' },
  { id: 'hline' as ToolId, Icon: Minus, label: 'Horizontal', color: '' },
  { id: 'text' as ToolId, Icon: Type, label: 'Text', color: '' },
  { id: 'buy' as ToolId, Icon: ArrowUpRight, label: 'Buy Badge', color: 'text-[color:var(--bull)]' },
  { id: 'sell' as ToolId, Icon: ArrowDownRight, label: 'Sell Badge', color: 'text-[color:var(--bear)]' },
  { id: 'greenbox' as ToolId, Icon: Square, label: 'Green Box', color: 'text-[color:var(--bull)]' },
  { id: 'redbox' as ToolId, Icon: Square, label: 'Red Box', color: 'text-[color:var(--bear)]' },
];

export default function DrawingToolbar() {
  const { tool, setTool, selectedId, remove, clearAll } = useDrawingsStore();

  const saveImage = () => {
    const container = document.querySelector('.chart-pane') as HTMLElement;
    if (!container) return;
    const canvases = Array.from(container.querySelectorAll('canvas')) as HTMLCanvasElement[];
    const rect = container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const combined = document.createElement('canvas');
    combined.width = rect.width * dpr; combined.height = rect.height * dpr;
    const ctx = combined.getContext('2d')!;
    ctx.scale(dpr, dpr);
    ctx.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim() || '#fff';
    ctx.fillRect(0, 0, rect.width, rect.height);
    for (const c of canvases) {
      const cRect = c.getBoundingClientRect();
      try { ctx.drawImage(c, cRect.left - rect.left, cRect.top - rect.top, cRect.width, cRect.height); } catch {}
    }
    const link = document.createElement('a'); link.download = `bongotrader-${Date.now()}.png`; link.href = combined.toDataURL('image/png'); link.click();
  };

  return (
    <div className="flex items-center gap-1 flex-wrap p-2 border-b border-[color:var(--border)]">
      {TOOLS.map(({ id, Icon, label, color }) => (
        <button key={id} onClick={() => setTool(id)} title={label}
          className={`p-1.5 rounded-lg border transition-colors ${tool === id ? 'bg-[color:var(--accent)] text-white border-[color:var(--accent)]' : 'border-[color:var(--border)] hover:bg-[color:var(--muted)]/10'} ${tool !== id && color ? color : ''}`}>
          <Icon size={14} />
        </button>
      ))}
      <div className="flex-1" />
      {selectedId && <button onClick={() => remove(selectedId)} className="p-1.5 rounded-lg border border-[color:var(--bear)] text-[color:var(--bear)]"><Trash2 size={14} /></button>}
      <button onClick={clearAll} className="px-2 py-1 text-xs rounded-lg border border-[color:var(--border)]">Clear</button>
      <button onClick={saveImage} className="p-1.5 rounded-lg border border-[color:var(--border)]"><ImageIcon size={14} /></button>
    </div>
  );
}
