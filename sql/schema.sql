-- ============================================================
-- Bongotrader Supabase schema
-- Run this ONCE in: supabase.com → SQL Editor → New query
-- ============================================================

-- Materialized view: all symbols with last date + active flag
drop materialized view if exists mv_symbols cascade;
create materialized view mv_symbols as
select
  d.symbol,
  d.symbol as display_name,
  min(d.date) as first_date,
  max(d.date) as last_date,
  (max(d.date) >= current_date - interval '7 days') as is_active,
  (select close from daily_ohlcv x where x.symbol = d.symbol order by date desc limit 1) as last_close,
  (select volume from daily_ohlcv x where x.symbol = d.symbol order by date desc limit 1) as last_volume
from daily_ohlcv d
group by d.symbol;
create unique index if not exists mv_symbols_pk on mv_symbols(symbol);
create index if not exists mv_symbols_name on mv_symbols(display_name);

-- Materialized view: per-symbol daily summary (drives movers + picker)
drop materialized view if exists mv_daily_summary cascade;
create materialized view mv_daily_summary as
with ranked as (
  select symbol, date, close, volume,
    row_number() over (partition by symbol order by date desc) as rn
  from daily_ohlcv
)
select
  s.symbol,
  s.display_name,
  s.is_active,
  s.last_date,
  max(case when r.rn = 1 then r.close end) as last_close,
  max(case when r.rn = 2 then r.close end) as prev_close,
  case
    when max(case when r.rn = 2 then r.close end) > 0
    then ((max(case when r.rn = 1 then r.close end)
         - max(case when r.rn = 2 then r.close end))
        / max(case when r.rn = 2 then r.close end)) * 100
    else null
  end as pct_change,
  max(case when r.rn = 1 then r.volume end) as last_volume
from mv_symbols s
left join ranked r on r.symbol = s.symbol and r.rn <= 2
group by s.symbol, s.display_name, s.is_active, s.last_date;
create unique index if not exists mv_daily_summary_pk on mv_daily_summary(symbol);
create index if not exists mv_daily_summary_pct on mv_daily_summary(pct_change desc nulls last);

-- Chart drawings persistence (per user)
create table if not exists chart_drawings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  symbol text not null,
  timeframe text not null,
  payload jsonb not null,
  updated_at timestamptz default now()
);
alter table chart_drawings enable row level security;
drop policy if exists dr_read on chart_drawings;
create policy dr_read on chart_drawings for select using (auth.uid() = user_id);
drop policy if exists dr_write on chart_drawings;
create policy dr_write on chart_drawings for all using (auth.uid() = user_id);

-- RLS on the main table (read-only for public)
alter table daily_ohlcv enable row level security;
drop policy if exists daily_read on daily_ohlcv;
create policy daily_read on daily_ohlcv for select using (true);

-- ============================================================
-- OPTIONAL — nightly auto-refresh of the views at 15:05 BST
-- ============================================================
-- First enable pg_cron: Dashboard → Database → Extensions → pg_cron
-- Then uncomment and run:
--
-- select cron.schedule('refresh-mvs', '5 9 * * *', $$
--   refresh materialized view concurrently mv_symbols;
--   refresh materialized view concurrently mv_daily_summary;
-- $$);
--
-- To refresh manually at any time:
--   refresh materialized view concurrently mv_symbols;
--   refresh materialized view concurrently mv_daily_summary;
