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
9. To answer with Codex instead, install Codex (`codex`, version 0.170.0) and sign it in with ChatGPT once with `codex login`, keeping the login in the file store (`~/.codex/auth.json`). Then pick Codex in the menu's Brain row. Each time the menu opens, the row checks both brains (`claude auth status`, `codex login status` and whether the login file exists) and greys out one that can't be used, with what to do. Umi runs Codex from its own Codex home in Application Support, which holds only a link to that login file.

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
- `-UmiHoldFile <path>` plays the file as one question: the hold starts when the app launches and ends when the file ends. To ask several questions in one launch, give a list, `-UmiHoldFile '("<first>", "<second>")'`: the files play in order, and each next hold starts 25 s after the previous one ended, so a short answer finishes first. A list needs `-UmiScreenImage` too, so that no scheduled hold sends a picture of the real screen; without it no hold plays and the log says why.
- `-UmiScreenImage <path>` sends that image to the brain instead of a picture of the screen, so a proof never carries the real screen.
- `-UmiBrainPicks '("codex", "claude")'` works with `-UmiHoldFile`: before each hold begins, the next brain in the list is chosen, the same way as picking it in the menu's Brain row (the choice is saved).
- `-UmiBrainExecutables <folder>` looks for `claude` and `codex` only in that folder, for both the Brain row's check and the answers. A missing file makes that brain look not installed; a small script in its place can print a made-up status (for example `Not logged in` on stderr for `codex login status`, or `{"loggedIn": false}` for `claude auth status`) or `exec` the real tool. Launch with `open --env CODEX_HOME=<folder>` to point Umi at another Codex home. Never sign out of the real Codex or Claude to make a state.
- `-UmiMenuUpdateEvery <seconds>` updates the menu every few seconds as if it had just opened, so the Brain row's check runs without clicking the menu. Each update logs every Brain option (chosen, enabled, hint).
- `-UmiFailFlux YES` opens no Flux socket, so every hold takes the fallback: the whole recording goes to Deepgram Nova-3 after release. Nothing about the network changes.
- `-UmiHoldPause <seconds>` works with a `-UmiHoldFile` list: each next hold starts that many seconds after the previous one ended, in place of 25 s. A short pause asks the next question while an answer (or a drawing) is still going; a long one lets a long drawing answer finish first. A list, `-UmiHoldPause '(40, 8)'`, sets the pause after each hold in order, and the last one repeats: there a first drawing finishes, then the third question interrupts the second answer.
- `-UmiCutVoiceAfter <count>` makes the voice fail on purpose once it has sent the audio of that many voice pieces in one answer, the same way a Deepgram voice error does: the answer stops as with Esc and the fail mark shows. A piece is a sentence, a drawing line, or one of Umi's own lines; a sentence that names a pointed control is two when spoken words come before the name, and one when it starts with the name. It holds for every answer of that launch, so an answer with fewer pieces is not cut.
- `-UmiSpeechFile <path>` also writes what Umi spoke to that WAV file: exactly the sound that played during that launch, every spoken line in order, each ending where a cut stopped it.

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
