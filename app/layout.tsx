import './globals.css';
import { NextIntlClientProvider } from 'next-intl';
import { getLocale, getMessages } from 'next-intl/server';
import Providers from './providers';
import HealthGate from '@/components/HealthGate';
import ClientIntlProvider from '@/components/ClientIntlProvider';

export const metadata = { title: 'Chartbongo.com | DSE Terminal', description: 'Trade Smarter' };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <body>
        <ClientIntlProvider>
          <Providers>
            <HealthGate>{children}</HealthGate>
          </Providers>
        </ClientIntlProvider>
      </body>
    </html>
  );
}
