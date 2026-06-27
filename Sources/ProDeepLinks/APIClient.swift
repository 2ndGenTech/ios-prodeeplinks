import Foundation

enum APIClient {
    static let defaultBaseURL = "https://api.prodeeplinks.com"
    static let maxQueueSize = 1000
    static let maxBatchSize = 50
    static let flushIntervalSeconds: TimeInterval = 30

    private static var queuedMmpEvents: [(apiKey: String, event: MmpEventPayload)] = []
    private static var flushTask: Task<Void, Never>?
    private static var currentBaseURL = defaultBaseURL

    static func setBaseURL(_ url: String) {
        currentBaseURL = baseURL(from: url)
    }

    static func baseURL(from override: String?) -> String {
        let trimmed = (override ?? defaultBaseURL).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? defaultBaseURL : trimmed
    }

    private static func endpoint(_ path: String, baseURL: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
    }

    private static func buildMmpHeaders(apiKey: String) -> [String: String] {
        [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Accept-Encoding": "gzip",
            "x-api-key": apiKey,
            "X-SDK-Version": EventPayload.sdkVersion,
            "X-SDK-Platform": "ios",
        ]
    }

    private static func logDeprecationHeaders(_ response: HTTPURLResponse) {
        guard response.value(forHTTPHeaderField: "X-Api-Key-Deprecation") == "true" else { return }
        let message =
            response.value(forHTTPHeaderField: "X-Api-Key-Deprecation-Message") ??
            "You are using a legacy API key. Migrate to pdl_live_pk_* or pdl_test_pk_*."
        #if DEBUG
        print("[ProDeepLink]", message)
        #endif
    }

    private static func sleep(seconds: UInt64) async {
        try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
    }

    private static func mmpFetch(
        url: URL,
        request: URLRequest,
        maxRetries: Int = 3
    ) async -> (Data, HTTPURLResponse)? {
        var delaySeconds: UInt64 = 1

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { return nil }
                logDeprecationHeaders(httpResponse)

                if httpResponse.statusCode != 429 || attempt == maxRetries {
                    return (data, httpResponse)
                }

                await sleep(seconds: min(delaySeconds, 30))
                delaySeconds *= 2
            } catch {
                if attempt == maxRetries { return nil }
                await sleep(seconds: delaySeconds)
                delaySeconds *= 2
            }
        }

        return nil
    }

    // MARK: - Fingerprint match (public, no auth)

    static func matchFingerprint(
        payload: FingerprintMatchPayload,
        baseURL: String
    ) async -> FingerprintMatchResponse {
        guard let url = endpoint("/custom-deep-link/fingerprint/match", baseURL: baseURL) else {
            return FingerprintMatchResponse(error: "Invalid fingerprint endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return FingerprintMatchResponse(error: "Fingerprint match failed")
            }

            if let decoded = try? JSONDecoder().decode(FingerprintMatchResponse.self, from: data) {
                return decoded
            }

            return FingerprintMatchResponse(
                matched: false,
                matchConfidence: 0,
                error: "Fingerprint match failed: \(httpResponse.statusCode)"
            )
        } catch {
            return FingerprintMatchResponse(
                matched: false,
                matchConfidence: 0,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - MMP events

    static func postMmpEvent(
        apiKey: String,
        event: MmpEventPayload,
        baseURL: String
    ) async -> MmpEventResponse {
        guard let url = endpoint("/v1/mmp/events", baseURL: baseURL) else {
            return MmpEventResponse(success: false, error: "Invalid MMP events endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in buildMmpHeaders(apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONEncoder().encode(event)
            guard let (data, httpResponse) = await mmpFetch(url: url, request: request) else {
                return MmpEventResponse(success: false, error: "MMP event request failed")
            }

            let decoded = try? JSONDecoder().decode(MmpEventAPIResponse.self, from: data)

            if !httpResponse.statusCode.isSuccess {
                let message = decoded?.message ?? decoded?.error ?? "MMP event failed: \(httpResponse.statusCode)"
                return MmpEventResponse(success: false, error: message)
            }

            return MmpEventResponse(
                success: decoded?.success ?? true,
                eventId: decoded?.eventId,
                sessionId: decoded?.sessionId,
                resolvedEventType: decoded?.resolvedEventType,
                attributionType: decoded?.attributionType,
                source: decoded?.source,
                campaign: decoded?.campaign
            )
        } catch {
            return MmpEventResponse(success: false, error: error.localizedDescription)
        }
    }

    static func postMmpEventBatch(
        apiKey: String,
        events: [MmpEventPayload],
        baseURL: String
    ) async -> MmpBatchResponse {
        if events.isEmpty {
            return MmpBatchResponse(success: true, count: 0)
        }

        guard let url = endpoint("/v1/mmp/events/batch", baseURL: baseURL) else {
            return MmpBatchResponse(success: false, error: "Invalid MMP batch endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in buildMmpHeaders(apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        struct BatchBody: Encodable {
            let events: [MmpEventPayload]
        }

        do {
            request.httpBody = try JSONEncoder().encode(BatchBody(events: events))
            guard let (data, httpResponse) = await mmpFetch(url: url, request: request) else {
                return MmpBatchResponse(success: false, error: "MMP batch request failed")
            }

            var decoded = (try? JSONDecoder().decode(MmpBatchResponse.self, from: data))

            if !httpResponse.statusCode.isSuccess {
                let message = decoded?.message ?? decoded?.error ?? "MMP batch failed: \(httpResponse.statusCode)"
                return MmpBatchResponse(success: false, error: message)
            }

            if decoded == nil {
                decoded = MmpBatchResponse(success: true, count: events.count)
            }

            return decoded ?? MmpBatchResponse(success: true, count: events.count)
        } catch {
            return MmpBatchResponse(success: false, error: error.localizedDescription)
        }
    }

    static func postConversion(
        apiKey: String,
        payload: MmpConversionPayload,
        baseURL: String
    ) async -> MmpConversionResponse {
        guard let url = endpoint("/v1/mmp/conversions", baseURL: baseURL) else {
            return MmpConversionResponse(success: false, error: "Invalid conversions endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in buildMmpHeaders(apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        struct ConversionAPIResponse: Decodable {
            let success: Bool?
            let conversionId: String?
            let attribution: MmpAttributionResult?
            let message: String?
            let error: String?
        }

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            guard let (data, httpResponse) = await mmpFetch(url: url, request: request) else {
                return MmpConversionResponse(success: false, error: "Conversion request failed")
            }

            let decoded = try? JSONDecoder().decode(ConversionAPIResponse.self, from: data)

            if !httpResponse.statusCode.isSuccess {
                let message = decoded?.message ?? decoded?.error ?? "Conversion failed: \(httpResponse.statusCode)"
                return MmpConversionResponse(success: false, error: message)
            }

            return MmpConversionResponse(
                success: decoded?.success ?? true,
                conversionId: decoded?.conversionId,
                attribution: decoded?.attribution
            )
        } catch {
            return MmpConversionResponse(success: false, error: error.localizedDescription)
        }
    }

    static func fetchAttribution(
        apiKey: String,
        conversionId: String,
        baseURL: String
    ) async -> MmpAttributionResponse {
        guard let url = endpoint("/v1/mmp/attribution/\(conversionId)", baseURL: baseURL) else {
            return MmpAttributionResponse(success: false, error: "Invalid attribution endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in buildMmpHeaders(apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        struct AttributionAPIResponse: Decodable {
            let success: Bool?
            let attributions: MmpAttributionResult?
            let message: String?
            let error: String?
        }

        do {
            guard let (data, httpResponse) = await mmpFetch(url: url, request: request) else {
                return MmpAttributionResponse(success: false, error: "Attribution request failed")
            }

            let decoded = try? JSONDecoder().decode(AttributionAPIResponse.self, from: data)

            if !httpResponse.statusCode.isSuccess {
                let message = decoded?.message ?? decoded?.error ?? "Attribution fetch failed: \(httpResponse.statusCode)"
                return MmpAttributionResponse(success: false, error: message)
            }

            return MmpAttributionResponse(
                success: decoded?.success ?? true,
                attributions: decoded?.attributions
            )
        } catch {
            return MmpAttributionResponse(success: false, error: error.localizedDescription)
        }
    }

    static func fetchAttributionWithRetry(
        apiKey: String,
        conversionId: String,
        baseURL: String,
        maxRetries: Int = 3
    ) async -> MmpAttributionResponse {
        var last = MmpAttributionResponse(success: false, error: "Unknown error")

        for attempt in 1...maxRetries {
            last = await fetchAttribution(apiKey: apiKey, conversionId: conversionId, baseURL: baseURL)
            if last.success, last.attributions != nil {
                return last
            }
            if attempt < maxRetries {
                await sleep(seconds: 2)
            }
        }

        return last
    }

    // MARK: - Event queue

    static func enqueueMmpEvent(_ event: MmpEventPayload, apiKey: String) {
        if queuedMmpEvents.count >= maxQueueSize {
            queuedMmpEvents.removeFirst()
        }
        queuedMmpEvents.append((apiKey: apiKey, event: event))
        ensureFlushTimer()
        if queuedMmpEvents.count >= maxBatchSize {
            Task { _ = await flushMmpEvents(baseURL: currentBaseURL) }
        }
    }

    static func ensureFlushTimer() {
        guard flushTask == nil else { return }
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(flushIntervalSeconds * 1_000_000_000))
                _ = await flushMmpEvents(baseURL: currentBaseURL)
            }
        }
    }

    static func flushMmpEvents(baseURL: String) async -> FlushResult {
        if queuedMmpEvents.isEmpty {
            return FlushResult(success: true, count: 0)
        }

        guard let firstKey = queuedMmpEvents.first?.apiKey else {
            return FlushResult(success: false, error: "Missing API key in queue")
        }

        var batchItems: [(apiKey: String, event: MmpEventPayload)] = []
        var remaining: [(apiKey: String, event: MmpEventPayload)] = []

        for item in queuedMmpEvents {
            if batchItems.count < maxBatchSize, item.apiKey == firstKey {
                batchItems.append(item)
            } else {
                remaining.append(item)
            }
        }

        queuedMmpEvents = remaining

        let result = await postMmpEventBatch(
            apiKey: firstKey,
            events: batchItems.map(\.event),
            baseURL: baseURL
        )

        if result.success != true {
            queuedMmpEvents = batchItems + queuedMmpEvents
            return FlushResult(success: false, error: result.error)
        }

        return FlushResult(
            success: true,
            count: result.count ?? batchItems.count,
            sessionId: result.sessionId
        )
    }

    static func resetQueue() {
        flushTask?.cancel()
        flushTask = nil
        queuedMmpEvents.removeAll()
        currentBaseURL = defaultBaseURL
    }
}

private extension Int {
    var isSuccess: Bool {
        (200...299).contains(self)
    }
}
