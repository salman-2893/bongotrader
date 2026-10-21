import * as ti from 'technicalindicators';

export const INDICATOR_DEFS = [
  { type: 'SMA', name: 'Simple Moving Average', defaultPeriod: 20, isOscillator: false, color: '#F59E0B' },
  { type: 'EMA', name: 'Exponential Moving Average', defaultPeriod: 20, isOscillator: false, color: '#8B5CF6' },
  { type: 'WMA', name: 'Weighted Moving Average', defaultPeriod: 20, isOscillator: false, color: '#EC4899' },
  { type: 'BB', name: 'Bollinger Bands', defaultPeriod: 20, isOscillator: false, color: '#3B82F6' },
  { type: 'RSI', name: 'Relative Strength Index', defaultPeriod: 14, isOscillator: true, color: '#06B6D4' },
  { type: 'MACD', name: 'MACD', defaultPeriod: 26, isOscillator: true, color: '#10B981' },
  { type: 'OBV', name: 'On Balance Volume', defaultPeriod: 0, isOscillator: true, color: '#F43F5E' },
  { type: 'STOCH', name: 'Stochastic', defaultPeriod: 14, isOscillator: true, color: '#D946EF' },
  { type: 'ADX', name: 'ADX', defaultPeriod: 14, isOscillator: true, color: '#64748B' },
  { type: 'ATR', name: 'Average True Range', defaultPeriod: 14, isOscillator: true, color: '#EAB308' },
  { type: 'CCI', name: 'Commodity Channel Index', defaultPeriod: 20, isOscillator: true, color: '#14B8A6' },
  { type: 'MFI', name: 'Money Flow Index', defaultPeriod: 14, isOscillator: true, color: '#F97316' },
];

export function calcIndicator(candles: any[], type: string, period: number) {
  const c = candles.map(x => x.close);
  const h = candles.map(x => x.high);
  const l = candles.map(x => x.low);
  const o = candles.map(x => x.open);
  const v = candles.map(x => x.volume || 0);
  
  let res: any[] = [];
  try {
    switch(type) {
      case 'SMA': res = ti.sma({ period, values: c }); break;
      case 'EMA': res = ti.ema({ period, values: c }); break;
      case 'WMA': res = ti.wma({ period, values: c }); break;
      case 'RSI': res = ti.rsi({ period, values: c }); break;
      case 'BB': 
        const bb = ti.bollingerbands({ period, stdDev: 2, values: c });
        return { upper: pad(bb.map(b=>b.upper), candles.length), mid: pad(bb.map(b=>b.middle), candles.length), lower: pad(bb.map(b=>b.lower), candles.length) };
      case 'MACD': res = ti.macd({ values: c, fastPeriod: 12, slowPeriod: 26, signalPeriod: 9 }).map(m => m.histogram); break;
      case 'OBV': res = ti.obv({ close: c, volume: v }); break;
      case 'STOCH': res = ti.stochastic({ high: h, low: l, close: c, period, signalPeriod: 3 }).map(s => s.k); break;
      case 'ADX': res = ti.adx({ high: h, low: l, close: c, period }).map(a => a.adx); break;
      case 'ATR': res = ti.atr({ high: h, low: l, close: c, period }); break;
      case 'CCI': res = ti.cci({ high: h, low: l, close: c, period }); break;
      case 'MFI': res = ti.mfi({ high: h, low: l, close: c, volume: v, period }); break;
      default: res = [];
    }
  } catch (e) { console.error(e); return []; }
  
  return pad(res, candles.length);
}

function pad(arr: any[], len: number) {
  if (arr.length >= len) return arr.slice(-len);
  return Array(len - arr.length).fill(null).concat(arr);
}
