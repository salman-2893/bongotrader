import { NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const sb = adminClient();
    const { error } = await sb.from('mv_symbols').select('symbol').limit(1);
    if (error) throw error;
    return NextResponse.json({ db: 'ok' });
  } catch (e) {
    console.error('[health]', e);
    return NextResponse.json({ db: 'down' }, { status: 503 });
  }
}
