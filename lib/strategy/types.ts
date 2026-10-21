export type Operand =
  | { kind: 'price'; field: 'open' | 'high' | 'low' | 'close' }
  | { kind: 'indicator'; name: 'SMA' | 'EMA' | 'WMA' | 'RSI' | 'BB_upper' | 'BB_mid' | 'BB_lower'; period: number; stdDev?: number }
  | { kind: 'volume' }
  | { kind: 'constant'; value: number };

export type Comparator = 'crossesAbove' | 'crossesBelow' | '>' | '<' | '>=' | '<=';

export interface Condition {
  id: string;
  left: Operand;
  op: Comparator;
  right: Operand;
}

export interface ConditionGroup {
  op: 'AND' | 'OR';
  conditions: Condition[];
}

export interface Strategy {
  id: string;
  name: string;
  buy: ConditionGroup;
  sell: ConditionGroup;
  capital: number;
  sizing: { type: 'pct' | 'fixedBDT' | 'shares'; value: number };
  feePct: number;
  stopLoss?: number;
  takeProfit?: number;
}

export interface Trade {
  id: string;
  strategy: string;
  symbol: string;
  side: 'BUY' | 'SELL';
  trigger: string;
  qty: number;
  price: number;
  fee: number;
  pnl?: number;
  pnlPct?: number;
  time: number;
  exitTime?: number;
  exitPrice?: number;
}
