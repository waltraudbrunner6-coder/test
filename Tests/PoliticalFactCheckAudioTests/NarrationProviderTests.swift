import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckAudio

final class NarrationProviderTests: XCTestCase {
    override func tearDown() { SpeechHTTPStub.reset(); super.tearDown() }
    private func provider(model: String = OpenAINarrationProvider.defaultModel, limit: Int = NarrationLimits.sceneBytes,
                          key: String? = "test-key-not-real") -> OpenAINarrationProvider {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SpeechHTTPStub.self]
        return OpenAINarrationProvider(model: model, session: URLSession(configuration: config),
            maxResponseBytes: limit, environment: { _ in key })
    }
    func testEndpointMethodAuthorizationAndContentType() throws {
        let request = try provider().makeRequest(audioRequest())
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/audio/speech")
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key-not-real")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    func testBodyContainsOnlyExactNarrationAndTechnicalParameters() throws {
        let value = "  Synthetic text, 12.5 and proper punctuation!\nSecond line. "
        let request = try provider().makeRequest(audioRequest(value))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["model", "voice", "input", "response_format", "speed", "instructions"])
        XCTAssertEqual(body["input"] as? String, value); XCTAssertEqual(body["model"] as? String, "gpt-realtime-2.1-mini")
        XCTAssertEqual(body["voice"] as? String, "marin"); XCTAssertEqual(body["response_format"] as? String, "wav")
        XCTAssertEqual(body["speed"] as? Double, 1); XCTAssertEqual(body["instructions"] as? String, try NarrationStyleV1.instructions())
        XCTAssertEqual(SpeechHTTPStub.requests, 0)
    }
    func testModelIsConfigurableStringWithoutDeprecatedFallback() throws {
        let request = try provider(model: "synthetic-future-model-name").makeRequest(audioRequest())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "synthetic-future-model-name")
    }
    func testAllSupportedVoicesRemainBuiltinAndSpeedIsExplicit() throws {
        for voice in BuiltinNarrationVoice.allCases {
            let value = try audioRequest()
            let request = NarrationRequest(scenePosition: 0, statementID: value.statementID, text: value.text,
                voice: voice, speed: 1.1, instructions: value.instructions)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(provider().makeRequest(request).httpBody)) as? [String: Any])
            XCTAssertEqual(body["voice"] as? String, voice.rawValue); XCTAssertEqual(body["speed"] as? Double, 1.1)
        }
    }
    func testStyleResourceIsByteIdenticalToVersionedDocument() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(Data(try NarrationStyleV1.instructions().utf8), try Data(contentsOf: root.appendingPathComponent("docs/narration-style-v1.md")))
    }
    func testCaseSpecificInstructionsCannotReplaceStaticStyle() throws {
        let base = try audioRequest(), request = NarrationRequest(scenePosition: 0, statementID: base.statementID,
            text: base.text, instructions: "Synthetic forbidden case-specific instruction")
        XCTAssertThrowsError(try provider().makeRequest(request)) { XCTAssertEqual($0 as? NarrationError, .invalidRequest) }
    }
    func testInvalidSpeedAndBlankInputBlockBeforeNetworking() throws {
        let base = try audioRequest()
        for speed in [Double.nan, 0, 1.8] {
            XCTAssertThrowsError(try provider().makeRequest(NarrationRequest(scenePosition: 0, statementID: base.statementID,
                text: base.text, speed: speed, instructions: base.instructions)))
        }
        XCTAssertThrowsError(try provider().makeRequest(audioRequest(" \n ")))
        XCTAssertEqual(SpeechHTTPStub.requests, 0)
    }
    func testMissingKeyDoesNotSend() async throws {
        do { _ = try await provider(key: nil).synthesize(request: audioRequest()); XCTFail("Missing key accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .missingAPIKey) }
        XCTAssertEqual(SpeechHTTPStub.requests, 0)
    }
    func testHTTP400IsControlledWithoutFallback() async throws { try await httpFailure(400, .badRequest) }
    func testHTTP401IsControlled() async throws { try await httpFailure(401, .authenticationFailed) }
    func testHTTP403IsControlled() async throws { try await httpFailure(403, .permissionDenied) }
    func testHTTP408IsTimeout() async throws { try await httpFailure(408, .timeout) }
    func testHTTP429IsRateLimit() async throws { try await httpFailure(429, .rateLimited) }
    func testHTTP500IsServiceFailure() async throws { try await httpFailure(500, .serviceUnavailable) }
    private func httpFailure(_ status: Int, _ expected: NarrationError) async throws {
        SpeechHTTPStub.status = status; SpeechHTTPStub.body = Data("SYNTHETIC PRIVATE ERROR test-key-not-real".utf8)
        do { _ = try await provider().synthesize(request: audioRequest()); XCTFail("HTTP error accepted") }
        catch { XCTAssertEqual(error as? NarrationError, expected); XCTAssertFalse(String(describing: error).contains("PRIVATE ERROR")) }
        XCTAssertEqual(SpeechHTTPStub.requests, 1)
    }
    func testTimeoutIsControlled() async throws { try await transportFailure(.timedOut, .timeout) }
    func testTransportFailureIsControlled() async throws { try await transportFailure(.notConnectedToInternet, .transportFailure) }
    private func transportFailure(_ code: URLError.Code, _ expected: NarrationError) async throws {
        SpeechHTTPStub.failure = URLError(code)
        do { _ = try await provider().synthesize(request: audioRequest()); XCTFail("Transport error accepted") }
        catch { XCTAssertEqual(error as? NarrationError, expected) }
    }
    func testTransportCancellationPropagates() async throws {
        SpeechHTTPStub.failure = URLError(.cancelled)
        do { _ = try await provider().synthesize(request: audioRequest()); XCTFail("Cancellation accepted") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testCancelledTaskNeverStartsRequest() async throws {
        let task = Task { () -> NarrationAudio in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await provider().synthesize(request: audioRequest())
        }
        do { _ = try await task.value; XCTFail("Cancelled task completed") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(SpeechHTTPStub.requests, 0)
    }
    func testCancellationCancelsActiveHTTPDataTask() async throws {
        let started = expectation(description: "Offline HTTP request started")
        let stopped = expectation(description: "Active URLProtocol stopped")
        SpeechHTTPStub.hold = true; SpeechHTTPStub.started = { started.fulfill() }
        SpeechHTTPStub.stopped = { stopped.fulfill() }
        let task = Task { try await provider().synthesize(request: audioRequest()) }
        await fulfillment(of: [started], timeout: 5); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled HTTP request completed") }
        catch { XCTAssertTrue(error is CancellationError) }
        await fulfillment(of: [stopped], timeout: 5)
        XCTAssertEqual(SpeechHTTPStub.requests, 1); XCTAssertEqual(SpeechHTTPStub.stops, 1)
    }
    func testEmptyBodyIsControlled() async throws { try await bodyFailure(Data(), .emptyResponse) }
    func testNonAudioJSONBodyIsControlled() async throws { try await bodyFailure(Data("{\"message\":\"synthetic\"}".utf8), .nonAudioResponse) }
    func testCorruptRIFFContainerIsControlled() async throws { try await bodyFailure(Data("RIFF0000WAVEsynthetic corruption".utf8), .corruptWAV) }
    private func bodyFailure(_ bytes: Data, _ expected: NarrationError) async throws {
        SpeechHTTPStub.body = bytes
        do { _ = try await provider().synthesize(request: audioRequest()); XCTFail("Invalid audio accepted") }
        catch { XCTAssertEqual(error as? NarrationError, expected) }
    }
    func testStreamingLimitRejectsBodyWithoutContentLength() async throws {
        SpeechHTTPStub.body = Data(repeating: 0, count: 2048)
        do { _ = try await provider(limit: 1024).synthesize(request: audioRequest()); XCTFail("Unbounded audio accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .responseTooLarge) }
    }
    func testAdvertisedOversizedBodyIsRejected() async throws {
        SpeechHTTPStub.headers = ["Content-Length": "999999999"]
        do { _ = try await provider().synthesize(request: audioRequest()); XCTFail("Oversized length accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .responseTooLarge) }
    }
    func testCumulativeStreamingChunksCannotExceedLimit() async throws {
        SpeechHTTPStub.body = Data(repeating: 0, count: 2048); SpeechHTTPStub.chunkSize = 512
        do { _ = try await provider(limit: 1024).synthesize(request: audioRequest()); XCTFail("Cumulative oversize accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .responseTooLarge) }
    }
    func testValidHTTPAudioHasExactBytes() async throws {
        SpeechHTTPStub.body = try FakeNarrationProvider.wav(durationSeconds: 0.5)
        let audio = try await provider().synthesize(request: audioRequest())
        XCTAssertEqual(audio.bytes, SpeechHTTPStub.body); XCTAssertEqual(audio.format, .wav)
    }
}

private final class SpeechHTTPStub: URLProtocol {
    static var status = 200
    static var body = Data()
    static var failure: URLError?
    static var headers: [String: String] = ["Content-Type": "audio/wav"]
    static var requests = 0
    static var hold = false, stops = 0
    static var started: (() -> Void)?
    static var stopped: (() -> Void)?
    static var chunkSize: Int?
    static func reset() {
        status = 200; body = Data(); failure = nil; headers = ["Content-Type": "audio/wav"]; requests = 0
        hold = false; stops = 0; started = nil; stopped = nil; chunkSize = nil
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        if Self.hold { Self.started?(); return }
        if let error = Self.failure { client?.urlProtocol(self, didFailWithError: error); return }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: Self.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let size = Self.chunkSize {
            for start in stride(from: 0, to: Self.body.count, by: size) {
                client?.urlProtocol(self, didLoad: Self.body.subdata(in: start..<min(start + size, Self.body.count)))
            }
        } else { client?.urlProtocol(self, didLoad: Self.body) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { Self.stops += 1; Self.stopped?() }
}
