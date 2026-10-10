import Foundation
import PoliticalFactCheckCore

public struct OpenAINarrationProvider: NarrationProvider {
    public static let defaultModel = "gpt-realtime-2.1-mini"
    public let model: String
    public var identifier: NonEmptyText { try! NonEmptyText("openai-audio-speech") }
    private let session: URLSession
    private let environment: (String) -> String?
    private let timeoutSeconds: Double
    private let maxResponseBytes: Int
    public init(model: String = OpenAINarrationProvider.defaultModel, session: URLSession = .init(configuration: .ephemeral),
                timeoutSeconds: Double = 60, maxResponseBytes: Int = NarrationLimits.sceneBytes,
                environment: @escaping (String) -> String? = { ProcessInfo.processInfo.environment[$0] }) {
        self.model = model; self.session = session; self.timeoutSeconds = timeoutSeconds
        self.maxResponseBytes = maxResponseBytes; self.environment = environment
    }
    /// No domain IDs/metadata or local paths enter this body. Model stays a configurable string.
    func makeRequest(_ value: NarrationRequest) throws -> URLRequest {
        try value.validate()
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              timeoutSeconds.isFinite, timeoutSeconds > 0, maxResponseBytes > 0,
              maxResponseBytes <= NarrationLimits.sceneBytes else { throw NarrationError.invalidRequest }
        guard let key = environment("OPENAI_API_KEY"), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw NarrationError.missingAPIKey }
        guard !key.contains("\r"), !key.contains("\n") else { throw NarrationError.invalidRequest }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!,
            cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "voice": value.voice.rawValue,
            "input": value.text, "response_format": value.format.rawValue, "speed": value.speed,
            "instructions": value.instructions], options: [.sortedKeys])
        return request
    }
    public func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        try Task.checkCancellation()
        let value = try makeRequest(request)
        let receiver = BoundedSpeechDownload(limit: maxResponseBytes)
        let result = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                receiver.start(request: value, configuration: session.configuration, continuation: continuation)
            }
        }, onCancel: { receiver.cancel() })
        try Task.checkCancellation()
        try WAVInspection.requireHeader(result.0)
        return NarrationAudio(bytes: result.0, contentType: result.1.mimeType)
    }
}

/// Owns one concrete download, enforcing limits before appending any received chunk.
/// Lock protects URLSession delegate callbacks and cancellation from different executors.
private final class BoundedSpeechDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var bytes = Data()
    private var response: HTTPURLResponse?
    private var failure: NarrationError?
    private var cancelled = false
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    init(limit: Int) { self.limit = limit }
    func start(request: URLRequest, configuration: URLSessionConfiguration,
               continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>) {
        lock.lock()
        if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: request); self.task = task
        lock.unlock(); task.resume()
    }
    func cancel() {
        lock.lock(); cancelled = true; let task = task; lock.unlock()
        task?.cancel()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock()
        if let http = response as? HTTPURLResponse {
            self.response = http
            switch http.statusCode {
            case 200...299: break
            case 401: failure = .authenticationFailed
            case 403: failure = .permissionDenied
            case 408: failure = .timeout
            case 429: failure = .rateLimited
            case 500...599: failure = .serviceUnavailable
            default: failure = .badRequest
            }
            if failure == nil && response.expectedContentLength > Int64(limit) { failure = .responseTooLarge }
        } else { failure = .nonAudioResponse }
        let allowed = failure == nil && !cancelled
        lock.unlock(); completionHandler(allowed ? .allow : .cancel)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let stop = cancelled || failure != nil || data.count > limit - bytes.count
        if !stop { bytes.append(data) }
        else if !cancelled && failure == nil { failure = .responseTooLarge }
        lock.unlock()
        if stop { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = self.continuation; self.continuation = nil
        let response = response, data = bytes, failure = failure, cancelled = cancelled
        self.task = nil; self.session = nil
        lock.unlock()
        session.finishTasksAndInvalidate()
        guard let continuation else { return }
        if cancelled { continuation.resume(throwing: CancellationError()) }
        else if let failure { continuation.resume(throwing: failure) }
        else if let error = error as? URLError {
            if error.code == .cancelled { continuation.resume(throwing: CancellationError()) }
            else { continuation.resume(throwing: error.code == .timedOut ? NarrationError.timeout : NarrationError.transportFailure) }
        } else if error != nil { continuation.resume(throwing: NarrationError.transportFailure) }
        else if let response { continuation.resume(returning: (data, response)) }
        else { continuation.resume(throwing: NarrationError.nonAudioResponse) }
    }
}
