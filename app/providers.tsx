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
