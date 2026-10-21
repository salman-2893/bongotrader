const OPEN_MIN = 10 * 60;
const CLOSE_MIN = 14 * 60 + 30;

export function nextDseEvent(now = new Date()) {
  const bstMs = now.getTime() + 6 * 60 * 60 * 1000;
  const d = new Date(bstMs);
  const dow = d.getUTCDay();
  const mins = d.getUTCHours() * 60 + d.getUTCMinutes() + d.getUTCSeconds() / 60;
  const tradingDay = dow >= 0 && dow <= 4;

  if (tradingDay && mins < OPEN_MIN) {
    return { label: 'OPEN' as const, targetMs: bstMs + (OPEN_MIN - mins) * 60000 };
  }
  if (tradingDay && mins >= OPEN_MIN && mins < CLOSE_MIN) {
    return { label: 'CLOSE' as const, targetMs: bstMs + (CLOSE_MIN - mins) * 60000 };
  }
  let add = 1;
  while (true) {
    const n = new Date(bstMs + add * 86400000);
    const nd = n.getUTCDay();
    if (nd >= 0 && nd <= 4) {
      return { label: 'OPEN' as const, targetMs: n.getTime() + OPEN_MIN * 60000 };
    }
    add++;
  }
}

export function fmtCountdown(ms: number) {
  if (ms <= 0) return '00d 00h 00m 00s';
  const s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  return `${String(d).padStart(2,'0')}d ${String(h).padStart(2,'0')}h ${String(m).padStart(2,'0')}m ${String(ss).padStart(2,'0')}s`;
}
