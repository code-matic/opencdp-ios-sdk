# Changelog

## [Unreleased]

### Added

- `registerDeviceToken(_:fcmToken:)` takes the Firebase Cloud Messaging token. OpenCDP sends push through FCM, and the SDK previously registered iOS devices with no FCM token, so they could not receive OpenCDP pushes. The token is stored and reused on later launches; the single-argument call still works
- An error is logged when a device registers without an FCM token, or without `iOSAppGroup` (the Notification Service Extension then cannot report delivery)

### Fixed

- The in-app banner used an iOS 14-only button API, so the SDK failed to compile at its iOS 13 deployment target

### Docs

- README push examples pass the FCM token and use `try?` (`registerDeviceToken` throws)

## [1.0.3] - 2026-09-29

### Changed

- Default gateway fallback hosts updated from `api.opencdp.com` / `api.opencdp.xyz` to `api.open-cdp.com` / `api.open-cdp.xyz` (primary remains `api.opencdp.io`)

## [1.0.2] - 2026-07-08

### Added

- `InAppDemoView` SwiftUI example covering all four in-app render types
- Customer.io optional subspec (`OpenCDP/CustomerIO`)

### Changed

- `OpenCDPExampleApp` enables in-app messaging by default in the example
- Podspec version aligned with git release tags

## [1.0.1] - 2026-06-17

### Fixed

- Removed invalid parent dependency from `PushExtension` subspec

## [0.1.1] - 2026-05-18

- Earlier CocoaPods release
