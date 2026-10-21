'use client';
import { useState } from 'react';
import { CandlestickChart, LineChart, AreaChart, BarChart3, Layers, X, Search } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';
import { INDICATOR_DEFS } from '@/lib/indicators/engine';

const TFS = [{ v: 'D', l: 'D' }, { v: 'W', l: 'W' }, { v: 'M', l: 'M' }, { v: 'Q', l: 'Q' }, { v: 'Y', l: 'Y' }] as const;

export default function ChartToolbar() {
  const { timeframe, setTimeframe, chartType, setChartType, indicators, addIndicator, removeIndicator, updateIndicator } = useAppStore();
  const [showModal, setShowModal] = useState(false);
  const [search, setSearch] = useState('');
  const [customPeriod, setCustomPeriod] = useState<number | ''>('');

  const filtered = INDICATOR_DEFS.filter(i => i.name.toLowerCase().includes(search.toLowerCase()) || i.type.toLowerCase().includes(search.toLowerCase()));

  const handleAdd = (def: any) => {
    addIndicator({ 
      id: Math.random().toString(36).slice(2,8), 
      type: def.type, 
      period: customPeriod || def.defaultPeriod, 
      color: def.color 
    });
    setShowModal(false);
    setCustomPeriod('');
    setSearch('');
  };

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

      {/* Active Indicators List - Editable */}
      <div className="flex gap-2 ml-4 overflow-x-auto max-w-[50%] no-scrollbar">
        {indicators.map(ind => (
           <div key={ind.id} className="flex items-center gap-1 text-[10px] px-2 py-1 rounded-full border border-[color:var(--border)] bg-[color:var(--bg)]/50 whitespace-nowrap">
             <span style={{color: ind.color}}>{ind.type}(</span>
             <input 
                type="number" 
                value={ind.period} 
                onChange={(e) => updateIndicator(ind.id, { period: Number(e.target.value) })}
                className="w-8 bg-transparent border-b border-[color:var(--border)] text-center focus:outline-none focus:border-[color:var(--accent)]"
             />
             <span style={{color: ind.color}}>)</span>
             <button onClick={() => removeIndicator(ind.id)} className="text-[color:var(--muted)] hover:text-red-500 ml-1"><X size={10}/></button>
           </div>
        ))}
      </div>

      <div className="flex gap-1 ml-auto">
        <button onClick={() => setShowModal(true)} className="flex items-center gap-1 px-2 py-1.5 rounded-lg border border-[color:var(--border)] hover:bg-[color:var(--muted)]/10">
          <Layers size={14} /> <span className="text-xs font-medium">Indicators</span>
        </button>
      </div>

      {showModal && (
        <div className="absolute right-2 top-full mt-1 w-80 card p-0 z-50 shadow-2xl flex flex-col max-h-[70vh]">
          <div className="p-3 border-b border-[color:var(--border)] flex justify-between items-center">
            <h3 className="font-semibold text-sm">Add Indicator</h3>
            <button onClick={() => setShowModal(false)}><X size={16} /></button>
          </div>
          
          <div className="p-3 border-b border-[color:var(--border)] flex gap-2">
             <div className="relative flex-1">
               <Search size={14} className="absolute left-2 top-1/2 -translate-y-1/2 text-[color:var(--muted)]"/>
               <input autoFocus value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search..." className="w-full bg-transparent border border-[color:var(--border)] rounded pl-8 pr-2 py-1.5 text-xs outline-none focus:border-[color:var(--accent)]"/>
             </div>
             <input type="number" placeholder="Period" value={customPeriod} onChange={e => setCustomPeriod(e.target.value ? Number(e.target.value) : '')} className="w-20 bg-transparent border border-[color:var(--border)] rounded px-2 py-1.5 text-xs text-center outline-none focus:border-[color:var(--accent)]" title="Custom Period (Leave blank for default)"/>
          </div>

          <div className="overflow-y-auto p-1">
            {filtered.map(ind => (
              <button key={ind.type} onClick={() => handleAdd(ind)} className="w-full text-left px-3 py-2 text-xs hover:bg-[color:var(--muted)]/10 rounded flex justify-between items-center group">
                <span>{ind.name} <span className="text-[10px] text-[color:var(--muted)]">(Default: {ind.defaultPeriod})</span></span>
                <span className="text-[10px] text-[color:var(--muted)] group-hover:text-[color:var(--accent)]">+ Add</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
