# ProDeepLinks iOS

Native iOS Swift Package for secure deep linking with license key validation and device fingerprinting.

Companion to the [rn-prodeeplinks](https://github.com/2ndGenTech/rn-prodeeplinks) React Native package — same API backend at `api.prodeeplinks.com`.

> **License Required**: A valid license key from the ProDeepLinks portal is required.

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

## Installation (Swift Package Manager)

### Xcode

1. **File → Add Package Dependencies…**
2. Enter your GitHub repo URL (after publishing):
   ```
   https://github.com/yourorg/ios-prodeeplinks
   ```
3. Add the **ProDeepLinks** product to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/yourorg/ios-prodeeplinks", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ProDeepLinks"]
    ),
]
```

## Usage

### 1. Initialize

```swift
import ProDeepLinks

let result = await ProDeepLinksSDK.initialize(licenseKey: "your-license-key-from-portal")
if !result.success {
    print("Init failed:", result.error ?? "unknown")
}
```

### 2. Capture launch URL (Universal Links / custom scheme)

In your `AppDelegate` or `SceneDelegate`, pass the URL that opened the app:

```swift
// UIKit AppDelegate
func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    ProDeepLinksSDK.setLaunchURL(url)
    return true
}

// SceneDelegate (Universal Links)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
        ProDeepLinksSDK.setLaunchURL(url)
    }
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
        ProDeepLinksSDK.setLaunchURL(url)
    }
}
```

### 3. Resolve deep link

```swift
let result = await ProDeepLinksSDK.getDeepLink()
if result.success, let url = result.url {
    print("Deep link:", url)
    // Navigate in your app based on the URL
} else {
    print("No deep link:", result.error ?? result.message ?? "")
}
```

With callback:

```swift
let result = await ProDeepLinksSDK.getDeepLink { url in
    print("Deep link:", url)
}
```

### Resolution flow

Matches the React Native SDK:

1. Collect device fingerprint
2. Call fingerprint match API → return URL if matched
3. Fall back to stored launch URL (from `setLaunchURL`)
4. Return `nil` URL if neither source has a link

### Analytics

```swift
let response = await ProDeepLinksSDK.trackAnalyticsEvent(
    CustomDeepLinkAnalyticsEvent(
        eventType: "deeplink",
        eventName: "button_click",
        category: "custom",
        action: "open",
        properties: ["buttonId": AnyCodable("cta_start")]
    )
)
```

### Advanced (class-based)

```swift
let client = try ProDeepLink(config: InitConfig(licenseKey: "your-key"))
let result = await client.getDeepLinkURL()
```

### Utility

```swift
if await ProDeepLinksSDK.isReady() { /* ... */ }
await ProDeepLinksSDK.reset()
```

## Project structure

```
ios-prodeeplinks/
├── Package.swift
├── Sources/ProDeepLinks/
│   ├── ProDeepLinksSDK.swift   # Public API
│   ├── APIClient.swift         # HTTP layer
│   ├── FingerprintCollector.swift
│   ├── LicenseValidator.swift
│   └── Models.swift
└── Tests/ProDeepLinksTests/
```

## Publishing to GitHub

```bash
cd ~/Desktop/ios-prodeeplinks
git init
git add .
git commit -m "Initial iOS SPM release"
git remote add origin https://github.com/yourorg/ios-prodeeplinks.git
git push -u origin main
```

Tag a release for semver pinning:

```bash
git tag 0.1.0
git push origin 0.1.0
```

## Associated Domains (Universal Links)

The SDK reads launch URLs you pass in — it does not configure Universal Links for you. Add Associated Domains in Xcode and host the `apple-app-site-association` file on your domain.

## License

Proprietary. Unauthorized use without a valid license key is prohibited.
