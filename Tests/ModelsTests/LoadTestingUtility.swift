import XCTest
import Foundation
@testable import Models

/// Utility class for load testing APIs and adapters
class LoadTestingUtility {
    
    /// Options for load testing
    struct LoadTestOptions {
        /// Number of concurrent requests to make
        let concurrentRequests: Int
        
        /// Total number of requests to make
        let totalRequests: Int
        
        /// Time interval between batches of requests (in seconds)
        let intervalBetweenBatches: TimeInterval
        
        /// Whether to log detailed statistics
        let logDetailedStats: Bool
        
        /// Timeout for each request (in seconds)
        let requestTimeout: TimeInterval
        
        /// Initialize with default values
        init(
            concurrentRequests: Int = 10,
            totalRequests: Int = 100,
            intervalBetweenBatches: TimeInterval = 1.0,
            logDetailedStats: Bool = false,
            requestTimeout: TimeInterval = 30.0
        ) {
            self.concurrentRequests = concurrentRequests
            self.totalRequests = totalRequests
            self.intervalBetweenBatches = intervalBetweenBatches
            self.logDetailedStats = logDetailedStats
            self.requestTimeout = requestTimeout
        }
    }
    
    /// Results of a load test
    struct LoadTestResults {
        /// Total requests made
        let totalRequests: Int
        
        /// Successful requests
        let successfulRequests: Int
        
        /// Failed requests
        let failedRequests: Int
        
        /// Average response time in milliseconds
        let averageResponseTime: Double
        
        /// Minimum response time in milliseconds
        let minResponseTime: Double
        
        /// Maximum response time in milliseconds
        let maxResponseTime: Double
        
        /// 95th percentile response time in milliseconds
        let p95ResponseTime: Double
        
        /// Requests per second
        let requestsPerSecond: Double
        
        /// Total test duration in seconds
        let totalDuration: TimeInterval
        
        /// Error counts by type
        let errorCounts: [String: Int]
    }
    
    /// Run a load test against the Yale Lock Adapter
    /// - Parameters:
    ///   - adapter: The adapter to test
    ///   - operation: The operation to perform
    ///   - lockId: The lock ID to use
    ///   - options: Test options
    /// - Returns: Test results
    static func runAdapterLoadTest(
        adapter: YaleLockAdapter,
        operation: LockOperation,
        lockId: String,
        options: LoadTestOptions = LoadTestOptions()
    ) async -> LoadTestResults {
        let startTime = Date()
        var responseTimes: [Double] = []
        var successCount = 0
        var failureCount = 0
        var errorDict: [String: Int] = [:]
        
        // Function to make a single request and measure time
        func makeRequest() async -> (success: Bool, responseTime: Double, errorType: String?) {
            let requestStartTime = Date().timeIntervalSince1970
            do {
                try await withTimeout(of: options.requestTimeout) {
                    try await adapter.controlLock(id: lockId, operation: operation)
                }
                let requestEndTime = Date().timeIntervalSince1970
                let responseTime = (requestEndTime - requestStartTime) * 1000 // Convert to ms
                return (true, responseTime, nil)
            } catch {
                let requestEndTime = Date().timeIntervalSince1970
                let responseTime = (requestEndTime - requestStartTime) * 1000 // Convert to ms
                let errorType = String(describing: type(of: error))
                return (false, responseTime, errorType)
            }
        }
        
        // Execute requests in batches
        var completedRequests = 0
        
        while completedRequests < options.totalRequests {
            let batchSize = min(options.concurrentRequests, options.totalRequests - completedRequests)
            var batch: [Task<(success: Bool, responseTime: Double, errorType: String?), Never>] = []
            
            // Create and start tasks for this batch
            for _ in 0..<batchSize {
                let task = Task {
                    await makeRequest()
                }
                batch.append(task)
            }
            
            // Wait for all tasks in batch to complete
            for task in batch {
                let result = await task.value
                responseTimes.append(result.responseTime)
                
                if result.success {
                    successCount += 1
                } else {
                    failureCount += 1
                    if let errorType = result.errorType {
                        errorDict[errorType] = (errorDict[errorType] ?? 0) + 1
                    }
                }
                
                if options.logDetailedStats {
                    print("Request completed in \(result.responseTime)ms - \(result.success ? "Success" : "Failed")")
                }
            }
            
            completedRequests += batchSize
            
            // Progress report
            if options.logDetailedStats {
                let progress = Double(completedRequests) / Double(options.totalRequests) * 100
                print("Progress: \(Int(progress))% (\(completedRequests)/\(options.totalRequests))")
            }
            
            // Wait before next batch if not the last batch
            if completedRequests < options.totalRequests {
                try? await Task.sleep(nanoseconds: UInt64(options.intervalBetweenBatches * 1_000_000_000))
            }
        }
        
        // Calculate statistics
        let endTime = Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        let requestsPerSecond = Double(options.totalRequests) / totalDuration
        
        // Sort response times for percentile calculations
        responseTimes.sort()
        
        let minResponseTime = responseTimes.first ?? 0
        let maxResponseTime = responseTimes.last ?? 0
        let averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        // Calculate 95th percentile
        let p95Index = Int(ceil(Double(responseTimes.count) * 0.95)) - 1
        let p95ResponseTime = p95Index >= 0 && p95Index < responseTimes.count ? responseTimes[p95Index] : 0
        
        return LoadTestResults(
            totalRequests: options.totalRequests,
            successfulRequests: successCount,
            failedRequests: failureCount,
            averageResponseTime: averageResponseTime,
            minResponseTime: minResponseTime,
            maxResponseTime: maxResponseTime,
            p95ResponseTime: p95ResponseTime,
            requestsPerSecond: requestsPerSecond,
            totalDuration: totalDuration,
            errorCounts: errorDict
        )
    }
    
    /// Executes an operation with a timeout
    /// - Parameters:
    ///   - seconds: The timeout in seconds
    ///   - operation: The operation to execute
    /// - Throws: Throws TimeoutError if the operation times out
    private static func withTimeout<T>(of seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Wait for the first task to complete (either the operation or the timeout)
            defer {
                group.cancelAll()
            }
            
            // Return the first result or throw the first error
            return try await group.next()!
        }
    }
    
    /// Error thrown when an operation times out
    struct TimeoutError: Error {}
}

/// XCTest extension for load testing
extension XCTestCase {
    /// Run a load test and assert on the results
    /// - Parameters:
    ///   - adapter: The adapter to test
    ///   - operation: The operation to perform
    ///   - lockId: The lock ID to use
    ///   - options: Test options
    ///   - maxFailureRate: Maximum acceptable failure rate (0.0 to 1.0)
    ///   - maxAvgResponseTime: Maximum acceptable average response time in milliseconds
    ///   - file: The file in which the failure occurs
    ///   - line: The line number at which the failure occurs
    func runAndAssertLoadTest(
        adapter: YaleLockAdapter,
        operation: LockOperation,
        lockId: String,
        options: LoadTestingUtility.LoadTestOptions = LoadTestingUtility.LoadTestOptions(),
        maxFailureRate: Double = 0.05,
        maxAvgResponseTime: Double = 500.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let results = await LoadTestingUtility.runAdapterLoadTest(
            adapter: adapter,
            operation: operation,
            lockId: lockId,
            options: options
        )
        
        // Calculate failure rate
        let failureRate = Double(results.failedRequests) / Double(results.totalRequests)
        
        // Print results
        print("\n--- Load Test Results ---")
        print("Total Requests: \(results.totalRequests)")
        print("Successful Requests: \(results.successfulRequests)")
        print("Failed Requests: \(results.failedRequests)")
        print("Failure Rate: \(String(format: "%.2f%%", failureRate * 100))")
        print("Average Response Time: \(String(format: "%.2f", results.averageResponseTime))ms")
        print("Min Response Time: \(String(format: "%.2f", results.minResponseTime))ms")
        print("Max Response Time: \(String(format: "%.2f", results.maxResponseTime))ms")
        print("95th Percentile Response Time: \(String(format: "%.2f", results.p95ResponseTime))ms")
        print("Requests Per Second: \(String(format: "%.2f", results.requestsPerSecond))")
        print("Total Duration: \(String(format: "%.2f", results.totalDuration))s")
        
        if !results.errorCounts.isEmpty {
            print("\nError Counts:")
            for (errorType, count) in results.errorCounts.sorted(by: { $0.value > $1.value }) {
                print("  \(errorType): \(count)")
            }
        }
        print("------------------------\n")
        
        // Assert that the failure rate is acceptable
        XCTAssertLessThanOrEqual(
            failureRate,
            maxFailureRate,
            "Failure rate of \(String(format: "%.2f%%", failureRate * 100)) exceeds maximum allowed \(String(format: "%.2f%%", maxFailureRate * 100))",
            file: file,
            line: line
        )
        
        // Assert that the average response time is acceptable
        XCTAssertLessThanOrEqual(
            results.averageResponseTime,
            maxAvgResponseTime,
            "Average response time of \(String(format: "%.2f", results.averageResponseTime))ms exceeds maximum allowed \(String(format: "%.2f", maxAvgResponseTime))ms",
            file: file,
            line: line
        )
    }
} 