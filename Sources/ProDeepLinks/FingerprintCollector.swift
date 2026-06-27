import Foundation
import UIKit
import Network

enum FingerprintCollector {
    @MainActor
    static func generate() async -> DeviceFingerprint {
        let screenBounds = UIScreen.main.bounds
        let width = screenBounds.width
        let height = screenBounds.height
        let screenResolution = "\(Int(width))x\(Int(height))"

        let device = UIDevice.current
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let deviceModel = deviceModelName()
        let osVersion = device.systemVersion
        let appVersion = appVersionString()
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil

        let locale = Locale.current.identifier
        let language = Locale.current.languageCode ?? "en"
        let timezone = TimeZone.current.identifier

        let connectionType = await currentConnectionType()

        return DeviceFingerprint(
            platform: "ios",
            osVersion: osVersion,
            deviceId: deviceId,
            deviceModel: deviceModel,
            manufacturer: "Apple",
            screenResolution: screenResolution,
            screenWidth: Double(width),
            screenHeight: Double(height),
            timezone: timezone,
            language: language,
            locale: locale,
            appVersion: appVersion,
            carrier: nil,
            connectionType: connectionType,
            isSimulator: isSimulator,
            isRooted: false,
            ipAddress: nil
        )
    }

    static func buildMatchPayload(
        from fingerprint: DeviceFingerprint,
        customerUserId: String? = nil
    ) -> FingerprintMatchPayload {
        FingerprintMatchPayload(
            basic: FingerprintBasicPayload(
                userAgent: "",
                language: fingerprint.language ?? "en",
                platform: fingerprint.platform,
                screenResolution: fingerprint.screenResolution,
                timezone: fingerprint.timezone ?? "",
                timezoneOffset: TimeZone.current.secondsFromGMT() / -60
            ),
            network: FingerprintNetworkPayload(
                ipAddress: fingerprint.ipAddress ?? "",
                connectionType: fingerprint.connectionType ?? ""
            ),
            device: FingerprintDevicePayload(
                deviceModel: fingerprint.deviceModel,
                osVersion: fingerprint.osVersion,
                appVersion: fingerprint.appVersion
            ),
            customerUserId: customerUserId,
            userId: customerUserId
        )
    }

    @MainActor
    private static func appVersionString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }

    private static func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
        return identifier
    }

    private static func currentConnectionType() async -> String? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.prodeeplinks.network-monitor")

            monitor.pathUpdateHandler = { path in
                monitor.cancel()

                if path.usesInterfaceType(.wifi) {
                    continuation.resume(returning: "wifi")
                } else if path.usesInterfaceType(.cellular) {
                    continuation.resume(returning: "cellular")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    continuation.resume(returning: "ethernet")
                } else if path.status == .satisfied {
                    continuation.resume(returning: "other")
                } else {
                    continuation.resume(returning: "none")
                }
            }

            monitor.start(queue: queue)
        }
    }
}
