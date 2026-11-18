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

A worktree links to the main checkout's file instead of copying it:

```sh
ln -s <main checkout>/Local.xcconfig Local.xcconfig
```

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

## Run

```sh
open "build/Build/Products/Debug/Umi Dev.app"
```

The app's icon is the `waveform` symbol in the menu bar; clicking it opens the menu. The Debug build also has a Dock icon, which opens the same menu, so computer use can find the app. The Release build lives only in the menu bar.

Launch only the `Umi Dev` build from your own checkout.

## Check

```sh
./scripts/check
```

It runs every local check and stops at the first failure:

1. The Team ID from `Local.xcconfig` appears in no tracked file.
2. SwiftLint with `--strict` (rules in `.swiftlint.yml`).
3. The Debug build.
