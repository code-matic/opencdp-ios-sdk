# OpenCDP iOS SDK

A native Swift SDK for integrating with the OpenCDP platform. Track user events, screen views, and device attributes with automatic lifecycle tracking.

## Features

- ✅ User identification and tracking
- ✅ Event tracking (custom, screen view, lifecycle)
- ✅ Device registration (APNs)
- ✅ Automatic application lifecycle tracking
- ✅ Thread-safe singleton architecture
- ✅ Swift Concurrency (async/await) support

## Installation

### Swift Package Manager

Add the following to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/code-matic/opencdp-ios-sdk.git", from: "1.0.0")
]
```

## Quick Start

1. **Initialize the SDK** in your `AppDelegate` or `App` struct:

```swift
import OpenCDP

// In your App init or applicationDidFinishLaunching
let config = OpenCDPConfig(
    cdpApiKey: "your-api-key",
    iOSAppGroup: "group.com.yourapp", // Optional: for extensions
    debug: true
)
OpenCDP.shared.initialize(config: config)
```

2. **Identify a User**:

```swift
OpenCDP.shared.identify(
    identifier: "user_123",
    properties: ["plan": "premium", "name": "John Doe"]
)
```

3. **Track Events**:

```swift
OpenCDP.shared.track(
    eventName: "purchased_item",
    properties: ["price": 99.99, "item_id": "p_123"]
)
```

4. **Register Device Token** (for Push Notifications):

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    OpenCDP.shared.registerDeviceToken(tokenString)
}
```

## Requirements

- iOS 13.0+
- Swift 5.9+


pod trunk register developers@codematic.io 'CodeMatic' --description='OpenCDP iOS SDK'

pod spec create OpenCDP

pod spec lint OpenCDP.podspec --allow-warnings

pod trunk push OpenCDP.podspec --allow-warnings


