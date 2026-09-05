import Foundation

protocol PayloadDispatcher: AnyObject {
    associatedtype Payload: Encodable

    var payloadQueue: ConcurrentQueue<Payload> { get }
    var maximumBatchSize: Int { get }

    func send(_ payloads: [Payload]) async throws
}

extension PayloadDispatcher {
    func enqueue(_ payload: Payload) {
        payloadQueue.enqueue(payload)
    }

    func enqueue(_ payloads: [Payload]) {
        payloadQueue.enqueue(contentsOf: payloads)
    }

    func flush() async {
        if payloadQueue.isEmpty {
            return
        }

        var failedPayloads: [Payload] = []
        while !payloadQueue.isEmpty {
            let payloadsToSend = payloadQueue.dequeue(count: maximumBatchSize)
            do {
                try await send(payloadsToSend)
            } catch {
                failedPayloads.append(contentsOf: payloadsToSend)
            }
        }

        if !failedPayloads.isEmpty {
            enqueue(failedPayloads)
        }
    }
}
