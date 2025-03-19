import XCTest
@testable import Models

final class YaleLockAdapterTests: XCTestCase {
    var adapter: YaleLockAdapter!
    var mockNetworkService: MockNetworkService!
    var mockSecurityService: MockSecurityService!
    var mockAuditLogger: MockAuditLogger!
    var mockKeychainHelper: MockKeychainHelper!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        mockSecurityService = MockSecurityService()
        mockAuditLogger = MockAuditLogger()
        mockKeychainHelper = MockKeychainHelper()
        
        adapter = YaleLockAdapter(
            networkService: mockNetworkService,
            securityService: mockSecurityService,
            auditLogger: mockAuditLogger
        )
    }
    
    override func tearDown() {
        adapter = nil
        mockNetworkService = nil
        mockSecurityService = nil
        mockAuditLogger = nil
        mockKeychainHelper = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithValidToken() throws {
        let token = "valid-token"
        try adapter.initialize(with: token)
        
        // Verify token is stored
        let fetchedToken = try await adapter.getValidToken()
        XCTAssertEqual(fetchedToken, token)
    }
    
    // MARK: - Fetch Locks Tests
    
    func testFetchLocksSuccess() async throws {
        // Setup mock response
        let mockLocks = [
            YaleLockResponse(
                deviceId: "lock1",
                deviceName: "Front Door",
                deviceStatus: "locked",
                batteryLevel: 85,
                deviceMetadata: YaleLockResponse.YaleLockMetadata(
                    lastUpdated: ISO8601DateFormatter().string(from: Date()),
                    remoteOperationEnabled: true,
                    model: "Yale Assure Lock",
                    firmwareVersion: "1.0.0"
                )
            )
        ]
        
        mockNetworkService.mockResponse = mockLocks
        
        // Execute
        let locks = try await adapter.fetchLocks()
        
        // Verify
        XCTAssertEqual(locks.count, 1)
        XCTAssertEqual(locks[0].id, "lock1")
        XCTAssertEqual(locks[0].name, "Front Door")
        XCTAssertEqual(locks[0].currentState, .locked)
        XCTAssertEqual(locks[0].batteryLevel, 85)
        
        // Verify audit logging
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 2)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, "fetch_locks")
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].status, .started)
        XCTAssertEqual(mockAuditLogger.loggedEvents[1].status, .success)
    }
    
    func testFetchLocksNetworkError() async {
        // Setup mock error
        mockNetworkService.mockError = URLError(.notConnectedToInternet)
        
        // Execute and verify
        do {
            _ = try await adapter.fetchLocks()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? LockError, .networkError)
        }
        
        // Verify audit logging
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 2)
        XCTAssertEqual(mockAuditLogger.loggedEvents[1].status, .failed)
    }
    
    // MARK: - Control Lock Tests
    
    func testControlLockSuccess() async throws {
        // Setup
        let lockId = "lock1"
        let operation = LockOperation.lock
        
        // Execute
        try await adapter.controlLock(id: lockId, operation: operation)
        
        // Verify
        XCTAssertEqual(mockNetworkService.lastRequest?.endpoint, "\(YaleConfiguration.shared.baseURL)/devices/\(lockId)/control")
        XCTAssertEqual(mockNetworkService.lastRequest?.method, .post)
        
        // Verify audit logging
        XCTAssertEqual(mockAuditLogger.loggedEvents.count, 2)
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].action, "control_lock")
        XCTAssertEqual(mockAuditLogger.loggedEvents[0].status, .started)
        XCTAssertEqual(mockAuditLogger.loggedEvents[1].status, .success)
    }
    
    func testControlLockInvalidId() async {
        // Setup
        let invalidId = "invalid"
        let operation = LockOperation.lock
        
        // Execute and verify
        do {
            try await adapter.controlLock(id: invalidId, operation: operation)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? LockOperationError, .invalidLockId)
        }
    }
    
    // MARK: - Security Tests
    
    func testCertificateValidation() {
        // Setup
        let mockServerTrust = MockSecTrust()
        
        // Execute
        let isValid = adapter.validateCertificate(mockServerTrust)
        
        // Verify
        XCTAssertTrue(isValid)
    }
    
    func testRateLimiting() async throws {
        // Setup
        let lockId = "lock1"
        let operation = LockOperation.lock
        
        // Execute multiple requests in quick succession
        try await adapter.controlLock(id: lockId, operation: operation)
        try await adapter.controlLock(id: lockId, operation: operation)
        
        // Verify
        XCTAssertGreaterThanOrEqual(
            mockNetworkService.lastRequest!.timestamp.timeIntervalSince(mockNetworkService.requests[0].timestamp),
            0.5 // minRequestInterval
        )
    }
    
    // MARK: - Mock Classes
    
    class MockNetworkService: NetworkServiceProtocol {
        var mockResponse: Any?
        var mockError: Error?
        var requests: [(endpoint: String, method: HTTPMethod, timestamp: Date)] = []
        var lastRequest: (endpoint: String, method: HTTPMethod, timestamp: Date)?
        
        func request<T: Decodable>(
            endpoint: String,
            method: HTTPMethod = .get,
            token: String? = nil,
            body: [String: Any]? = nil,
            headers: [String: String]? = nil,
            certificateValidation: ((SecTrust) -> Bool)? = nil
        ) async throws -> T {
            let timestamp = Date()
            requests.append((endpoint, method, timestamp))
            lastRequest = (endpoint, method, timestamp)
            
            if let error = mockError {
                throw error
            }
            
            guard let response = mockResponse as? T else {
                throw LockOperationError.operationFailed("Invalid response type")
            }
            
            return response
        }
    }
    
    class MockSecurityService: SecurityServiceProtocol {
        func validateCertificate(_ serverTrust: SecTrust) -> Bool {
            return true
        }
    }
    
    class MockAuditLogger: AuditLoggerProtocol {
        var loggedEvents: [(type: AuditEventType, action: String, status: AuditEventStatus, details: [String: Any])] = []
        
        func logEvent(type: AuditEventType, action: String, status: AuditEventStatus, details: [String: Any]) {
            loggedEvents.append((type, action, status, details))
        }
    }
    
    class MockKeychainHelper: KeychainHelper {
        var storedItems: [String: Data] = [:]
        
        override func save(_ data: Data, service: String, account: String) throws {
            storedItems["\(service):\(account)"] = data
        }
        
        override func get(service: String, account: String) throws -> Data? {
            return storedItems["\(service):\(account)"]
        }
        
        override func delete(service: String, account: String) throws {
            storedItems.removeValue(forKey: "\(service):\(account)")
        }
    }
    
    class MockSecTrust: SecTrust {
        override var certificateCount: Int {
            return 1
        }
        
        override func certificate(at index: Int) -> SecCertificate? {
            return nil
        }
    }
} 