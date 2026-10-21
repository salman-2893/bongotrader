'use client';
import { Plus, Trash2, Save } from 'lucide-react';
import { useStrategyStore } from '@/store/useStrategyStore';
import type { Comparator, Condition, ConditionGroup, Operand, Strategy } from '@/lib/strategy/types';

const OPERAND_TYPES = [
  { v: 'close', label: 'Price Close' }, { v: 'open', label: 'Price Open' },
  { v: 'high', label: 'Price High' }, { v: 'low', label: 'Price Low' },
  { v: 'SMA', label: 'SMA' }, { v: 'EMA', label: 'EMA' }, { v: 'WMA', label: 'WMA' },
  { v: 'RSI', label: 'RSI' }, { v: 'volume', label: 'Volume' }, { v: 'constant', label: 'Constant' },
];

const OPS: { v: Comparator; label: string }[] = [
  { v: 'crossesAbove', label: 'crosses above' }, { v: 'crossesBelow', label: 'crosses below' },
  { v: '>', label: '>' }, { v: '<', label: '<' }, { v: '>=', label: '≥' }, { v: '<=', label: '≤' },
];

function fromType(v: string, period = 20, value = 0): Operand {
  if (['close','open','high','low'].includes(v)) return { kind: 'price', field: v as any };
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

// Reusable dark-mode select
const DarkSelect = ({ value, onChange, options, className="" }: any) => (
  <select value={value} onChange={onChange} 
    className={`bg-[#1E2A44] text-[#E6EDF7] border border-[#3B4A6B] rounded px-2 py-1 text-xs outline-none focus:border-[color:var(--accent)] ${className}`}>
    {options.map((o: any) => <option key={o.v} value={o.v} className="bg-[#111A2C] text-[#E6EDF7]">{o.label}</option>)}
  </select>
);

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
    g.conditions = [...g.conditions, { id: Math.random().toString(36).slice(2, 8), left: { kind: 'indicator', name: 'EMA', period: 20 }, op: 'crossesAbove', right: { kind: 'indicator', name: 'EMA', period: 50 } }];
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
        <DarkSelect value={current[side].op} onChange={(e: any) => update({ [side]: { ...current[side], op: e.target.value } } as any)} options={[{v:'AND',label:'AND (All must trigger)'},{v:'OR',label:'OR (Any triggers)'}]} />
      </div>
      {current[side].conditions.map((c, i) => (
        <div key={c.id} className="grid grid-cols-1 md:grid-cols-[1fr_auto_1fr_auto] gap-2 items-center p-2 rounded-lg border border-[color:var(--border)]">
          
          {/* Left Operand */}
          <div className="flex gap-1 items-center">
            <DarkSelect value={toType(c.left)} onChange={(e: any) => setCondition(side, i, { left: fromType(e.target.value) })} options={OPERAND_TYPES} className="flex-1" />
            {c.left.kind === 'indicator' && <input type="number" value={c.left.period} onChange={e => setCondition(side, i, { left: { ...c.left, period: Number(e.target.value) } as any })} className="w-12 bg-[#1E2A44] text-[#E6EDF7] border border-[#3B4A6B] rounded px-1 py-1 text-xs" />}
          </div>

          <DarkSelect value={c.op} onChange={(e: any) => setCondition(side, i, { op: e.target.value })} options={OPS} />

          {/* Right Operand */}
          <div className="flex gap-1 items-center">
            <DarkSelect value={toType(c.right)} onChange={(e: any) => setCondition(side, i, { right: fromType(e.target.value) })} options={OPERAND_TYPES} className="flex-1" />
            {c.right.kind === 'indicator' && <input type="number" value={c.right.period} onChange={e => setCondition(side, i, { right: { ...c.right, period: Number(e.target.value) } as any })} className="w-12 bg-[#1E2A44] text-[#E6EDF7] border border-[#3B4A6B] rounded px-1 py-1 text-xs" />}
          </div>

          <button onClick={() => removeCondition(side, i)} className="p-1.5 rounded border border-[color:var(--border)] hover:text-red-500"><Trash2 size={12} /></button>
        </div>
      ))}
      <button onClick={() => addCondition(side)} className="flex items-center gap-1 text-xs px-2 py-1 rounded border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">
        <Plus size={12} /> Add condition
      </button>
    </div>
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 flex-wrap">
        <input value={current.name} onChange={(e) => update({ name: e.target.value })} className="px-2 py-1 rounded border border-[color:var(--border)] bg-transparent text-sm font-medium" placeholder="Strategy name" />
        <DarkSelect onChange={(e: any) => e.target.value && load(e.target.value)} defaultValue="" options={[{v:'',label:'Load saved...'}, ...strategies.map(s => ({ v: s.id, label: s.name }))]} />
        <button onClick={createNew} className="text-xs px-2 py-1 rounded border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">New</button>
        <button onClick={save} className="flex items-center gap-1 text-xs px-2 py-1 rounded bg-[color:var(--accent)] text-white"><Save size={12} /> Save</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Group side="buy" label="BUY when" />
        <Group side="sell" label="SELL when" />
      </div>
    </div>
  );
}
