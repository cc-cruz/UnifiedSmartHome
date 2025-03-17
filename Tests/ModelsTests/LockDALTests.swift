import XCTest
@testable import Models

// Mock classes for testing
class MockLockAdapter: LockAdapter {
    var locks: [LockDevice] = []
    var lockOperationCalled = false
    var unlockOperationCalled = false
    var getStatusCalled = false
    var lastCommandId: String?
    var lastCommand: LockCommand?
    var shouldThrowError = false
    
    func initialize(with authToken: String) throws {}
    
    func fetchLocks() async throws -> [LockDevice] {
        return locks
    }
    
    func getLockStatus(id: String) async throws -> LockDevice {
        getStatusCalled = true
        lastCommandId = id
        
        if shouldThrowError {
            throw LockOperationError.networkError
        }
        
        guard let lock = locks.first(where: { $0.id == id }) else {
            throw LockOperationError.operationFailed("Lock not found")
        }
        
        return lock
    }
    
    func controlLock(id: String, command: LockCommand) async throws -> LockDevice.LockState {
        lastCommandId = id
        lastCommand = command
        
        if shouldThrowError {
            throw LockOperationError.networkError
        }
        
        if command == .lock {
            lockOperationCalled = true
            return .locked
        } else {
            unlockOperationCalled = true
            return .unlocked
        }
    }
}

class MockSecurityService: SecurityService {
    var validateCalled = false
    var lastDeviceId: String?
    var lastUserId: String?
    var lastOperation: LockOperation?
    var shouldThrowError = false
    
    override func validateLockOperation(deviceId: String, userId: String, operation: LockOperation) async throws {
        validateCalled = true
        lastDeviceId = deviceId
        lastUserId = userId
        lastOperation = operation
        
        if shouldThrowError {
            throw SecurityError.permissionDenied
        }
    }
}

class MockAuditLogger: AuditLogger {
    var logOperationCalled = false
    var logResultCalled = false
    var lastOperationType: String?
    var lastDetails: [String: String]?
    var lastSuccess: Bool?
    
    override func logSensitiveOperation(type: String, details: [String: String]) {
        logOperationCalled = true
        lastOperationType = type
        lastDetails = details
    }
    
    override func logOperationResult(type: String, success: Bool, details: [String: String]) {
        logResultCalled = true
        lastOperationType = type
        lastSuccess = success
        lastDetails = details
    }
}

final class LockDALTests: XCTestCase {
    var lockDAL: LockDAL!
    var mockAdapter: MockLockAdapter!
    var mockSecurityService: MockSecurityService!
    var mockAuditLogger: MockAuditLogger!
    var testLock: LockDevice!
    
    override func setUp() {
        super.setUp()
        
        // Create test lock
        testLock = LockDevice(
            id: "test-lock-id",
            name: "Test Lock",
            room: "Living Room",
            manufacturer: "August",
            model: "Smart Lock Pro",
            firmwareVersion: "1.0.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: ["propertyId": "property-123"],
            currentState: .locked,
            batteryLevel: 80,
            lastStateChange: Date(),
            isRemoteOperationEnabled: true,
            accessHistory: []
        )
        
        // Setup mocks
        mockAdapter = MockLockAdapter()
        mockAdapter.locks = [testLock]
        
        mockSecurityService = MockSecurityService()
        mockAuditLogger = MockAuditLogger()
        
        // Create LockDAL with mocks
        lockDAL = LockDAL(
            lockAdapter: mockAdapter,
            securityService: mockSecurityService,
            auditLogger: mockAuditLogger
        )
    }
    
    override func tearDown() {
        lockDAL = nil
        mockAdapter = nil
        mockSecurityService = nil
        mockAuditLogger = nil
        testLock = nil
        super.tearDown()
    }
    
    // MARK: - Lock Operation Tests
    
    func testLockOperation_Success() async throws {
        // Perform lock operation
        let result = try await lockDAL.lock(deviceId: "test-lock-id", userId: "test-user-id")
        
        // Verify security validation was called
        XCTAssertTrue(mockSecurityService.validateCalled)
        XCTAssertEqual(mockSecurityService.lastDeviceId, "test-lock-id")
        XCTAssertEqual(mockSecurityService.lastUserId, "test-user-id")
        XCTAssertEqual(mockSecurityService.lastOperation, .lock)
        
        // Verify audit logging was called
        XCTAssertTrue(mockAuditLogger.logOperationCalled)
        XCTAssertEqual(mockAuditLogger.lastOperationType, "lock_operation")
        XCTAssertEqual(mockAuditLogger.lastDetails?["deviceId"], "test-lock-id")
        XCTAssertEqual(mockAuditLogger.lastDetails?["userId"], "test-user-id")
        XCTAssertEqual(mockAuditLogger.lastDetails?["operation"], "lock")
        
        // Verify adapter was called
        XCTAssertTrue(mockAdapter.lockOperationCalled)
        XCTAssertEqual(mockAdapter.lastCommandId, "test-lock-id")
        XCTAssertEqual(mockAdapter.lastCommand, .lock)
        
        // Verify result
        XCTAssertEqual(result, .locked)
        
        // Verify success was logged
        XCTAssertTrue(mockAuditLogger.logResultCalled)
        XCTAssertEqual(mockAuditLogger.lastSuccess, true)
    }
    
    func testUnlockOperation_Success() async throws {
        // Perform unlock operation
        let result = try await lockDAL.unlock(deviceId: "test-lock-id", userId: "test-user-id")
        
        // Verify security validation was called
        XCTAssertTrue(mockSecurityService.validateCalled)
        XCTAssertEqual(mockSecurityService.lastDeviceId, "test-lock-id")
        XCTAssertEqual(mockSecurityService.lastUserId, "test-user-id")
        XCTAssertEqual(mockSecurityService.lastOperation, .unlock)
        
        // Verify audit logging was called
        XCTAssertTrue(mockAuditLogger.logOperationCalled)
        XCTAssertEqual(mockAuditLogger.lastOperationType, "lock_operation")
        XCTAssertEqual(mockAuditLogger.lastDetails?["deviceId"], "test-lock-id")
        XCTAssertEqual(mockAuditLogger.lastDetails?["userId"], "test-user-id")
        XCTAssertEqual(mockAuditLogger.lastDetails?["operation"], "unlock")
        
        // Verify adapter was called
        XCTAssertTrue(mockAdapter.unlockOperationCalled)
        XCTAssertEqual(mockAdapter.lastCommandId, "test-lock-id")
        XCTAssertEqual(mockAdapter.lastCommand, .unlock)
        
        // Verify result
        XCTAssertEqual(result, .unlocked)
        
        // Verify success was logged
        XCTAssertTrue(mockAuditLogger.logResultCalled)
        XCTAssertEqual(mockAuditLogger.lastSuccess, true)
    }
    
    // MARK: - Error Handling Tests
    
    func testLockOperation_SecurityError() async {
        // Setup security service to throw error
        mockSecurityService.shouldThrowError = true
        
        do {
            _ = try await lockDAL.lock(deviceId: "test-lock-id", userId: "test-user-id")
            XCTFail("Expected security error")
        } catch {
            // Verify error is thrown
            XCTAssertTrue(error is SecurityError)
            
            // Verify security validation was called
            XCTAssertTrue(mockSecurityService.validateCalled)
            
            // Verify audit logging was called
            XCTAssertTrue(mockAuditLogger.logOperationCalled)
            
            // Verify adapter was NOT called
            XCTAssertFalse(mockAdapter.lockOperationCalled)
            
            // Verify failure was logged
            XCTAssertTrue(mockAuditLogger.logResultCalled)
            XCTAssertEqual(mockAuditLogger.lastSuccess, false)
        }
    }
    
    func testLockOperation_AdapterError() async {
        // Setup adapter to throw error
        mockAdapter.shouldThrowError = true
        
        do {
            _ = try await lockDAL.lock(deviceId: "test-lock-id", userId: "test-user-id")
            XCTFail("Expected adapter error")
        } catch {
            // Verify error is thrown
            XCTAssertTrue(error is LockOperationError)
            
            // Verify security validation was called
            XCTAssertTrue(mockSecurityService.validateCalled)
            
            // Verify audit logging was called
            XCTAssertTrue(mockAuditLogger.logOperationCalled)
            
            // Verify adapter was called
            XCTAssertEqual(mockAdapter.lastCommandId, "test-lock-id")
            
            // Verify failure was logged
            XCTAssertTrue(mockAuditLogger.logResultCalled)
            XCTAssertEqual(mockAuditLogger.lastSuccess, false)
        }
    }
    
    // MARK: - Status and History Tests
    
    func testGetStatus() async throws {
        // Get lock status
        let lock = try await lockDAL.getStatus(deviceId: "test-lock-id")
        
        // Verify adapter was called
        XCTAssertTrue(mockAdapter.getStatusCalled)
        XCTAssertEqual(mockAdapter.lastCommandId, "test-lock-id")
        
        // Verify result
        XCTAssertEqual(lock.id, "test-lock-id")
    }
    
    func testGetAccessHistory() async throws {
        // Create lock with history
        let historyRecord = LockDevice.LockAccessRecord(
            timestamp: Date(),
            operation: .lock,
            userId: "test-user-id",
            success: true
        )
        
        testLock = LockDevice(
            id: "test-lock-id",
            name: "Test Lock",
            room: "Living Room",
            manufacturer: "August",
            model: "Smart Lock Pro",
            firmwareVersion: "1.0.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: ["propertyId": "property-123"],
            currentState: .locked,
            batteryLevel: 80,
            lastStateChange: Date(),
            isRemoteOperationEnabled: true,
            accessHistory: [historyRecord]
        )
        
        mockAdapter.locks = [testLock]
        
        // Get access history
        let history = try await lockDAL.getAccessHistory(deviceId: "test-lock-id", limit: 10)
        
        // Verify adapter was called
        XCTAssertTrue(mockAdapter.getStatusCalled)
        XCTAssertEqual(mockAdapter.lastCommandId, "test-lock-id")
        
        // Verify result
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].operation, .lock)
        XCTAssertEqual(history[0].userId, "test-user-id")
    }
} 