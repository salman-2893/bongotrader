import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET(req: NextRequest, { params }: { params: { symbol: string } }) {
  const sb = adminClient();
  const { data, error } = await sb.from('companies').select('*').eq('symbol', params.symbol).single();
  if (error && error.code !== 'PGRST116') return NextResponse.json({ error: 'db' }, { status: 500 });
  return NextResponse.json({ data });
}
