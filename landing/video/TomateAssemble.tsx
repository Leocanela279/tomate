import { LogoAssemble } from '@/components/snap-cn/logo-assemble';
import { BRAND, SHOTS } from './brand';

export const TomateAssemble = () => (
  <LogoAssemble {...BRAND} images={SHOTS} middleText={'Estudia en pomodoros\nde hasta 90 minutos'} />
);
