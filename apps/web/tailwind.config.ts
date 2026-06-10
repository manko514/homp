import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#EFF6FF',
          600: '#1E3A8A',
          700: '#1E3A5F',
        },
      },
    },
  },
  plugins: [],
};

export default config;
