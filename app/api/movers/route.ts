import { NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET() {
  const sb = adminClient();
  const [gain, lose] = await Promise.all([
    sb.from('mv_daily_summary').select('symbol,last_close,pct_change')
      .not('pct_change', 'is', null).gt('pct_change', 0)
      .order('pct_change', { ascending: false }).limit(5),
    sb.from('mv_daily_summary').select('symbol,last_close,pct_change')
      .not('pct_change', 'is', null).lt('pct_change', 0)
      .order('pct_change', { ascending: true }).limit(5),
  ]);
  return NextResponse.json({ gainers: gain.data ?? [], losers: lose.data ?? [] });
}
