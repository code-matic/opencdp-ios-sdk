# OpenCDP iOS SDK

A native Swift SDK for integrating with the OpenCDP platform. Track user events, screen views, and device attributes with automatic lifecycle tracking.

## Features

- ✅ User identification and trait tracking
- ✅ Custom event tracking
- ✅ Screen view tracking (manual and automatic)
- ✅ Device registration for push notifications (APNs)
- ✅ Clear identity / logout support
- ✅ Automatic application lifecycle tracking
- ✅ Thread-safe singleton architecture
- ✅ Swift Concurrency (async/await) support
- ✅ App Group support for Notification Service Extensions

## Requirements

- iOS 13.0+
- Swift 5.9+

---

## Examples

A complete runnable SwiftUI example app is available in [`Example/`](Example/):

```
Example/
├── README.md                          # Xcode setup & run instructions
└── OpenCDPExample/
    ├── OpenCDPExampleApp.swift        # App entry — SDK initialization
    └── ContentView.swift              # Full interactive demo with live log output
```

See [`Example/README.md`](Example/README.md) for step-by-step Xcode setup.

---

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/code-matic/opencdp-ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Packages** → paste the URL above.

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'OpenCDP', '~> 1.0'
```

Then run:

```bash
pod install
```

---

## Quick Start

1. **Initialize the SDK** in your `AppDelegate` or `App` struct:

```swift
import OpenCDP

@main
struct MyApp: App {
    init() {
        let config = OpenCDPConfig(
            cdpApiKey: "your-api-key",
            debug: true
        )
        OpenCDP.shared.initialize(config: config)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

2. **Identify a User** (e.g., on login):

```swift
OpenCDP.shared.identify(
    identifier: "user_123",
    properties: ["plan": "premium", "name": "Jane Doe"]
)
```

3. **Track Events**:

```swift
OpenCDP.shared.track(
    eventName: "purchased_item",
    properties: ["price": 99.99, "item_id": "p_123"]
)
```

4. **Register Device Token** (in `AppDelegate`):

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    OpenCDP.shared.registerDeviceToken(tokenString)
}
```

---

## Usage

### Identify a User

Associate a unique ID with user traits. Call this on sign-up, login, or when user attributes change.

```swift
OpenCDP.shared.identify(
    identifier: "user_123",
    properties: [
        "email": "user@example.com",
        "name": "Jane Doe",
        "plan": "pro"
    ]
)
```

> `identifier` must be a unique user ID — **not** an email address.

---

### Track an Event

Record any custom user action.

```swift
OpenCDP.shared.track(
    eventName: "checkout_completed",
    properties: [
        "total": 149.99,
        "currency": "USD",
        "items": 3
    ]
)
```

---

### Track a Screen View

Track navigation to a specific screen manually. If `autoTrackScreens` is enabled, this is unnecessary for standard UIKit view controllers.

```swift
OpenCDP.shared.trackScreenView(
    title: "ProductDetails",
    properties: ["sku": "X-001"]
)
```

Screen views are recorded internally as `screen_view` events with a `screen` property.

---

### Register Device Token

Register an APNs token to enable push notification targeting.

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    OpenCDP.shared.registerDeviceToken(tokenString)
}
```

---

### Clear Identity / Logout

Reset the SDK's user state when a user logs out. The next `identify` call will establish a new user session.

```swift
OpenCDP.shared.clearIdentity()
```

After calling `clearIdentity()`, `currentUserId` is set to `nil`. Subsequent `track` calls will have no associated identity until `identify` is called again.

---

### Automatic Lifecycle Tracking

Enable with `trackApplicationLifecycleEvents: true` in the config. The SDK automatically fires:

| Event | Trigger |
|-------|---------|
| `application_opened` | App becomes active |
| `application_backgrounded` | App enters background |

```swift
let config = OpenCDPConfig(
    cdpApiKey: "your-api-key",
    trackApplicationLifecycleEvents: true,
    autoTrackScreens: true   // Also auto-tracks screen views
)
```

---

### App Group (Notification Extension)

To share the SDK context with a **Notification Service Extension**, pass an App Group ID:

```swift
let config = OpenCDPConfig(
    cdpApiKey: "your-api-key",
    iOSAppGroup: "group.com.yourapp.opencdp"
)
```

Make sure the App Group is enabled in both your main app and extension targets in Xcode.

---

## Error Handling

By default, the SDK **silently logs errors** instead of throwing them. To receive errors in your code, set `throwErrorsBack: true`:

```swift
let config = OpenCDPConfig(
    cdpApiKey: "your-api-key",
    throwErrorsBack: true
)
```

The SDK uses the `CDPError` type internally with the following cases:

| Error Case | Cause |
|-----------|-------|
| `networkError(String)` | Network connectivity failure |
| `serverError(Int, String)` | Non-2xx HTTP response |
| `decodingError` | Response parsing failure |
| `invalidInput` | Bad identifier or payload |
| `initializationError` | SDK used before `initialize()` is called |

---

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cdpApiKey` | `String` | **Required** | Your OpenCDP API Key |
| `apiBaseUrl` | `String` | Production URL | Custom API Gateway URL |
| `iOSAppGroup` | `String?` | `nil` | App Group ID for Notification Extensions |
| `debug` | `Bool` | `false` | Enable verbose console logging |
| `autoTrackScreens` | `Bool` | `true` | Auto-track UIViewController appearances |
| `trackApplicationLifecycleEvents` | `Bool` | `true` | Auto-track app open/background events |
| `autoTrackDeviceAttributes` | `Bool` | `true` | Automatically collect and send device attributes |
| `throwErrorsBack` | `Bool` | `false` | Throw errors instead of logging silently |

---

## Accessing the Current User

```swift
if let userId = OpenCDP.shared.currentUserId {
    print("Currently identified: \(userId)")
}
```
