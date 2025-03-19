import XCTest
import LocalAuthentication
@testable import Models

final class BiometricAuthenticationTests: XCTestCase {
    var securityService: SecurityService!
    
    override func setUp() {
        super.setUp()
        securityService = SecurityService()
        
        // Mock the BiometricAuthentication for testing
        BiometricAuthenticationMock.mockResult = .success
    }
    
    override func tearDown() {
        BiometricAuthenticationMock.mockResult = nil
        securityService = nil
        super.tearDown()
    }
    
    // MARK: - Biometric Tests
    
    func testBiometricAuthenticationSuccess() async {
        BiometricAuthenticationMock.mockResult = .success
        
        let testValue = "success"
        do {
            // Verify that the operation is performed after successful authentication
            let result = try await securityService.authenticateAndPerform("Test authentication") {
                return testValue
            }
            XCTAssertEqual(result, testValue, "Operation should be performed after successful authentication")
        } catch {
            XCTFail("No error should be thrown for successful authentication: \(error)")
        }
    }
    
    func testBiometricAuthenticationCanceled() async {
        BiometricAuthenticationMock.mockResult = .canceled
        
        do {
            // Verify that we get an authentication canceled error
            _ = try await securityService.authenticateAndPerform("Test authentication") {
                return "This should not be reached"
            }
            XCTFail("Operation should not be performed for canceled authentication")
        } catch let error as SecurityError {
            XCTAssertEqual(error, SecurityError.authenticationCanceled, "Should throw authentication canceled error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testBiometricAuthenticationFallback() async {
        BiometricAuthenticationMock.mockResult = .fallback
        
        do {
            // Verify that we get an authentication fallback error
            _ = try await securityService.authenticateAndPerform("Test authentication") {
                return "This should not be reached"
            }
            XCTFail("Operation should not be performed for fallback authentication")
        } catch let error as SecurityError {
            XCTAssertEqual(error, SecurityError.authenticationFallback, "Should throw authentication fallback error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testBiometricAuthenticationFailed() async {
        BiometricAuthenticationMock.mockResult = .failed
        
        do {
            // Verify that we get an authentication failed error
            _ = try await securityService.authenticateAndPerform("Test authentication") {
                return "This should not be reached"
            }
            XCTFail("Operation should not be performed for failed authentication")
        } catch let error as SecurityError {
            XCTAssertEqual(error, SecurityError.authenticationFailed, "Should throw authentication failed error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testBiometricAuthenticationNotAvailable() async {
        BiometricAuthenticationMock.mockResult = .notAvailable
        
        do {
            // Verify that we get an authentication failed error for not available
            _ = try await securityService.authenticateAndPerform("Test authentication") {
                return "This should not be reached"
            }
            XCTFail("Operation should not be performed when biometrics not available")
        } catch let error as SecurityError {
            XCTAssertEqual(error, SecurityError.authenticationFailed, "Should throw authentication failed error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAsyncOperation() async {
        BiometricAuthenticationMock.mockResult = .success
        
        let testValue = "async success"
        do {
            // Verify that the async operation is performed after successful authentication
            let result = try await securityService.authenticateAndPerform("Test authentication") async {
                // Simulate async work
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return testValue
            }
            XCTAssertEqual(result, testValue, "Async operation should be performed after successful authentication")
        } catch {
            XCTFail("No error should be thrown for successful authentication: \(error)")
        }
    }
    
    func testYaleLockAdapterIntegration() async {
        BiometricAuthenticationMock.mockResult = .success
        
        let adapter = YaleLockAdapter(
            networkService: MockNetworkService(),
            securityService: securityService,
            auditLogger: AuditLogger()
        )
        
        do {
            // Mock the network service
            (adapter.networkService as! MockNetworkService).mockResponse = EmptyResponse()
            
            // This operation should require biometric authentication
            try await adapter.controlLock(id: "valid-lock-id", operation: .unlock)
            
            // If we get here, authentication passed and the operation completed
            XCTAssertTrue(true, "Unlock operation with biometric authentication should succeed")
        } catch {
            XCTFail("No error should be thrown for successful authentication: \(error)")
        }
    }
    
    func testYaleLockAdapterWithFailedAuthentication() async {
        BiometricAuthenticationMock.mockResult = .failed
        
        let adapter = YaleLockAdapter(
            networkService: MockNetworkService(),
            securityService: securityService,
            auditLogger: AuditLogger()
        )
        
        do {
            // Mock the network service
            (adapter.networkService as! MockNetworkService).mockResponse = EmptyResponse()
            
            // This operation should fail due to failed biometric authentication
            try await adapter.controlLock(id: "valid-lock-id", operation: .unlock)
            
            XCTFail("Unlock operation should fail with failed authentication")
        } catch let error as SecurityError {
            XCTAssertEqual(error, SecurityError.authenticationFailed, "Should throw authentication failed error")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Mock Classes
    
    class MockNetworkService: NetworkServiceProtocol {
        var mockResponse: Any?
        var mockError: Error?
        
        func request<T: Decodable>(
            endpoint: String,
            method: HTTPMethod = .get,
            token: String? = nil,
            body: [String: Any]? = nil,
            headers: [String: String]? = nil,
            certificateValidation: ((SecTrust) -> Bool)? = nil
        ) async throws -> T {
            if let error = mockError {
                throw error
            }
            
            guard let response = mockResponse as? T else {
                throw SecurityError.authenticationFailed
            }
            
            return response
        }
    }
}

// MARK: - BiometricAuthentication Mock for Testing

class BiometricAuthenticationMock: BiometricAuthentication {
    static var mockResult: BiometricResult?
    
    static override func authenticate(
        reason: String,
        fallbackTitle: String? = nil
    ) async -> BiometricResult {
        return mockResult ?? .success
    }
}

// Helper class to make SecurityError equatable for testing
extension SecurityError: Equatable {
    public static func == (lhs: SecurityError, rhs: SecurityError) -> Bool {
        switch (lhs, rhs) {
        case (.deviceCompromised, .deviceCompromised):
            return true
        case (.authenticationFailed, .authenticationFailed),
             (.authenticationCanceled, .authenticationCanceled),
             (.authenticationFallback, .authenticationFallback):
            return true
        default:
            return false
        }
    }
} 