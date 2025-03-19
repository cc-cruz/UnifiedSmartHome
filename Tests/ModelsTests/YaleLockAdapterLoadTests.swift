import XCTest
@testable import Models

final class YaleLockAdapterLoadTests: XCTestCase {
    var adapter: YaleLockAdapter!
    var mockNetworkService: MockNetworkService!
    var securityService: SecurityService!
    var auditLogger: AuditLogger!
    
    override func setUp() {
        super.setUp()
        
        // Mock biometric authentication to always succeed for load testing
        BiometricAuthenticationMock.mockResult = .success
        
        // Initialize the mock network service
        mockNetworkService = MockNetworkService()
        mockNetworkService.baseResponseTime = 0.05 // 50ms base response time
        mockNetworkService.variableResponseTime = 0.02 // +/- 20ms variation
        
        // Initialize real components
        securityService = SecurityService()
        auditLogger = AuditLogger()
        
        // Initialize the adapter with mock components
        adapter = YaleLockAdapter(
            networkService: mockNetworkService,
            securityService: securityService,
            auditLogger: auditLogger
        )
    }
    
    override func tearDown() {
        BiometricAuthenticationMock.mockResult = nil
        mockNetworkService = nil
        adapter = nil
        securityService = nil
        auditLogger = nil
        super.tearDown()
    }
    
    /// Test the lock operation under load
    func testLockOperationUnderLoad() async {
        // Configure options for a small load test by default
        let options = LoadTestingUtility.LoadTestOptions(
            concurrentRequests: 5, // 5 concurrent requests
            totalRequests: 20,     // 20 total requests
            intervalBetweenBatches: 0.5, // 0.5 second between batches
            logDetailedStats: true, // Log detailed stats
            requestTimeout: 5.0     // 5 second timeout
        )
        
        // Run the load test
        await runAndAssertLoadTest(
            adapter: adapter,
            operation: .lock,
            lockId: "yale-lock-123",
            options: options,
            maxFailureRate: 0.1,     // 10% failure rate acceptable for tests
            maxAvgResponseTime: 200.0 // 200ms max average response time
        )
    }
    
    /// Test the unlock operation under load
    func testUnlockOperationUnderLoad() async {
        // Configure options for a small load test by default
        let options = LoadTestingUtility.LoadTestOptions(
            concurrentRequests: 5, // 5 concurrent requests
            totalRequests: 20,     // 20 total requests
            intervalBetweenBatches: 0.5, // 0.5 second between batches
            logDetailedStats: true, // Log detailed stats
            requestTimeout: 5.0     // 5 second timeout
        )
        
        // Run the load test
        await runAndAssertLoadTest(
            adapter: adapter,
            operation: .unlock,
            lockId: "yale-lock-123",
            options: options,
            maxFailureRate: 0.1,     // 10% failure rate acceptable for tests
            maxAvgResponseTime: 250.0 // 250ms max average response time (unlock is slower due to biometric)
        )
    }
    
    // Test error responses
    func testErrorResponsesUnderLoad() async {
        // Set error probability
        mockNetworkService.errorProbability = 0.3 // 30% chance of error
        
        // Configure options for a small load test by default
        let options = LoadTestingUtility.LoadTestOptions(
            concurrentRequests: 5, // 5 concurrent requests
            totalRequests: 30,     // 30 total requests to ensure error cases
            intervalBetweenBatches: 0.5, // 0.5 second between batches
            logDetailedStats: true, // Log detailed stats
            requestTimeout: 5.0     // 5 second timeout
        )
        
        // Run the load test with higher accepted failure rate
        await runAndAssertLoadTest(
            adapter: adapter,
            operation: .lock,
            lockId: "yale-lock-123",
            options: options,
            maxFailureRate: 0.4,     // 40% failure rate acceptable for this test
            maxAvgResponseTime: 200.0 // 200ms max average response time
        )
    }
    
    // Mock network service with variable response times and error probability
    class MockNetworkService: NetworkServiceProtocol {
        var mockResponse: EmptyResponse = EmptyResponse()
        var errorProbability: Double = 0.0 // Probability of returning an error
        var baseResponseTime: TimeInterval = 0.1 // Base response time in seconds
        var variableResponseTime: TimeInterval = 0.05 // Additional variable response time
        
        func request<T: Decodable>(
            endpoint: String,
            method: HTTPMethod = .get,
            token: String? = nil,
            body: [String: Any]? = nil,
            headers: [String: String]? = nil,
            certificateValidation: ((SecTrust) -> Bool)? = nil
        ) async throws -> T {
            // Simulate network delay
            let delay = baseResponseTime + Double.random(in: -variableResponseTime...variableResponseTime)
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            // Randomly return an error based on error probability
            if Double.random(in: 0.0...1.0) < errorProbability {
                // Select a random error type
                let errorTypes: [Error] = [
                    URLError(.notConnectedToInternet),
                    URLError(.timedOut),
                    URLError(.badServerResponse),
                    LockOperationError.operationFailed("Random error")
                ]
                
                throw errorTypes.randomElement()!
            }
            
            // Return the mock response
            return mockResponse as! T
        }
    }
} 