'use client';
import { useAppStore } from '@/store/useAppStore';
export default function LanguageToggle() {
  const { lang, setLang } = useAppStore();
  return (
    <button onClick={() => setLang(lang === 'en' ? 'bn' : 'en')}
      className="px-2 py-1 text-xs rounded-lg border border-[color:var(--border)] font-medium">
      {lang === 'en' ? 'বাংলা' : 'EN'}
    </button>
  );
}
