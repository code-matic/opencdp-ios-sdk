# OpenCDP iOS SDK Example
 
This directory contains the source code for the example app.

## How to Run

Since the Xcode project file was not auto-generated, you can create a new project in Xcode and drop these files in:

1. Open Xcode -> Create a new Xcode Project
2. Choose **App** -> **iOS**
3. Name it `OpenCDPExample`
4. Set Interface to **SwiftUI**
5. Replace the generated `OpenCDPExampleApp.swift` and `ContentView.swift` with the files in this directory.
6. **Add the SDK Package**:
   - File -> Add Package Dependencies...
   - Enter the local path to the SDK: `/Users/mac/CodeMatic/sdk-porting-agent/opencdp-ios-sdk`
   - Select "Add Package"

## Features Demonstrated

- SDK Initialization
- User Identification
- Custom Event Tracking
- Manual Screen Tracking
- Device Token Registration
