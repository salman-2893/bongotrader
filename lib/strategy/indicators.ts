export function sma(v: number[], p: number): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  let sum = 0;
  for (let i = 0; i < v.length; i++) {
    sum += v[i];
    if (i >= p) sum -= v[i - p];
    if (i >= p - 1) out[i] = sum / p;
  }
  return out;
}

export function ema(v: number[], p: number): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  const k = 2 / (p + 1);
  let prev: number | null = null;
  for (let i = 0; i < v.length; i++) {
    if (i === p - 1) {
      let s = 0; for (let j = 0; j < p; j++) s += v[j];
      prev = s / p; out[i] = prev;
    } else if (prev !== null) {
      prev = v[i] * k + prev * (1 - k); out[i] = prev;
    }
  }
  return out;
}

export function wma(v: number[], p: number): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  const denom = (p * (p + 1)) / 2;
  for (let i = p - 1; i < v.length; i++) {
    let s = 0;
    for (let j = 0; j < p; j++) s += v[i - p + 1 + j] * (j + 1);
    out[i] = s / denom;
  }
  return out;
}

export function rsi(v: number[], p = 14): (number | null)[] {
  const out: (number | null)[] = new Array(v.length).fill(null);
  if (v.length <= p) return out;
  let gain = 0, loss = 0;
  for (let i = 1; i <= p; i++) {
    const d = v[i] - v[i - 1];
    if (d >= 0) gain += d; else loss -= d;
  }
  let ag = gain / p, al = loss / p;
  out[p] = 100 - 100 / (1 + ag / (al || 1e-9));
  for (let i = p + 1; i < v.length; i++) {
    const d = v[i] - v[i - 1];
    const g = d > 0 ? d : 0, l = d < 0 ? -d : 0;
    ag = (ag * (p - 1) + g) / p; al = (al * (p - 1) + l) / p;
    out[i] = 100 - 100 / (1 + ag / (al || 1e-9));
  }
  return out;
}

export function bollinger(v: number[], p = 20, k = 2) {
  const mid = sma(v, p);
  const upper: (number | null)[] = new Array(v.length).fill(null);
  const lower: (number | null)[] = new Array(v.length).fill(null);
  for (let i = p - 1; i < v.length; i++) {
    let s = 0;
    for (let j = i - p + 1; j <= i; j++) s += (v[j] - (mid[i] ?? 0)) ** 2;
    const sd = Math.sqrt(s / p);
    upper[i] = (mid[i] ?? 0) + k * sd;
    lower[i] = (mid[i] ?? 0) - k * sd;
  }
  return { upper, mid, lower };
}
