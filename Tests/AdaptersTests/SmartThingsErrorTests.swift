import XCTest
@testable import UnifiedSmartHome

final class SmartThingsErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testErrorDescriptions() {
        XCTAssertEqual(SmartThingsError.invalidCredentials.errorDescription, "Invalid SmartThings credentials")
        XCTAssertEqual(SmartThingsError.tokenExpired.errorDescription, "Authentication token has expired")
        XCTAssertEqual(SmartThingsError.deviceNotFound("device-123").errorDescription, "Device not found: device-123")
        XCTAssertEqual(SmartThingsError.rateLimitExceeded.errorDescription, "Rate limit exceeded")
    }
    
    // MARK: - Recovery Suggestion Tests
    
    func testRecoverySuggestions() {
        XCTAssertEqual(SmartThingsError.invalidCredentials.recoverySuggestion, "Please check your SmartThings credentials and try again")
        XCTAssertEqual(SmartThingsError.tokenExpired.recoverySuggestion, "Please log in again to refresh your authentication")
        XCTAssertEqual(SmartThingsError.deviceNotFound("device-123").recoverySuggestion, "Please verify the device ID and try again")
        XCTAssertEqual(SmartThingsError.rateLimitExceeded.recoverySuggestion, "Please wait a few minutes before trying again")
    }
    
    // MARK: - Recoverability Tests
    
    func testErrorRecoverability() {
        // Recoverable errors
        XCTAssertTrue(SmartThingsError.tokenExpired.isRecoverable)
        XCTAssertTrue(SmartThingsError.rateLimitExceeded.isRecoverable)
        XCTAssertTrue(SmartThingsError.deviceBusy("device-123").isRecoverable)
        XCTAssertTrue(SmartThingsError.timeout.isRecoverable)
        
        // Non-recoverable errors
        XCTAssertFalse(SmartThingsError.invalidCredentials.isRecoverable)
        XCTAssertFalse(SmartThingsError.unauthorized.isRecoverable)
        XCTAssertFalse(SmartThingsError.deviceNotFound("device-123").isRecoverable)
        XCTAssertFalse(SmartThingsError.invalidCommand("command").isRecoverable)
    }
    
    // MARK: - Retry Delay Tests
    
    func testRetryDelays() {
        XCTAssertEqual(SmartThingsError.rateLimitExceeded.retryDelay, 60)
        XCTAssertEqual(SmartThingsError.deviceBusy("device-123").retryDelay, 5)
        XCTAssertEqual(SmartThingsError.timeout.retryDelay, 2)
        XCTAssertEqual(SmartThingsError.tokenExpired.retryDelay, 1)
        XCTAssertEqual(SmartThingsError.invalidCredentials.retryDelay, 0)
    }
}

// MARK: - Retry Handler Tests

final class SmartThingsRetryHandlerTests: XCTestCase {
    var retryHandler: SmartThingsRetryHandler!
    
    override func setUp() {
        super.setUp()
        retryHandler = SmartThingsRetryHandler(
            maxRetries: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            jitter: 0.1
        )
    }
    
    override func tearDown() {
        retryHandler = nil
        super.tearDown()
    }
    
    func testSuccessfulOperation() async throws {
        var attempts = 0
        let result = try await retryHandler.execute {
            attempts += 1
            return "success"
        }
        
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 1)
    }
    
    func testRecoverableError() async throws {
        var attempts = 0
        let result = try await retryHandler.execute {
            attempts += 1
            if attempts == 1 {
                throw SmartThingsError.deviceBusy("device-123")
            }
            return "success"
        }
        
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 2)
    }
    
    func testNonRecoverableError() async throws {
        var attempts = 0
        do {
            _ = try await retryHandler.execute {
                attempts += 1
                throw SmartThingsError.invalidCredentials
            }
            XCTFail("Should have thrown an error")
        } catch SmartThingsError.invalidCredentials {
            XCTAssertEqual(attempts, 1)
        }
    }
    
    func testMaxRetriesExceeded() async throws {
        var attempts = 0
        do {
            _ = try await retryHandler.execute {
                attempts += 1
                throw SmartThingsError.deviceBusy("device-123")
            }
            XCTFail("Should have thrown an error")
        } catch SmartThingsError.deviceBusy {
            XCTAssertEqual(attempts, 4) // Initial attempt + 3 retries
        }
    }
    
    func testExponentialBackoff() async throws {
        var lastDelay: TimeInterval = 0
        var attempts = 0
        
        do {
            _ = try await retryHandler.execute {
                attempts += 1
                if attempts > 1 {
                    let currentDelay = Date().timeIntervalSince1970 - lastDelay
                    XCTAssertGreaterThan(currentDelay, lastDelay)
                }
                lastDelay = Date().timeIntervalSince1970
                throw SmartThingsError.deviceBusy("device-123")
            }
            XCTFail("Should have thrown an error")
        } catch SmartThingsError.deviceBusy {
            XCTAssertEqual(attempts, 4)
        }
    }
    
    func testJitterInDelay() async throws {
        var delays: [TimeInterval] = []
        var attempts = 0
        
        do {
            _ = try await retryHandler.execute {
                attempts += 1
                let start = Date()
                throw SmartThingsError.deviceBusy("device-123")
            }
            XCTFail("Should have thrown an error")
        } catch SmartThingsError.deviceBusy {
            XCTAssertEqual(attempts, 4)
        }
        
        // Verify that delays are not identical (jitter is working)
        let uniqueDelays = Set(delays)
        XCTAssertGreaterThan(uniqueDelays.count, 1)
    }
} 