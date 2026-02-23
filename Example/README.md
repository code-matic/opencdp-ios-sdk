# OpenCDP iOS SDK — Example App

This directory contains a complete SwiftUI example app demonstrating the full OpenCDP iOS SDK flow.

## Features Demonstrated

- SDK Initialization with config (`OpenCDPExampleApp.swift`)
- User Identification
- Custom Event Tracking
- Manual Screen View Tracking
- Device Token Registration (simulated APNs)
- Clear Identity (Logout)
- Auto sdk lifecycle tracking (app open / background)
- Live log output panel in-app

## File Structure

```
Example/
├── README.md
└── OpenCDPExample/
    ├── OpenCDPExampleApp.swift    # App entry — SDK initialization
    └── ContentView.swift          # Full interactive SwiftUI demo with log output
```

## How to Run

1. **Open Xcode** → Create a new Xcode Project
2. Choose **App** → **iOS**
3. Name it `OpenCDPExample`, set Interface to **SwiftUI**
4. Replace the generated `OpenCDPExampleApp.swift` and `ContentView.swift` with the files in this directory
5. **Add the SDK Package**:
   - File → Add Package Dependencies...
   - Enter: `https://github.com/code-matic/opencdp-ios-sdk.git`
   - Select **Add Package**
6. Set your API key in `OpenCDPExampleApp.swift` or via an environment variable `CDP_API_KEY`
7. **Run** on a simulator or device

## Handling Real APNs Tokens

In your `AppDelegate`, forward the real token to the SDK:

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    OpenCDP.shared.registerDeviceToken(tokenString)
}
```

And request notification permission on launch:

```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
    if granted {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```
