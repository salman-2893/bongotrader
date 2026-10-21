'use client';
import { Moon, Sun } from 'lucide-react';
import { useAppStore } from '@/store/useAppStore';
export default function ThemeToggle() {
  const { theme, toggleTheme } = useAppStore();
  return (
    <button onClick={toggleTheme} className="p-2 rounded-lg hover:bg-[color:var(--muted)]/10" aria-label="theme">
      {theme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
    </button>
  );
}
