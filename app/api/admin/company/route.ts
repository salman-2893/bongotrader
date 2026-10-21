import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function POST(req: NextRequest) {
  const body = await req.json();
  const sb = adminClient();
  // Upsert into companies table
  const { error } = await sb.from('companies').upsert(body, { onConflict: 'symbol' });
  if (error) return NextResponse.json({ error }, { status: 500 });
  return NextResponse.json({ success: true });
}
