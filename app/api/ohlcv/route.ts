import { NextRequest, NextResponse } from 'next/server';
import { adminClient } from '@/lib/supabase-admin';

type TF = 'D' | 'W' | 'M' | 'Q' | 'Y';

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const symbol = sp.get('symbol');
  const tf = (sp.get('tf') ?? 'D') as TF;
  const limit = Math.min(parseInt(sp.get('limit') ?? '500'), 5000);
  if (!symbol) return NextResponse.json({ error: 'symbol' }, { status: 400 });

  const sb = adminClient();

  if (tf === 'D') {
    const { data, error } = await sb.from('daily_ohlcv')
      .select('date,open,high,low,close,volume').eq('symbol', symbol)
      .order('date', { ascending: false }).limit(limit);
    if (error) return NextResponse.json({ error: 'db' }, { status: 500 });
    return NextResponse.json({ data: (data ?? []).reverse() });
  }

  const { data: raw } = await sb.from('daily_ohlcv')
    .select('date,open,high,low,close,volume').eq('symbol', symbol)
    .order('date', { ascending: false }).limit(limit * 7);

  const buckets = new Map<string, any>();
  for (const r of (raw ?? []).reverse()) {
    const d = new Date(r.date);
    const key = bucketKey(d, tf);
    const cur = buckets.get(key);
    if (!cur) buckets.set(key, { date: key, open: r.open, high: r.high, low: r.low, close: r.close, volume: r.volume });
    else {
      cur.high = Math.max(cur.high, r.high); cur.low = Math.min(cur.low, r.low);
      cur.close = r.close; cur.volume = (cur.volume ?? 0) + (r.volume ?? 0);
    }
  }
  return NextResponse.json({ data: Array.from(buckets.values()).slice(-limit) });
}

function bucketKey(d: Date, tf: TF) {
  const y = d.getUTCFullYear();
  const m = d.getUTCMonth();
  if (tf === 'W') {
    // Fix: Return actual valid YYYY-MM-DD format (start of week)
    const day = d.getUTCDay() || 7; 
    d.setUTCDate(d.getUTCDate() - day + 1); 
    return d.toISOString().slice(0, 10);
  }
  if (tf === 'M') return `${y}-${String(m + 1).padStart(2, '0')}-01`;
  if (tf === 'Q') {
    const qm = Math.floor(m / 3) * 3;
    return `${y}-${String(qm + 1).padStart(2, '0')}-01`;
  }
  return `${y}-01-01`;
}
