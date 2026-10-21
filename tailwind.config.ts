import type { Config } from 'tailwindcss';
const config: Config = {
  content: ['./app/**/*.{ts,tsx}','./components/**/*.{ts,tsx}'],
  darkMode: ['class','[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        bg: 'var(--bg)', panel: 'var(--panel)', border: 'var(--border)',
        text: 'var(--text)', muted: 'var(--muted)', accent: 'var(--accent)',
        bull: 'var(--bull)', bear: 'var(--bear)',
      },
    },
  },
  plugins: [],
};
export default config;
