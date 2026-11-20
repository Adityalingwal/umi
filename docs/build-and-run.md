# Build and run

How to set up a Mac for Umi, then build, sign, run and check the app.

## Set up a fresh Mac

1. Install Xcode and select it:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

2. Have one Apple Development certificate in the login keychain. Xcode creates it in Settings > Accounts > Manage Certificates.
3. Install Apple's WWDR G3 intermediate certificate ("Worldwide Developer Relations - G3" on https://www.apple.com/certificateauthority/) by opening the downloaded file. Without it the identity is not trusted.
4. Check that the identity is valid. Do not paste this output anywhere; it holds the account's details.

   ```sh
   security find-identity -v -p codesigning
   ```

5. Install SwiftLint:

   ```sh
   brew install swiftlint
   ```

6. Create `Local.xcconfig` in the main checkout. It is git-ignored and holds the Team ID, which never goes into a commit. This writes the Team ID from the certificate into the file without printing it:

   ```sh
   team=$(security find-certificate -c "Apple Development" -p \
     | openssl x509 -noout -subject -nameopt multiline \
     | awk -F'= ' '/organizationalUnitName/ {print $2}' | tr -d ' ')
   printf 'DEVELOPMENT_TEAM = %s\n' "$team" > Local.xcconfig
   unset team
   ```

   `Local.xcconfig.example` shows the format.

7. Put the Deepgram key in `.env` in the main checkout, as one line `DEEPGRAM_API_KEY=<key>`. The file is git-ignored. Without it the app still builds; it only cannot hear questions.

A worktree links to the main checkout's files instead of copying them:

```sh
ln -s <main checkout>/Local.xcconfig Local.xcconfig
ln -s <main checkout>/.env .env
```

8. Install Claude Code (`claude`, version 2.1.328 or newer) and sign it in once with `claude auth login`. Umi answers through it on the user's own Claude subscription.

## Build

```sh
xcodebuild -project Umi.xcodeproj -scheme Umi -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath build build
```

Build output stays in `build/` inside the checkout. The Debug build is `Umi Dev` (`io.github.adityalingwal.umi.dev`); `-configuration Release` builds `Umi` (`io.github.adityalingwal.umi`).

Every build is signed with the Apple Development identity and the Team ID from `Local.xcconfig`, with Hardened Runtime on. A stable signature keeps macOS permissions across rebuilds. To see the signature:

```sh
codesign -dvv "build/Build/Products/Debug/Umi Dev.app"
```

The `Authority` and `TeamIdentifier` lines hold the account's details; leave them out of anything you share.

The build's "Write Keys" step copies `DEEPGRAM_API_KEY` from `.env` into `Contents/Resources/Keys.plist` inside the built app, so a built app holds the key in plain text: never share a build. The step never prints the key.

## Run

```sh
open "build/Build/Products/Debug/Umi Dev.app"
```

The app's icon is the `waveform` symbol in the menu bar; clicking it opens the menu. The Debug build also has a Dock icon, which opens the same menu, so computer use can find the app. The Release build lives only in the menu bar.

Launch only the `Umi Dev` build from your own checkout.

The Debug build takes these launch arguments:

- `-UmiAudioFile <path>` plays the file into the menu's level bar instead of the microphone.
- `-UmiHoldFile <path>` plays the file as one question: the hold starts when the app launches and ends when the file ends.
- `-UmiScreenImage <path>` sends that image to Claude instead of a picture of the screen, so a proof never carries the real screen.
- `-UmiFailFlux YES` opens no Flux socket, so every hold takes the fallback: the whole recording goes to Deepgram Nova-3 after release. Nothing about the network changes.

```sh
open "build/Build/Products/Debug/Umi Dev.app" --args -UmiHoldFile "$PWD/question.wav" -UmiScreenImage "$PWD/screen.jpg"
```

Read the app's log with `/usr/bin/log show --last 1m --style compact --predicate 'subsystem == "io.github.adityalingwal.umi.dev"'`.

## Check

```sh
./scripts/check
```

It runs every local check and stops at the first failure:

1. The Team ID from `Local.xcconfig` appears in no tracked file.
2. No `swiftlint:disable` in any tracked Swift file.
3. SwiftLint with `--strict` (rules in `.swiftlint.yml`).
4. The Debug build.
5. The tests (`xcodebuild test`).
