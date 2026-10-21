import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

export async function GET(req: NextRequest) {
  const q = req.nextUrl.searchParams.get('q') ?? '';
  const page = parseInt(req.nextUrl.searchParams.get('page') ?? '0');
  const size = Math.min(parseInt(req.nextUrl.searchParams.get('size') ?? '50'), 2000); // Increased limit for screener
  const sb = adminClient();
  
  let query = sb
    .from('mv_daily_summary')
    .select('symbol,display_name,is_active,last_close,pct_change,last_volume', { count: 'exact' })
    .order('display_name', { ascending: true })
    .range(page * size, page * size + size - 1);
    
  if (q) query = query.ilike('display_name', `%${q}%`);
  
  const { data, count, error } = await query;
  if (error) return NextResponse.json({ error: 'db' }, { status: 500 });
  return NextResponse.json({ data, total: count ?? 0, page, size });
}
