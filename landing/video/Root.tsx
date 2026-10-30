import { Composition } from 'remotion';
import { TomateIntro } from './TomateIntro';

// The flicker resolves on frame 84; the rest holds the logo before the cut.
export const Root = () => (
  <Composition id="TomateIntro" component={TomateIntro} width={1920} height={1080} fps={30} durationInFrames={120} />
);
