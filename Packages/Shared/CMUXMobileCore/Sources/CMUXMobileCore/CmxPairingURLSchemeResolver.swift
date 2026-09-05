import Foundation

/// Resolves the pairing target for the current process without global state.
public struct CmxPairingURLSchemeResolver: Sendable {
    private let currentIOSBundleIdentifier: String?
    private let targetIOSBundleIdentifier: String?
    private let macInstanceTag: String?
    private let isDevelopmentBuild: Bool

    /// Captures the current app identity and any explicit Mac pairing target.
    ///
    /// A Mac may set `CMUX_IOS_PAIRING_BUNDLE_IDENTIFIER` to any authoritative
    /// release-lane bundle id. Tagged Mac builds otherwise target their exact
    /// same-tag iOS bundle.
    public init(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        currentIOSBundleIdentifier = bundle.bundleIdentifier
        targetIOSBundleIdentifier =
            environment["CMUX_IOS_PAIRING_BUNDLE_IDENTIFIER"]
        macInstanceTag = environment["CMUX_TAG"]
        #if DEBUG
        isDevelopmentBuild = true
        #else
        isDevelopmentBuild = false
        #endif
    }

    init(
        currentIOSBundleIdentifier: String?,
        targetIOSBundleIdentifier: String?,
        macInstanceTag: String?,
        isDevelopmentBuild: Bool
    ) {
        self.currentIOSBundleIdentifier = currentIOSBundleIdentifier
        self.targetIOSBundleIdentifier = targetIOSBundleIdentifier
        self.macInstanceTag = macInstanceTag
        self.isDevelopmentBuild = isDevelopmentBuild
    }

    /// Whether `scheme` is an authoritative lane scheme or the exact scheme
    /// this process emits (its own bundle on iOS, its target bundle on macOS).
    public func accepts(scheme: String?) -> Bool {
        CmxPairingURLScheme.accepting(
            rawValue: scheme,
            selfBundleIdentifier: targetIOSBundleIdentifier
                ?? currentIOSBundleIdentifier
        ) != nil
    }

    /// Whether `urlString` is a pairing URL this process accepts.
    public func accepts(urlString: String?) -> Bool {
        CmxPairingURLScheme.accepting(
            urlString: urlString,
            selfBundleIdentifier: targetIOSBundleIdentifier
                ?? currentIOSBundleIdentifier
        ) != nil
    }

    /// The exact scheme this process should emit, or `nil` on invalid identity.
    public var resolved: CmxPairingURLScheme? {
        #if os(iOS)
        return CmxPairingURLScheme(
            iOSBundleIdentifier: currentIOSBundleIdentifier
        )
        #else
        if let targetIOSBundleIdentifier {
            return CmxPairingURLScheme(
                iOSBundleIdentifier: targetIOSBundleIdentifier
            )
        }
        if macInstanceTag == nil || macInstanceTag?.isEmpty == true {
            return CmxPairingURLScheme(
                iOSBundleIdentifier: isDevelopmentBuild
                    ? "dev.cmux.ios"
                    : "com.cmux.app"
            )
        }
        guard let namespace = MobileIOSAppNamespace(
            pairedMacInstanceTag: macInstanceTag
        ) else {
            return nil
        }
        return CmxPairingURLScheme(
            iOSBundleIdentifier: namespace.bundleIdentifier
        )
        #endif
    }
}
