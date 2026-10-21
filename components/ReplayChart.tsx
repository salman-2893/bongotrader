'use client';
import { useEffect, useRef } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType, SeriesMarker, Time } from 'lightweight-charts';
import { useAppStore } from '@/store/useAppStore';

interface Props {
  bars: { time: number; open: number; high: number; low: number; close: number }[];
  cursor: number;
  markers: { time: number; side: 'BUY' | 'SELL'; text: string }[];
}

export default function ReplayChart({ bars, cursor, markers }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const seriesRef = useRef<ISeriesApi<'Candlestick'> | null>(null);
  const theme = useAppStore((s) => s.theme);

  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: {
        background: { type: ColorType.Solid, color: 'transparent' },
        textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540',
        fontFamily: 'ui-sans-serif',
      },
      grid: {
        vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
        horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 3, barSpacing: 6 },
      autoSize: true,
    });
    const series = chart.addCandlestickSeries({
      upColor: '#16A34A', downColor: '#DC2626',
      wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false,
    });
    chartRef.current = chart; seriesRef.current = series;
    return () => { chart.remove(); };
  }, []);

  useEffect(() => {
    if (!seriesRef.current) return;
    const visible = bars.slice(0, cursor + 1).map((b) => ({
      time: b.time as Time, open: b.open, high: b.high, low: b.low, close: b.close,
    }));
    seriesRef.current.setData(visible);
    const ms: SeriesMarker<Time>[] = markers.map((m) => ({
      time: m.time as Time,
      position: m.side === 'BUY' ? 'belowBar' : 'aboveBar',
      color: m.side === 'BUY' ? '#16A34A' : '#DC2626',
      shape: m.side === 'BUY' ? 'arrowUp' : 'arrowDown',
      text: m.text,
    }));
    seriesRef.current.setMarkers(ms);
  }, [bars, cursor, markers]);

  useEffect(() => {
    chartRef.current?.applyOptions({
      layout: { textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540' },
    });
  }, [theme]);

  return <div ref={containerRef} className="w-full h-[380px]" />;
}
