import { Condition, ConditionGroup, Operand, Strategy, Trade } from './types';
import { bollinger, ema, rsi, sma, wma } from './indicators';

export interface Bar { time: number; open: number; high: number; low: number; close: number; volume: number; }

function seriesFor(op: Operand, bars: Bar[]): (number | null)[] {
  const closes = bars.map((b) => b.close);
  if (op.kind === 'price') return bars.map((b) => b[op.field]);
  if (op.kind === 'volume') return bars.map((b) => b.volume);
  if (op.kind === 'constant') return bars.map(() => op.value);
  switch (op.name) {
    case 'SMA': return sma(closes, op.period);
    case 'EMA': return ema(closes, op.period);
    case 'WMA': return wma(closes, op.period);
    case 'RSI': return rsi(closes, op.period);
    case 'BB_upper': return bollinger(closes, op.period, op.stdDev ?? 2).upper;
    case 'BB_mid': return bollinger(closes, op.period, op.stdDev ?? 2).mid;
    case 'BB_lower': return bollinger(closes, op.period, op.stdDev ?? 2).lower;
    default: return new Array(bars.length).fill(null);
  }
}

function operandLabel(op: Operand): string {
  if (op.kind === 'price') return `Price(${op.field})`;
  if (op.kind === 'volume') return 'Volume';
  if (op.kind === 'constant') return `${op.value}`;
  return `${op.name}(${op.period})`;
}

export function conditionLabel(c: Condition): string {
  const opSym = { crossesAbove: 'crossed above', crossesBelow: 'crossed below', '>': '>', '<': '<', '>=': '≥', '<=': '≤' }[c.op];
  return `${operandLabel(c.left)} ${opSym} ${operandLabel(c.right)}`;
}

export function evaluateStrategy(strategy: Strategy, symbol: string, bars: Bar[]): { trades: Trade[]; equity: number[] } {
  const cache = new Map<string, (number | null)[]>();
  const getSeries = (op: Operand) => {
    const key = JSON.stringify(op);
    if (!cache.has(key)) cache.set(key, seriesFor(op, bars));
    return cache.get(key)!;
  };

  const evalCond = (c: Condition, i: number): boolean => {
    if (i < 1) return false;
    const L = getSeries(c.left), R = getSeries(c.right);
    const l0 = L[i], l1 = L[i - 1], r0 = R[i], r1 = R[i - 1];
    if (l0 == null || l1 == null || r0 == null || r1 == null) return false;
    switch (c.op) {
      case 'crossesAbove': return l1 <= r1 && l0 > r0;
      case 'crossesBelow': return l1 >= r1 && l0 < r0;
      case '>': return l0 > r0;
      case '<': return l0 < r0;
      case '>=': return l0 >= r0;
      case '<=': return l0 <= r0;
    }
  };

  const evalGroup = (g: ConditionGroup, i: number): boolean => {
    if (!g.conditions.length) return false;
    return g.op === 'AND' ? g.conditions.every((c) => evalCond(c, i)) : g.conditions.some((c) => evalCond(c, i));
  };

  const trades: Trade[] = [];
  const equity: number[] = [];
  let cash = strategy.capital;
  let qty = 0;
  let entryPrice = 0, entryTime = 0, entryFee = 0;
  const fee = (amt: number) => amt * (strategy.feePct / 100);

  for (let i = 0; i < bars.length; i++) {
    const b = bars[i];
    const inPos = qty > 0;

    if (inPos && strategy.stopLoss != null && b.low <= entryPrice * (1 - strategy.stopLoss / 100)) {
      const exit = entryPrice * (1 - strategy.stopLoss / 100);
      cash += qty * exit; const f = fee(qty * exit); cash -= f;
      const pnl = qty * (exit - entryPrice) - f - entryFee;
      trades.push({
        id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'SELL',
        trigger: `Stop-loss at ${strategy.stopLoss}%`, qty, price: exit, fee: f,
        pnl, pnlPct: (pnl / (qty * entryPrice)) * 100, time: entryTime,
        exitTime: b.time, exitPrice: exit,
      });
      qty = 0;
    } else if (inPos && strategy.takeProfit != null && b.high >= entryPrice * (1 + strategy.takeProfit / 100)) {
      const exit = entryPrice * (1 + strategy.takeProfit / 100);
      cash += qty * exit; const f = fee(qty * exit); cash -= f;
      const pnl = qty * (exit - entryPrice) - f - entryFee;
      trades.push({
        id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'SELL',
        trigger: `Take-profit at ${strategy.takeProfit}%`, qty, price: exit, fee: f,
        pnl, pnlPct: (pnl / (qty * entryPrice)) * 100, time: entryTime,
        exitTime: b.time, exitPrice: exit,
      });
      qty = 0;
    }

    if (!inPos && evalGroup(strategy.buy, i)) {
      const budget = strategy.sizing.type === 'pct' ? cash * (strategy.sizing.value / 100)
                   : strategy.sizing.type === 'fixedBDT' ? Math.min(cash, strategy.sizing.value)
                   : Math.min(cash, b.close * strategy.sizing.value);
      const buyQty = Math.floor(budget / b.close);
      if (buyQty > 0) {
        qty = buyQty;
        entryPrice = b.close;
        entryTime = b.time;
        entryFee = fee(qty * b.close);
        cash -= qty * b.close + entryFee;
        trades.push({
          id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'BUY',
          trigger: strategy.buy.conditions.map(conditionLabel).join(` ${strategy.buy.op} `),
          qty, price: b.close, fee: entryFee, time: b.time,
        });
      }
    } else if (inPos && evalGroup(strategy.sell, i)) {
      const exit = b.close;
      cash += qty * exit;
      const f = fee(qty * exit); cash -= f;
      const pnl = qty * (exit - entryPrice) - f - entryFee;
      trades.push({
        id: `t${trades.length}`, strategy: strategy.name, symbol, side: 'SELL',
        trigger: strategy.sell.conditions.map(conditionLabel).join(` ${strategy.sell.op} `),
        qty, price: exit, fee: f, pnl, pnlPct: (pnl / (qty * entryPrice)) * 100,
        time: entryTime, exitTime: b.time, exitPrice: exit,
      });
      qty = 0;
    }

    equity.push(cash + qty * b.close);
  }
  return { trades, equity };
}
