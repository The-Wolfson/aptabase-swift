import Foundation

enum ErrorSeverity: String, Encodable {
    case fatal
    case error
}

enum ErrorKind: String, Encodable {
    case crash
    case unhandled
    case taskException
    case handled
}

struct ErrorReport: Encodable {
    var errorMessage: String
    var errorType: String
    var stackTrace: String?
    var timestamp: Date
    var sessionId: String
    var platform: String
    var osName: String?
    var osVersion: String?
    var appVersion: String?
    var sdkVersion: String
    var severity: ErrorSeverity
    var kind: ErrorKind
    var isDebug: Bool

    private static let maxErrorMessage = 5000
    private static let maxErrorType = 100
    private static let maxStackTrace = 10000
    private static let maxOsName = 30
    private static let maxOsVersion = 100
    private static let maxAppVersion = 50
    private static let maxSdkVersion = 40

    static func build(
        from error: Error,
        severity: ErrorSeverity,
        kind: ErrorKind,
        sessionId: String,
        sdkVersion: String,
        env: EnvironmentInfo
    ) -> ErrorReport {
        let typeName = String(describing: type(of: error))
        let errorMessage = (error as NSError).localizedDescription
        let prefix = severity == .fatal ? "Fatal " : ""
        let stack = Thread.callStackSymbols.joined(separator: "\n")

        return ErrorReport(
            errorMessage: truncate("\(prefix)\(typeName): \(errorMessage)", maxErrorMessage),
            errorType: truncate(typeName, maxErrorType),
            stackTrace: stack.isEmpty ? nil : truncate(stack, maxStackTrace),
            timestamp: Date(),
            sessionId: sessionId,
            platform: "Apple",
            osName: env.osName.isEmpty ? nil : truncate(env.osName, maxOsName),
            osVersion: env.osVersion.isEmpty ? nil : truncate(env.osVersion, maxOsVersion),
            appVersion: env.appVersion.isEmpty ? nil : truncate(env.appVersion, maxAppVersion),
            sdkVersion: truncate(sdkVersion, maxSdkVersion),
            severity: severity,
            kind: kind,
            isDebug: env.isDebug
        )
    }

    private static func truncate(_ value: String, _ maxLength: Int) -> String {
        guard value.count > maxLength else {
            return value
        }

        return String(value.prefix(maxLength))
    }
}
