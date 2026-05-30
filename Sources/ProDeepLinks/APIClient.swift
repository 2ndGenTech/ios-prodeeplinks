import Foundation

enum APIClient {
    static let baseAPIURL = "https://api.prodeeplinks.com"
    static let deepLinkEndpointPath = "/custom-deep-link/fingerprint/match"
    static let analyticsEndpoint = "\(baseAPIURL)/custom-deep-link/track/event"
    static let defaultTimeout: TimeInterval = 10

    static func validateLicenseInit(licenseKey: String) async -> (success: Bool, error: String?) {
        let endpoint = URL(string: "\(baseAPIURL)/custom-deep-link/license/validate")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["licenseKey": licenseKey])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "License validation failed")
            }

            let decoded = try? JSONDecoder().decode(LicenseValidationAPIResponse.self, from: data)

            if !httpResponse.statusCode.isSuccess {
                let message = decoded?.message ?? decoded?.error ?? "License validation failed"
                return (false, message)
            }

            guard decoded?.success == true, decoded?.valid == true else {
                let message = decoded?.message ?? decoded?.error ?? "License is not valid"
                return (false, message)
            }

            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    static func matchFingerprint(
        payload: FingerprintMatchPayload,
        baseURL: String = baseAPIURL,
        licenseKey: String?
    ) async -> FingerprintMatchResponse {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = URL(string: "\(trimmedBase)/custom-deep-link/fingerprint/match")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let licenseKey {
            request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        }

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode.isSuccess {
                if let decoded = try? JSONDecoder().decode(FingerprintMatchResponse.self, from: data) {
                    return decoded
                }
            }

            if let decoded = try? JSONDecoder().decode(FingerprintMatchResponse.self, from: data) {
                return decoded
            }

            return FingerprintMatchResponse(
                matched: false,
                matchConfidence: 0,
                url: nil,
                message: nil,
                error: "Fingerprint match failed"
            )
        } catch {
            return FingerprintMatchResponse(
                matched: false,
                matchConfidence: 0,
                url: nil,
                message: nil,
                error: error.localizedDescription
            )
        }
    }

    static func fetchDeepLinkURL(
        licenseKey: String,
        fingerprint: DeviceFingerprint,
        apiEndpoint: String? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async -> DeepLinkResponse {
        let validation = LicenseValidator.validateFormat(licenseKey)
        if !validation.isValid {
            return DeepLinkResponse(success: false, error: validation.message ?? "Invalid license key")
        }

        let trimmedBase = (apiEndpoint ?? baseAPIURL).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = trimmedBase.contains("/custom-deep-link/")
            ? trimmedBase
            : "\(trimmedBase)\(deepLinkEndpointPath)"

        guard let endpoint = URL(string: endpointPath) else {
            return DeepLinkResponse(success: false, error: "Invalid API endpoint")
        }

        let payload: [String: Any] = [
            "licenseKey": licenseKey,
            "fingerprint": fingerprintDictionary(from: fingerprint),
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        request.timeoutInterval = timeout

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return DeepLinkResponse(success: false, error: "Invalid response")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return DeepLinkResponse(success: false, error: "API error: \(httpResponse.statusCode)")
            }

            if !httpResponse.statusCode.isSuccess {
                let message = json["message"] as? String ?? "API error: \(httpResponse.statusCode)"
                return DeepLinkResponse(success: false, error: message)
            }

            let success = json["success"] as? Bool ?? false
            if success {
                if let url = json["url"] as? String {
                    return DeepLinkResponse(
                        success: true,
                        url: url,
                        message: json["message"] as? String
                    )
                }
                return DeepLinkResponse(
                    success: true,
                    url: nil,
                    message: json["message"] as? String ?? "No deep link available"
                )
            }

            return DeepLinkResponse(
                success: false,
                error: json["message"] as? String ?? "No URL returned from API"
            )
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                return DeepLinkResponse(success: false, error: "Request timeout")
            }
            return DeepLinkResponse(success: false, error: error.localizedDescription)
        }
    }

    static func fetchDeepLinkURLWithRetry(
        licenseKey: String,
        fingerprint: DeviceFingerprint,
        retryAttempts: Int = 3,
        apiEndpoint: String? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async -> DeepLinkResponse {
        var lastError: DeepLinkResponse?

        for attempt in 1...retryAttempts {
            let result = await fetchDeepLinkURL(
                licenseKey: licenseKey,
                fingerprint: fingerprint,
                apiEndpoint: apiEndpoint,
                timeout: timeout
            )

            if result.success {
                return result
            }

            lastError = result

            if let error = result.error?.lowercased(),
               error.contains("license") || error.contains("invalid") {
                return result
            }

            if attempt < retryAttempts {
                let delay = UInt64(attempt) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        return lastError ?? DeepLinkResponse(success: false, error: "Failed after retries")
    }

    static func trackCustomDeepLinkEvent(
        event: CustomDeepLinkAnalyticsEvent,
        licenseKey: String?
    ) async -> [String: Any] {
        guard let endpoint = URL(string: analyticsEndpoint) else {
            return ["success": false, "error": "Invalid analytics endpoint"]
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let licenseKey {
            request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        }

        do {
            request.httpBody = try JSONEncoder().encode(event)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
            return ["success": true]
        } catch {
            return ["success": false, "error": error.localizedDescription]
        }
    }

    private static func fingerprintDictionary(from fingerprint: DeviceFingerprint) -> [String: Any] {
        var dict: [String: Any] = [
            "platform": fingerprint.platform,
            "osVersion": fingerprint.osVersion,
            "deviceId": fingerprint.deviceId,
            "deviceModel": fingerprint.deviceModel,
            "screenResolution": fingerprint.screenResolution,
            "screenWidth": fingerprint.screenWidth,
            "screenHeight": fingerprint.screenHeight,
            "appVersion": fingerprint.appVersion,
        ]

        if let manufacturer = fingerprint.manufacturer { dict["manufacturer"] = manufacturer }
        if let timezone = fingerprint.timezone { dict["timezone"] = timezone }
        if let language = fingerprint.language { dict["language"] = language }
        if let locale = fingerprint.locale { dict["locale"] = locale }
        if let carrier = fingerprint.carrier { dict["carrier"] = carrier }
        if let connectionType = fingerprint.connectionType { dict["connectionType"] = connectionType }
        if let isSimulator = fingerprint.isSimulator { dict["isSimulator"] = isSimulator }
        if let isRooted = fingerprint.isRooted { dict["isRooted"] = isRooted }
        if let ipAddress = fingerprint.ipAddress { dict["ipAddress"] = ipAddress }

        return dict
    }
}

private extension Int {
    var isSuccess: Bool {
        (200...299).contains(self)
    }
}
