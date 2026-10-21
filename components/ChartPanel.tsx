'use client';
import { useEffect, useRef, useState } from 'react';
import { createChart, IChartApi, ISeriesApi, ColorType, MouseEventParams } from 'lightweight-charts';
import { useQuery } from '@tanstack/react-query';
import { useAppStore } from '@/store/useAppStore';
import { chartRefs } from '@/lib/chartInstance';
import DrawingCanvas from './DrawingCanvas';
import { calcIndicator, INDICATOR_DEFS } from '@/lib/indicators/engine';

export default function ChartPanel() {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const mainSeriesRef = useRef<ISeriesApi<any> | null>(null);
  const indSeriesRef = useRef<ISeriesApi<any>[]>([]);
  const [hoverData, setHoverData] = useState<any>(null);
  
  const { activeSymbol: symbol, timeframe: tf, theme, chartType, indicators } = useAppStore();

  const { data, isLoading, error } = useQuery({
    queryKey: ['ohlcv', symbol, tf],
    queryFn: async () => {
      const r = await fetch(`/api/ohlcv?symbol=${symbol}&tf=${tf}&limit=500`);
      if (!r.ok) throw new Error('failed');
      const j = await r.json();
      const raw = (j.data as any[]) || [];
      const parsed = raw.map((d) => {
        const t = new Date(d.date).getTime();
        return { time: Math.floor(t / 1000) as any, open: Number(d.open), high: Number(d.high), low: Number(d.low), close: Number(d.close), volume: Number(d.volume || 0), value: Number(d.close) };
      }).filter((d) => !isNaN(d.time));
      const uniqueMap = new Map();
      parsed.forEach((item) => uniqueMap.set(item.time, item));
      return Array.from(uniqueMap.values()).sort((a, b) => a.time - b.time);
    },
  });

  useEffect(() => {
    if (!containerRef.current) return;
    const chart = createChart(containerRef.current, {
      layout: { background: { type: ColorType.Solid, color: 'transparent' }, textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540', fontFamily: 'ui-sans-serif' },
      grid: { vertLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' }, horzLines: { color: theme === 'dark' ? '#1E2A44' : '#BFD9FF' } },
      rightPriceScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF' },
      timeScale: { borderColor: theme === 'dark' ? '#1E2A44' : '#BFD9FF', rightOffset: 5, barSpacing: 8 },
      autoSize: true,
      crosshair: { mode: 0, vertLine: { visible: true, labelVisible: true }, horzLine: { visible: true } }
    });
    
    chart.subscribeCrosshairMove((param: MouseEventParams) => {
      if (param.point === undefined || !param.time || param.point.x < 0 || param.point.y < 0) setHoverData(null);
      else if (param.seriesData.size > 0) {
        const data = param.seriesData.get(mainSeriesRef.current!) as any;
        if (data) setHoverData(data);
      }
    });

    chartRef.current = chart;
    chartRefs.chart = chart;
    return () => { chart.remove(); chartRefs.chart = null; chartRefs.series = null; };
  }, []);

  useEffect(() => {
    if (!chartRef.current || !data) return;
    const chart = chartRef.current;
    
    if (mainSeriesRef.current) chart.removeSeries(mainSeriesRef.current);
    indSeriesRef.current.forEach(s => chart.removeSeries(s));
    indSeriesRef.current = [];

    const opts = { upColor: '#16A34A', downColor: '#DC2626', wickUpColor: '#16A34A', wickDownColor: '#DC2626', borderVisible: false };
    let series;
    if (chartType === 'line') series = chart.addLineSeries({ color: '#1E6FD9', lineWidth: 2 });
    else if (chartType === 'area') series = chart.addAreaSeries({ lineColor: '#1E6FD9', topColor: 'rgba(30,111,217,0.4)', bottomColor: 'rgba(30,111,217,0.0)' });
    else if (chartType === 'bar') series = chart.addBarSeries({ upColor: '#16A34A', downColor: '#DC2626' });
    else series = chart.addCandlestickSeries(opts);

    series.setData(data);
    mainSeriesRef.current = series;
    chartRefs.series = series as any;

    indicators.forEach(ind => {
      const values = calcIndicator(data, ind.type, ind.period);
      const def = INDICATOR_DEFS.find(d => d.type === ind.type);
      if (!def || !values) return;
      const priceScaleId = def.isOscillator ? `osc_${ind.id}` : 'right';
      const scaleMargins = def.isOscillator ? { top: 0.7, bottom: 0 } : undefined;

      if (ind.type === 'BB' && (values as any).upper) {
        const v = values as any;
        const bbU = chart.addLineSeries({ color: ind.color, lineWidth: 1, priceScaleId });
        bbU.setData(data.map((d, i) => ({ time: d.time, value: v.upper[i] })).filter(d => d.value != null));
        const bbL = chart.addLineSeries({ color: ind.color, lineWidth: 1, priceScaleId });
        bbL.setData(data.map((d, i) => ({ time: d.time, value: v.lower[i] })).filter(d => d.value != null));
        indSeriesRef.current.push(bbU, bbL);
      } else {
        const s = chart.addLineSeries({ color: ind.color, lineWidth: 2, priceScaleId });
        if (scaleMargins) s.priceScale().applyOptions({ scaleMargins });
        s.setData(data.map((d, i) => ({ time: d.time, value: (values as any[])[i] })).filter(d => d.value != null));
        indSeriesRef.current.push(s);
      }
    });

    chart.timeScale().scrollToRealTime();
  }, [data, chartType, indicators]);

  useEffect(() => {
    chartRef.current?.applyOptions({ layout: { textColor: theme === 'dark' ? '#E6EDF7' : '#0A2540' } });
  }, [theme]);

  return (
    <div className="chart-pane w-full h-full"> {/* CHANGED TO h-full */}
      {hoverData && (
        <div className="absolute top-2 left-2 z-20 flex gap-3 text-[10px] font-mono bg-[color:var(--bg)]/80 px-2 py-1 rounded backdrop-blur border border-[color:var(--border)]">
          <span className="text-[color:var(--muted)]">O <span className={hoverData.close >= hoverData.open ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{hoverData.open.toFixed(2)}</span></span>
          <span className="text-[color:var(--muted)]">H <span className="text-[color:var(--bull)]">{hoverData.high.toFixed(2)}</span></span>
          <span className="text-[color:var(--muted)]">L <span className="text-[color:var(--bear)]">{hoverData.low.toFixed(2)}</span></span>
          <span className="text-[color:var(--muted)]">C <span className={hoverData.close >= hoverData.open ? 'text-[color:var(--bull)]' : 'text-[color:var(--bear)]'}>{hoverData.close.toFixed(2)}</span></span>
        </div>
      )}
      <div ref={containerRef} className="w-full h-full" />
      <DrawingCanvas />
    </div>
  );
}
