# TileTales Godot version

A Godot 4.7 port of the web game in `www/`, with the same layout and behaviour. The web version stays in `www/`.

## What matches the web version

- Top bar with the app icon, picture title, level chip and settings button
- Board drawn like the web: rounded panel, spare slot, moves/time in the top band, Goal thumbnail (tap to enlarge), accent outline
- Tap or swipe pieces; invalid moves shake; pieces animate; the picture becomes seamless when solved
- Action bar: Pictures, Shuffle / New game, and hold-to-Peek
- Bottom-sheet Settings (show numbers, sound, vibration, photo grid size) and picture gallery (Original and Fairy-Tale collections, 14 categories, 42 pictures, locked levels)
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

`scripts/ads.gd` shows a banner at the bottom of the main screen and a rewarded ad that unlocks the next level early
(locked pictures one level ahead show "or watch an ad"). It uses the **AdMob plugin by Poing Studios**.

- **Without the plugin, or on a PC**, ads run in preview mode: a grey "Ad banner · preview" strip and a stand-in
  rewarded ad with a 3-second countdown. Use this to test the layout and the unlock flow.
- **Debug builds always use Google's test ads**; your own ad unit IDs are used only in release exports.
  Never tap your own live ads: AdMob can suspend the account.
- The banner hides while a sheet or dialog is open, because native banners draw on top of the game.
- In the EEA and UK, Google's consent form appears on first launch, and **Settings → Privacy choices** appears so players
  can change their answer.

### One-time setup

1. **AdMob:** in AdMob, add the app (Android, "TileTales"), then create two ad units: **Banner** and **Rewarded**.
   Note the App ID (contains `~`) and both ad unit IDs (contain `/`).
2. **AdMob → Privacy & messaging:** create a **GDPR (European regulations)** message for the app and publish it.
3. **Install the plugin:** in Godot open the **AssetLib** tab, search `AdMob`, choose the one by **Poing Studios**, then
   **Download** and **Install**. Enable it in **Project → Project Settings → Plugins**.
4. **Android build template:** **Project → Install Android Build Template**. If the plugin's Android library didn't
   download, use **Project → Tools → AdMob Manager → Android → Download & Install**.
5. **App ID:** **Project → Project Settings → General → Admob → General**: tick **Enabled** for Android and paste the App ID.
6. **Ad unit IDs:** paste them into `BANNER_UNIT` and `REWARDED_UNIT` at the top of `scripts/ads.gd`.
7. **Export preset:** **Project → Export → Add → Android**. Tick **Use Gradle Build**, set **Min SDK** to 24 or higher and
   **Target SDK** to 35 or higher, and enable the **Vibrate** permission.
8. **Test:** export a debug build to a phone. You should see a "Test Ad" banner, and "or watch an ad" should play a test video.

### Before publishing on Google Play

- **Play Console → App content:** answer **Contains ads: Yes**; in **Data safety**, declare the advertising ID and the
  data the AdMob SDK collects; for **Target audience**, choose 13+ age groups (choosing under-13 brings the stricter
  Families ad rules).
- **app-ads.txt:** add your developer website in Play Console and host the `app-ads.txt` line AdMob gives you there,
  otherwise ad fill and earnings are limited.
- Export a **release** build so your real ad unit IDs are used.

## Android export

Install the Android SDK, JDK and export templates, then add an Android export preset (see the ads setup above for
the settings it needs). The photo picker uses the system file dialog; check it on a real device.
