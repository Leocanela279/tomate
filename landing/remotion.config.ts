// Remotion renders the intro video in video/. Its bundler doesn't read tsconfig paths,
// so the @/ alias the snapcn components import from is set here as well.
import path from 'node:path';
import { Config } from '@remotion/cli/config';

Config.setEntryPoint('video/index.ts');
Config.overrideWebpackConfig((config) => ({
  ...config,
  resolve: {
    ...config.resolve,
    alias: { ...config.resolve?.alias, '@': path.join(process.cwd(), 'src') },
  },
}));
