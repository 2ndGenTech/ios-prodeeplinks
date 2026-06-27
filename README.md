# ProDeepLinks iOS

Native iOS Swift Package for **ProDeepLinks** — deferred deep linking, attribution param handling, and MMP event tracking.

Companion to the [rn-prodeeplinks](https://github.com/2ndGenTech/rn-prodeeplinks) React Native package — same API backend at `api.prodeeplinks.com`.

> **API key required**: Get your API key from [prodeeplinks.com](https://prodeeplinks.com/signup).

> **Version**: `0.2.0`

## Features

- Deep link resolution (OS URL first, then fingerprint match)
- Attribution param extraction (`clickId`, `pdlSessionId`, UTMs) on launch and warm-start links
- MMP event tracking (`/v1/mmp/events`, batch, conversions, attribution)
- Deferred fingerprint matching (public endpoint, no auth header)
- Swift 5.9+ / iOS 15+

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

## Installation (Swift Package Manager)

### Xcode

1. **File → Add Package Dependencies…**
2. Enter:
   ```
   https://github.com/2ndGenTech/ios-prodeeplinks
   ```
3. Add the **ProDeepLinks** product to your app target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/2ndGenTech/ios-prodeeplinks", from: "0.2.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ProDeepLinks"]
    ),
]
```

## Quick start

```swift
import ProDeepLinks

// 1. Capture launch URL from AppDelegate / SceneDelegate (see below)
// ProDeepLinksSDK.setLaunchURL(url)

// 2. Initialize (parses cold-start deep link + runs deferred fingerprint match)
let initResult = await ProDeepLinksSDK.initialize(apiKey: "your-api-key")
if !initResult.success {
    print(initResult.error ?? "Init failed")
    return
}

// 3. If your backend/native layer sends app_open and returns a sessionId:
await ProDeepLinksSDK.updateSessionId(sessionIdFromBackend)

// 4. Resolve deep link URL
let link = await ProDeepLinksSDK.getDeepLink()
if link.success, let url = link.url {
    print("Deep link:", url)
    // Navigate in your app using url
}

// 5. After login — auto-sends a login event
_ = await ProDeepLinksSDK.setCustomerUserId("user_42")

// 6. Purchase — sends purchase event + conversion in parallel
let purchase = await ProDeepLinksSDK.trackPurchase(TrackPurchasePayload(
    revenue: 29.99,
    currency: "USD",
    orderId: "order_123",
    productId: "prod_annual"
))
```

## Capture launch URL (Universal Links / custom scheme)

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

// SceneDelegate (custom scheme)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
        ProDeepLinksSDK.setLaunchURL(url)
    }
}

// SceneDelegate (Universal Links)
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
        ProDeepLinksSDK.setLaunchURL(url)
    }
}
```

Call `setLaunchURL` before or after `initialize()` — attribution params are parsed when the URL is stored.

## Deep link resolution flow

On `initialize()`:

1. Validates API key format locally
2. Collects and caches device fingerprint
3. Parses stored launch URL for `clickId`, `pdlSessionId`, and UTM params
4. Runs deferred fingerprint match in parallel when no URL is present

On `getDeepLink()`:

1. Returns cached URL if already resolved
2. Falls back to stored launch URL (from `setLaunchURL`)
3. Falls back to `POST /custom-deep-link/fingerprint/match` (public, no auth)

```
User taps link → OS opens app with URL
       ↓
setLaunchURL / initialize stores clickId / pdlSessionId / UTMs
       ↓
getDeepLink() returns URL for navigation
       ↓
trackAnalyticsEvent / trackPurchase attach stored attribution params
```

## App launch (`app_open`) — backend responsibility

This SDK **does not** send `app_open` on launch or foreground. That is handled by your **backend / native MMP layer**.

When your backend returns a `sessionId` from its `app_open` handling, pass it into the SDK:

```swift
await ProDeepLinksSDK.updateSessionId(sessionId)
```

The SDK uses that `sessionId` on subsequent events (`login`, `purchase`, custom events, conversions).

## API reference

### `initialize(config:)` / `initialize(apiKey:)`

| Field | Type | Description |
|-------|------|-------------|
| `apiKey` | String | Your API key from the ProDeepLinks portal |
| `licenseKey` | String | Deprecated alias for `apiKey` |
| `apiBaseUrl` | String? | Optional. Defaults to `https://api.prodeeplinks.com` |

### `getDeepLink(onURL:)`

Returns `DeepLinkResponse` with `success`, `url`, `message`, and `error`. URL is `nil` when no deferred link is available.

### `updateSessionId(_:)`

Sets the in-memory MMP session ID from your backend `app_open` layer.

### `setCustomerUserId(_:)`

Stores the user ID and **automatically sends** a `login` event to `/v1/mmp/events`.

### `trackAnalyticsEvent(_:)`

Sends custom/screen events. Secondary events are **batched** to `/v1/mmp/events/batch` (max 50). `login` and `purchase` are sent immediately.

Legacy event types are mapped automatically:

| Old | Sent as |
|-----|---------|
| `deeplink` | `app_open` |
| `identify` | `login` |
| `pro_track` | `custom` |

Auth uses the `x-api-key` header — do not put the key in the event body.

### `trackPurchase(_:)`

Sends **both** in parallel (per MMP integration guide):

- `POST /v1/mmp/events` with `eventType: "purchase"`
- `POST /v1/mmp/conversions` with `conversionType: "purchase"`

Duplicate `orderId` values are skipped client-side.

### `trackConversion(_:)`

Sends a conversion to `/v1/mmp/conversions`. Retries attribution fetch if inline attribution is null.

### `getAttribution(conversionId:)`

Fetches attribution from `GET /v1/mmp/attribution/:conversionId`.

### `flush()`

Force-flushes the in-memory event batch queue.

### `isReady()` / `reset()`

Check initialization state or clear SDK runtime state.

### `ProDeepLink` class (optional)

```swift
let pdl = try ProDeepLink(config: InitConfig(apiKey: "your-api-key"))
let initResult = await pdl.initialize()
let result = await pdl.getDeepLinkURL()
```

## Authentication

| Endpoint | Auth |
|----------|------|
| `/v1/mmp/*` | `x-api-key` header with your API key |
| `/custom-deep-link/fingerprint/match` | None (public) |

Use only the API key provided for your mobile app in the ProDeepLinks portal. Do not embed secret or server-side keys in the app.

## MMP endpoints used

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/v1/mmp/events` | Immediate events (`login`, `purchase`, `app_open`) |
| POST | `/v1/mmp/events/batch` | Batched secondary events |
| POST | `/v1/mmp/conversions` | Conversions + attribution |
| GET | `/v1/mmp/attribution/:id` | Attribution lookup |
| POST | `/custom-deep-link/fingerprint/match` | Deferred deep link resolution |

## Project structure

```
ios-prodeeplinks/
├── Package.swift
├── Sources/ProDeepLinks/
│   ├── ProDeepLinksSDK.swift   # Public API
│   ├── APIClient.swift         # HTTP / MMP layer
│   ├── FingerprintCollector.swift
│   ├── LicenseValidator.swift
│   ├── DeepLinkParams.swift
│   ├── EventPayload.swift
│   └── Models.swift
└── Tests/ProDeepLinksTests/
```

## Associated Domains (Universal Links)

The SDK reads launch URLs you pass in via `setLaunchURL` — it does not configure Universal Links for you. Add Associated Domains in Xcode and host the `apple-app-site-association` file on your domain.

## Error handling

- Invalid API key format is rejected locally before any network call
- MMP API errors return `{ success: false, error: String }`
- Rate limit (`429`) responses retry with exponential backoff (up to 3 attempts)

## Troubleshooting

**`getDeepLink()` returns nil**

- Normal on organic installs with no prior link click
- Deferred match requires a prior tracked click within the attribution window
- Ensure `setLaunchURL` is called when the app opens from a link

**Events missing attribution**

- Ensure `initialize()` ran before navigation (params are parsed on launch)
- Ensure `updateSessionId()` is called after your backend `app_open`
- Call `setLaunchURL` for warm-start links from `SceneDelegate`

**401 on MMP calls**

- Verify your API key from the [ProDeepLinks portal](https://prodeeplinks.com/signup)
- Confirm `initialize(apiKey:)` succeeded

## Support

- Portal: [prodeeplinks.com/signup](https://prodeeplinks.com/signup)
- React Native SDK: [rn-prodeeplinks](https://github.com/2ndGenTech/rn-prodeeplinks)

## License

Proprietary software. Requires a valid API key from the ProDeepLinks portal.
