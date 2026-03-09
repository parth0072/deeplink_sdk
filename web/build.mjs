import * as esbuild from 'esbuild';

// ESM bundle
await esbuild.build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  format: 'esm',
  outfile: 'dist/deeplink.esm.js',
  target: 'es2017',
  sourcemap: true,
});

// CJS bundle
await esbuild.build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  format: 'cjs',
  outfile: 'dist/deeplink.cjs.js',
  target: 'es2017',
  sourcemap: true,
});

// UMD/IIFE for CDN — exposes `Deeplink` global
await esbuild.build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  format: 'iife',
  globalName: 'DeeplinkSDK',
  outfile: 'dist/deeplink.min.js',
  target: 'es2017',
  minify: true,
  // Expose `Deeplink` as a global for <script> tag usage
  banner: {
    js: '/* Deeplink Web SDK v1.0.0 | MIT */',
  },
  footer: {
    js: 'if(typeof window!=="undefined"){window.Deeplink=DeeplinkSDK.Deeplink||DeeplinkSDK.default;}',
  },
});

console.log('Web SDK built successfully.');
