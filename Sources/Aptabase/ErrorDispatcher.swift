import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class ErrorDispatcher {
    private var reports = ConcurrentQueue<ErrorReport>()
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
        if reports.count >= maximumQueueSize {
            debugPrint("Aptabase: Error report queue is full. Dropping report.")
            return
        }

        reports.enqueue(report)
    }

    func flush() async {
        if reports.isEmpty {
            return
        }

        var failedReports: [ErrorReport] = []
        while !reports.isEmpty {
            guard let report = reports.dequeue() else {
                continue
            }

            let settled = await sendReport(report)
            if !settled {
                failedReports.append(report)
            }
        }

        if !failedReports.isEmpty {
            reports.enqueue(contentsOf: failedReports)
        }
    }

    private func sendReport(_ report: ErrorReport) async -> Bool {
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
                return true
            }

            if statusCode == 408 || statusCode == 429 || statusCode >= 500 {
                debugPrint("Aptabase: Failed to send error report because of \(reason). Will retry later.")
                return false
            }

            debugPrint("Aptabase: Failed to send error report because of \(reason). Will not retry.")
            return true
        } catch {
            debugPrint("Aptabase: Failed to send error report. Reason: \(error)")
            return false
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
