'use client';
import type { IChartApi, ISeriesApi } from 'lightweight-charts';

export const chartRefs: {
  chart: IChartApi | null;
  series: ISeriesApi<'Candlestick'> | null;
} = { chart: null, series: null };
