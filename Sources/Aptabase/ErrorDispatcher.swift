import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class ErrorDispatcher: PayloadDispatcher {
    let payloadQueue = ConcurrentQueue<ErrorReport>()
    let maximumBatchSize = 1
    private let headers: [String: String]
    private let apiUrl: URL
    private let session: URLSessionProtocol
    private let maximumQueueSize = 25

    init(appKey: String, baseUrl: String, env: EnvironmentInfo, session: URLSessionProtocol = URLSession.shared) {
        self.session = session
        apiUrl = URL(string: "\(baseUrl)/api/v0/error")!
        headers = [
            "Content-Type": "application/json",
            "App-Key": appKey,
            "User-Agent": "\(env.osName)/\(env.osVersion) \(env.locale)"
        ]
    }

    func enqueue(_ report: ErrorReport) {
        if payloadQueue.count >= maximumQueueSize {
            debugPrint("Aptabase: Error report queue is full. Dropping report.")
            return
        }

        payloadQueue.enqueue(report)
    }

    func send(_ payloads: [ErrorReport]) async throws {
        guard let report = payloads.first else {
            return
        }

        do {
            let body = try encoder.encode(report)

            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = body

            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode < 300 {
                return true
            }

            let responseText = String(data: data, encoding: .utf8) ?? ""
            let reason = "\(statusCode) \(responseText)"
            if statusCode == 403 {
                debugPrint("Aptabase: Error report rejected because of \(reason). Will not retry.")
                return
            }

            if statusCode == 408 || statusCode == 429 || statusCode >= 500 {
                debugPrint("Aptabase: Failed to send error report because of \(reason). Will retry later.")
                throw NSError(domain: "AptabaseError", code: statusCode, userInfo: ["reason": reason])
            }

            debugPrint("Aptabase: Failed to send error report because of \(reason). Will not retry.")
            return
        } catch {
            debugPrint("Aptabase: Failed to send error report. Reason: \(error)")
            throw error
        }
    }

    private var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "UTC")
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }()
}
