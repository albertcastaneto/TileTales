# TileTales Godot version

A Godot 4.7 port of the web game in `www/`, with the same layout and behaviour. The web version stays in `www/`.

## What matches the web version

- Top bar with the app icon, picture title, level chip and settings button
- Board drawn like the web: rounded panel, spare slot, moves/time in the top band, Goal thumbnail (tap to enlarge), accent outline
- Tap a piece to slide it, or swipe/drag it toward the gap; the held tile and the other tiles in its path move together in real time, then snap into place on release. Invalid paths are blocked with a brief shake and haptic feedback.
- Android touch events are explicitly forwarded to the Godot GUI as mouse input so board gestures and buttons share a reliable input path.
- Action bar: Pictures, Shuffle / New game, and hold-to-Peek
- Bottom-sheet Settings (show numbers, sound, vibration, photo grid size, grid-specific solving tips, privacy choices and privacy policy) and picture gallery (Original and Fairy-Tale collections, 14 categories, 42 pictures, category-specific locked levels)
- Win dialog with moves, time, unlocks and Next picture / Next level; confirmation before replacing an unfinished puzzle
- Light and dark colours follow the device setting; save and resume; Android Back closes sheets

## Files

- `scripts/main.gd`: screen layout, sheets and dialogs, game flow, save, sound and vibration
- `scripts/puzzle_board.gd`: board rules, drawing, animation and touch input
- `scripts/palette.gd`: colours (the web's CSS tokens), fonts and drawing helpers
- `assets/images/`: the gallery pictures (copied from `www/images/`; keep the two in sync)

## Open and run

1. Open `D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`.
2. In the Project Manager choose **Import**, select this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** to run.

## Ads (AdMob)

`scripts/ads.gd` shows a banner after 8 seconds without puzzle input, and a rewarded ad that unlocks the next level early
(locked pictures one level ahead show "or watch an ad"). It uses the **AdMob plugin by Poing Studios**.

- **Without the plugin, or on a PC**, ads run in preview mode: a grey "Ad banner · preview" strip and a stand-in
  rewarded ad with a 3-second countdown. Use this to test the layout and the unlock flow.
- **Debug builds always use Google's test ads**; your own ad unit IDs are used only in release exports.
  Never tap your own live ads: AdMob can suspend the account.
- The banner stays hidden while a puzzle is being played, slides up after 8 seconds without input, and hides immediately when input resumes or a sheet/dialog opens. Its space remains reserved to keep the board from jumping.
- In the EEA and UK, Google's consent form appears on first launch, and **Settings → Privacy choices** appears so players
  can change their answer.

### Current setup and next steps

- The AdMob App ID is configured in `project.godot`; the banner and rewarded unit IDs are in `scripts/ads.gd`.
- The developer has configured AdMob Privacy & messaging.
- Debug builds use Google's test ad IDs; live unit IDs are selected only for release builds. Never tap live ads while testing.
- The Poing Studios AdMob plugin v5.1.0 is installed under `addons/admob`, enabled in the project, and its Android library package for Godot 4.7.2 is installed. The plugin's iOS package was also downloaded by its installer, but TileTales is currently Android-only.
- Android export is configured in `export_presets.cfg` with package ID `com.koidafish.tiletales`. The preset targets Android 36 and supports arm64 devices. This machine has Godot 4.7.2 export templates and an Android SDK/JDK configured in Godot Editor settings.
- Android launcher icons use padded, Android-specific variants in `assets/app-icons/` so adaptive launcher masks do not crop the logo; the original `icon.webp` remains the in-game/web brand image.
- The Android system splash uses the padded TileTales mark, with the Godot boot splash disabled.
- Gallery images use ETC2 GPU texture compression and no mipmaps for Android, reducing the gallery's imported texture payload from about 127 MB to about 32 MB. Check image quality on a phone after exporting.
- Debug exports use the local debug signing key for phone testing. A Play Store release AAB requires a separate release key, which should be backed up securely.
- Export and install a **debug** build on a real phone. Verify the test banner, rewarded video earned/closed paths, consent flow, Settings → Privacy choices, and that failed/no-fill ads never grant a level.

### Before publishing on Google Play

- **Play Console → App content:** answer **Contains ads: Yes**; in **Data safety**, declare the advertising ID and the
  data the AdMob SDK collects; for **Target audience**, choose 13+ age groups (choosing under-13 brings the stricter
  Families ad rules).
- **app-ads.txt:** add your developer website in Play Console and host the `app-ads.txt` line AdMob gives you there,
  otherwise ad fill and earnings are limited.
- Export a **release** build so your real ad unit IDs are used.

## Before release

- Test phone and tablet layouts, safe areas, Android Back, system photo picker, save/resume, audio, and category-specific progression on physical devices.
- Configure a unique package identity and signing key; keep the release key backed up securely.
- Complete the Play Console store listing and its current app-content, ads, data-safety, and privacy declarations.
- Export a signed release bundle only after the debug build and internal testing are clean.

The photo picker uses the system file dialog; validate it on a real Android device.
