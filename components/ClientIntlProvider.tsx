'use client';
import { NextIntlClientProvider } from 'next-intl';
import { useAppStore } from '@/store/useAppStore';
import en from '../messages/en.json';
import bn from '../messages/bn.json';

export default function ClientIntlProvider({ children }: { children: React.ReactNode }) {
  const lang = useAppStore((state) => state.lang);
  const messages = lang === 'bn' ? bn : en;

  return (
    <NextIntlClientProvider locale={lang} messages={messages}>
      {children}
    </NextIntlClientProvider>
  );
}