import { Composition } from 'remotion';
import { TomateAssemble } from './TomateAssemble';
import { TomateIntro } from './TomateIntro';

const VIDEO = { width: 1920, height: 1080, fps: 30 };

// Each animation settles by frame 90 (the flicker on 84, the assemble on 90); the rest
// holds the logo before the cut.
export const Root = () => (
  <>
    <Composition id="TomateIntro" component={TomateIntro} {...VIDEO} durationInFrames={120} />
    <Composition id="TomateAssemble" component={TomateAssemble} {...VIDEO} durationInFrames={120} />
  </>
);
