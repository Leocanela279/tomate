import { loadFont } from '@remotion/fonts';
import cormorant from '@fontsource-variable/cormorant-garamond/files/cormorant-garamond-latin-wght-normal.woff2';

// The site's display face, from the same package the site loads it from.
loadFont({ family: 'Cormorant Garamond', url: cormorant, weight: '300 700' });

export const BRAND = {
  logoSrc: '/icon.png',
  brandName: 'Tomate',
  fontFamily: "'Cormorant Garamond', Georgia, serif",
  theme: { background: '#6e0a0f', foreground: '#fff1ec' },
};

// The six window captures, alternating looks. Six, not seven: the flicker hops
// through the pool with a stride of 7, which would stick on one image with seven.
export const SHOTS = ['timer', 'schedule', 'history'].flatMap((id) => [
  `/media/${id}-tomato.webp`,
  `/media/${id}-dark.webp`,
]);
