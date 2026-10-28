# Fixme — A sliding puzzle to slide your time

Mobile-first picture sliding puzzle. The web app lives in `www/` and is configured to share its web assets with an Android app through Capacitor. It has no online image API; its bundled WebP picture gallery works offline.

## Play locally

- Install Node.js 22 or newer.
- Run `npm install` once.
- Run `npm run dev`, then open `http://localhost:4173`.

## Android setup

- Install Android Studio and its Android SDK.
- Run `npm install`.
- Run `npm run android:add` once to create the native Android project.
- Run `npm run android:sync` after web changes.
- Run `npm run android:open` to open the project in Android Studio and build or run it on a device.

The Android SDK and Java are not included in this repository. The machine used for the initial setup did not have those tools installed, so an APK has not been built yet.

## Current features

- Mobile and tablet responsive layout, safe-area padding, and landscape layout.
- Seven offline picture categories, each with three bundled WebP images that increase in detail from Beginner to Intermediate to Advanced.
- Beginner starts unlocked; solving a puzzle at the current image tier unlocks the next tier. Unlock progress is saved locally.
- Personal photo selection, processed locally and never uploaded.
- Beginner (3×3), Intermediate (4×4), and Advanced (6×6) puzzle levels, solvable shuffle, moves, timer, number labels, and full-picture preview.
- Phone-first layout: picture title and level in the top bar, moves/time inside the board's top band, and a thumb-reach action bar (Pictures, Shuffle, hold-to-Peek).
- Tap or swipe pieces; invalid moves shake, and optional vibration gives feedback.
- Win dialog with stats and a "Next picture" / "Next level" button.
- Settings and picture gallery open as bottom sheets on phones; settings use on/off switches.
- Confirmation before replacing an unfinished puzzle.
- Automatic local save and resume, including selected custom image where browser storage allows it.
- PWA manifest and service worker for installability and offline app-shell and image use.

## Data model

- `cells[0..N*N-1]` are board positions; `cells[N*N]` is the spare slot at row -1, column 0.
- Values are piece IDs (their home cells); `-1` represents the empty slot.
- Pieces share one image using CSS background positioning.

## Next improvements

- Test on real Android phones and tablets, including narrow portrait and landscape screens.
- Generate branded PNG launcher icons and a signed release build.
- Consider IndexedDB for custom images if localStorage storage limits become a problem.
- Add one vetted online image provider later, with provider-specific attribution and storage behavior.
