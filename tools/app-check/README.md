# Local compile check (xtool)

`tools/check-app.sh` compiles the `DailyStore` app and `DailyStoreWidget` targets for iOS on the Windows
PC, in WSL Ubuntu, using the iOS SDK that [xtool](https://github.com/xtool-org/xtool) builds from an Xcode
download. It takes about 15 s from cold and a few seconds after small edits, instead of an 11 minute CI
round.

`Package.swift` here mirrors the two targets in `ios/project.yml` for SwiftPM: `Sources/Shared` is
copied into both, as Xcode compiles it into both; Debug defines `DEBUG`, Release does not; Swift 5 mode,
iOS 26.0. If a target, source folder or dependency changes in `project.yml`, change it here and in
`check-app.sh` too. CI and TestFlight never read this folder.

## What it does not cover

- It stops at the first file that fails, so it shows one error per run. Fix it and run again.
- Running the ValorantCore tests (`swift test` on Windows does that), the simulator, launching the app
  and screenshots: CI only.
- The asset catalog, Info.plist, entitlements and signing: not built at all. Only `.swift` files are
  staged.
- The SDK and compiler differ from CI's: Xcode 27.1 (iOS 27.1 SDK, Swift 6.4) here, Xcode 26.6
  (iOS 26.5 SDK, Swift 6.3) on CI until the runner image gets Xcode 27. A clean local run is a strong
  hint, not proof; the CI compile check stays the gate. Watch for APIs that are new in iOS 27: they
  compile here and fail on CI.

## Setup (once per PC)

KaiC's PC already has all of this; BiliNative uses the same install.

1. Download Xcode 27 (27.1 on KaiC's PC) with the owner's Apple ID from
   <https://developer.apple.com/download/all/?q=Xcode%2027> into `D:\Tools\Xcode\` (outside the repo;
   never commit it or anything extracted from it).
2. In WSL: `bash tools/app-check/setup-wsl.sh /mnt/d/Tools/Xcode/Xcode_27.1.xip`. It installs Swift 6.4.1
   (swiftly), xtool 1.22.2 and the SDK (`~/.swiftpm/swift-sdks/darwin.artifactbundle`). No Apple ID
   login: compiling needs none.

Builds are staged in `~/.cache/dailystore-check/<checkout>/` inside WSL; delete that folder to start clean.
The full log of the last run is `last-build.log` there.
