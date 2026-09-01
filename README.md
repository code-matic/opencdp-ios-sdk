# OpenCDP iOS SDK

A native Swift SDK for integrating with the OpenCDP platform. Track user events, screen views, and device attributes with automatic lifecycle tracking.

## Documentation

Published guides on [docs.opencdp.io](https://docs.opencdp.io):

- [Mobile E2E integration guide](https://docs.opencdp.io/integrations/mobile/e2e-guide)
- [Identity and devices](https://docs.opencdp.io/integrations/mobile/identity-and-devices)
- [Rich push images](https://docs.opencdp.io/integrations/mobile/push-big-picture)
- [iOS SDK docs](https://docs.opencdp.io/integrations/ios/intro)
- [Example app guide](https://docs.opencdp.io/integrations/ios/examples/example-app)

## Features

- ✅ User identification and trait tracking
- ✅ Custom event tracking
- ✅ Screen view tracking (manual and automatic)
- ✅ Device registration for push notifications (APNs)
- ✅ Rich push big-picture images via Notification Service Extension (`image_url`)
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
    .package(url: "https://github.com/code-matic/opencdp-ios-sdk.git", from: "0.1.1")
]
```

Or in Xcode: **File → Add Packages** → paste the URL above.

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'OpenCDP', '~> 1.0.2'
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

Track navigation to a specific screen manually. Prefer this for SwiftUI and for stable Include / Exclude page-rule ids.

```swift
OpenCDP.shared.trackScreenView(
    title: "/product-details",
    properties: ["sku": "X-001"]
)
```

When `autoTrackScreens` is enabled, UIKit appearances are tracked using `title` / `navigationItem.title` when set, otherwise a cleaned view controller type name. System/container controllers are skipped. Screen views are recorded as `screen_view` events with a `screen` property.

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

### Rich push (big-picture) via Notification Service Extension

When the push payload includes **`data.image_url`**, the Notification Service Extension can attach the image before display. The backend must set **`aps.mutable-content: 1`**.

In your Notification Service Extension target:

```swift
import UserNotifications
import OpenCDP

class NotificationService: UNNotificationServiceExtension {
    private let session = OpenCdpNotificationExtensionSession()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        session.didReceive(
            request,
            appGroup: "group.com.yourapp.opencdp",
            contentHandler: contentHandler
        )
    }

    override func serviceExtensionTimeWillExpire() {
        session.serviceExtensionTimeWillExpire()
    }
}
```

`OpenCdpPushExtensionHelper`:
- Downloads `image_url` and attaches it as a `UNNotificationAttachment`
- Delivers enriched content **before** posting delivery metrics (display is not blocked)
- Attaches the image even when delivery metric prerequisites are missing

Use `OpenCDPPushPayload.parseImageUrl(data)` in the main app when parsing push payloads manually.

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

## Customer.io dual-write (optional)

Link the Customer.io iOS SDK via the optional CocoaPods subspec:

```ruby
pod 'OpenCDP/CustomerIO', '~> 0.1.1'
pod 'CustomerIO/DataPipelines', '~> 3.0'
```

When `sendToCustomerIo: true` and `customerIo` is configured, identify/track/screen/registerDeviceToken/clearIdentity mirror to Customer.io. Without the CIO SDK linked, OpenCDP continues to work (no-op dual-write).

---

## Push setup helper

```swift
OpenCDPPushSetup.setupPushNotifications(application: UIApplication.shared)
// In AppDelegate — forward APNs token:
OpenCDP.shared.registerDeviceToken(apnsTokenString)
```

See [PUSH_NOTIFICATION_V2_INTEGRATION.md](https://github.com/opencdp/opencdp-flutter-sdk/blob/main/PUSH_NOTIFICATION_V2_INTEGRATION.md) for NSE big-picture setup.

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
