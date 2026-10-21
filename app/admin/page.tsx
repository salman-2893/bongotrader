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
