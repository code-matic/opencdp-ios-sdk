# OpenCDP iOS SDK — Example App

SwiftUI demo covering in-app messaging with all four render types.

## Features Demonstrated

- SDK Initialization with `enableInAppMessages: true` (`OpenCDPExampleApp.swift`)
- In-app listener + manual sync (`InAppDemoView.swift`)
- Logical screen switching (`home`, `cart`, `profile`, `inbox`)
- Modal, banner, inline, and inbox_card renderers
- User Identification
- Impression / click / dismiss tracking
- Clear Identity (Logout)
- Live log output panel in-app

## Render types (`InAppDemoView.swift`)

| Backend value | SwiftUI component |
|---------------|-------------------|
| `modal` | `InAppModalView` (sheet) |
| `banner` | `InAppBannerView` (top overlay) |
| `inline` | `InAppInlineCardView` |
| `inbox_card` | Same inline card (use `inbox` screen) |

## File Structure

```
Example/
├── README.md
└── OpenCDPExample/
    ├── OpenCDPExampleApp.swift    # App entry — SDK initialization
    ├── InAppDemoView.swift        # In-app demo (primary UI)
    └── ContentView.swift          # Legacy identify/track demo (optional)
```

## How to Run

1. **Open Xcode** → Create a new Xcode Project
2. Choose **App** → **iOS**
3. Name it `OpenCDPExample`, set Interface to **SwiftUI**
4. Copy `OpenCDPExampleApp.swift` and `InAppDemoView.swift` from this directory into the project
5. **Add the SDK Package**:
   - File → Add Package Dependencies...
   - Enter: `https://github.com/opencdp/opencdp-ios-sdk.git`
   - Select **Add Package**
6. Set your API key in `OpenCDPExampleApp.swift` (`YOUR_CDP_API_KEY`) or via environment variable `CDP_API_KEY`
7. **Run** on a simulator or device — tap **Identify user**, switch screens, then **Sync in-app**

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
