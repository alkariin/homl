// Renders the launcher-icon and native-splash PNGs from the canonical logo
// (assets/images/logo.svg). Run `npm install && node generate.mjs` from this
// directory; outputs land in out/ and are committed (the platform icon and
// splash generators read them from there).
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, 'out');
mkdirSync(outDir, { recursive: true });

// The logo viewBox is 0 0 91 80. The hash's extremities sit near the edge
// midpoints, so its circumradius around the viewBox center (45.5, 40) is
// ~40.9 units — that is what must fit inside the circular safe zones below.
const LOGO_W = 91;
const LOGO_H = 80;
const logoSvg = readFileSync(join(here, '../../assets/images/logo.svg'), 'utf8');
const logoPaths = logoSvg
  .split('\n')
  .filter((line) => line.trim().startsWith('<path'))
  .join('\n');
const blackPaths = logoPaths.replaceAll('fill="#D3A934"', 'fill="black"');

/** Composes an SVG canvas with the logo paths centered at the given width. */
function compose({ canvas, logoWidth, paths, background }) {
  const scale = logoWidth / LOGO_W;
  const tx = (canvas - logoWidth) / 2;
  const ty = (canvas - LOGO_H * scale) / 2;
  const rect = background
    ? `<rect width="${canvas}" height="${canvas}" fill="${background}"/>`
    : '';
  return `<svg width="${canvas}" height="${canvas}" viewBox="0 0 ${canvas} ${canvas}" fill="none" xmlns="http://www.w3.org/2000/svg">
${rect}
<g transform="translate(${tx} ${ty}) scale(${scale})">
${paths}
</g>
</svg>`;
}

function render(name, svg, width) {
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: width } }).render();
  writeFileSync(join(outDir, name), png.asPng());
  console.log(`out/${name} (${width}px)`);
}

// Launcher icon: two-tone hash on white, ~62% width for breathing room.
render('icon-1024.png', compose({ canvas: 1024, logoWidth: 640, paths: logoPaths, background: '#FFFFFF' }), 1024);

// Android adaptive foreground: transparent, hash inside the 66/108 safe-zone
// circle (diameter ~626px on a 1024 canvas → circumradius caps width at ~690).
render('icon-foreground-1024.png', compose({ canvas: 1024, logoWidth: 690, paths: logoPaths }), 1024);

// Android 13+ themed icon: same layout, all strokes black.
render('icon-monochrome-1024.png', compose({ canvas: 1024, logoWidth: 690, paths: blackPaths }), 1024);

// Native splash: all-black hash on transparent. 480px = 120dp at 4x, matching
// the 120-logical-px logo on the Flutter splash for a seamless hand-off.
render('splash-logo-black.png', `<svg width="${LOGO_W}" height="${LOGO_H}" viewBox="0 0 ${LOGO_W} ${LOGO_H}" fill="none" xmlns="http://www.w3.org/2000/svg">\n${blackPaths}\n</svg>`, 480);

// Android 12+ splash icon: 1152×1152 with the hash inside the system's
// 768px-diameter circular mask (circumradius caps width at ~848).
render('splash-logo-black-a12.png', compose({ canvas: 1152, logoWidth: 848, paths: blackPaths }), 1152);
