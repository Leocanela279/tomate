import { loadFont } from '@remotion/fonts';
import { LogoFlicker } from '@/components/snap-cn/logo-flicker';
import cormorant from '@fontsource-variable/cormorant-garamond/files/cormorant-garamond-latin-wght-normal.woff2';

// The site's display face, from the same package the site loads it from.
loadFont({ family: 'Cormorant Garamond', url: cormorant, weight: '300 700' });

// The six window captures, alternating looks. Six, not seven: the flicker hops
// through the pool with a stride of 7, which would stick on one image with seven.
const SHOTS = ['timer', 'schedule', 'history'].flatMap((id) => [
  `/media/${id}-tomato.webp`,
  `/media/${id}-dark.webp`,
]);

export const TomateIntro = () => (
  <LogoFlicker
    logoSrc="/icon.png"
    brandName="Tomate"
    images={SHOTS}
    fontFamily="'Cormorant Garamond', Georgia, serif"
    theme={{ background: '#6e0a0f', foreground: '#fff1ec' }}
  />
);
