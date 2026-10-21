export const bdt = (n: number) => {
  const s = new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: 2, maximumFractionDigits: 2,
  }).format(n);
  return `৳${s}`;
};
export const pct = (n: number) => `${n >= 0 ? '+' : ''}${n.toFixed(2)}%`;
export const num = (n: number) => new Intl.NumberFormat('en-IN').format(n);
export const dt = (t: number) => new Date(t * 1000).toISOString().slice(0, 10);
