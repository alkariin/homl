# App icons & native splash

All branding images are rendered from the canonical logo,
`assets/images/logo.svg`. `generate.mjs` composes the variants (white-background
launcher icon, transparent adaptive foreground, black monochrome, all-black
splash logo) and rasterizes them into `out/`, which is committed.

## Regenerate

After changing `assets/images/logo.svg`:

```bash
# 1. Re-render the source PNGs (Node ≥ 18)
cd tool/icons
npm install
npm run generate

# 2. Re-emit the platform assets (from homl-ui/)
cd ../..
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Both tools are configured in `pubspec.yaml` (`flutter_launcher_icons:` and
`flutter_native_splash:` sections).

## Outputs

| File | Used for |
| --- | --- |
| `out/icon-1024.png` | iOS / web / legacy Android icon (hash on white) |
| `out/icon-foreground-1024.png` | Android adaptive-icon foreground (transparent) |
| `out/icon-monochrome-1024.png` | Android 13+ themed icon (all black) |
| `out/splash-logo-black.png` | Native splash logo, 480 px = 120 dp @4x to match the Flutter splash |
| `out/splash-logo-black-a12.png` | Android 12+ splash icon (1152 px canvas, fits the 768 px circular mask) |

Sizing notes: the hash's extremities sit near the edge midpoints of its
viewBox, so what must fit inside the circular safe zones (adaptive icon,
Android 12 splash mask) is its circumradius (~40.9 units for a 91-unit-wide
logo) — that is what caps the logo widths hardcoded in `generate.mjs`.

The splash color `#FBFBFB` matches the app theme's `scaffoldBackgroundColor`
(`lib/helpers/colors.dart` → `background`), so the native splash hands off
seamlessly to the in-app `SplashPage`, whose logo starts fully black before
the gold reveal plays.
