export type ToolId = 'select' | 'trendline' | 'hline' | 'text' | 'buy' | 'sell' | 'greenbox' | 'redbox';

export interface BaseDrawing {
  id: string;
  tool: ToolId;
  a: { time: number; price: number };
  b?: { time: number; price: number };
  text?: string;
}

export type Drawing = BaseDrawing;
