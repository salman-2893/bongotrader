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
