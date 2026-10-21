# Bongotrader

DSE trading & backtesting terminal.

## Setup

1. Fill `.env.local` with your Supabase keys (rotate the service_role key first!).
2. Run `sql/schema.sql` in Supabase SQL editor.
3. `npm install && npm run dev`
4. Open http://localhost:3000

## Routes

- `/chart` — candlestick chart + drawing tools
- `/backtest` — strategy builder + replay engine
- `/account` — portfolio (stub)
