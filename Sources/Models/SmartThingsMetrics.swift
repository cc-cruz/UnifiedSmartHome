import Foundation

/// Metrics collection system for SmartThings operations
public class SmartThingsMetrics {
    public static let shared = SmartThingsMetrics()
    
    private var errorCounts: [SmartThingsError: Int] = [:]
    private var deviceOperationCounts: [String: [String: Int]] = [:]
    private var sceneOperationCounts: [String: [String: Int]] = [:]
    private var groupOperationCounts: [String: [String: Int]] = [:]
    private var operationLatencies: [String: [TimeInterval]] = [:]
    
    private let queue = DispatchQueue(label: "com.unifiedsmarthome.smartthings.metrics")
    
    private init() {}
    
    // MARK: - Error Metrics
    
    public func recordError(_ error: SmartThingsError) {
        queue.async {
            self.errorCounts[error, default: 0] += 1
            self.recordOperationLatency("error", latency: 0)
        }
    }
    
    public func getErrorCounts() -> [SmartThingsError: Int] {
        queue.sync { errorCounts }
    }
    
    // MARK: - Device Operation Metrics
    
    public func recordDeviceOperation(deviceId: String, operation: String, status: String) {
        queue.async {
            if self.deviceOperationCounts[deviceId] == nil {
                self.deviceOperationCounts[deviceId] = [:]
            }
            let key = "\(operation)_\(status)"
            self.deviceOperationCounts[deviceId]?[key, default: 0] += 1
        }
    }
    
    public func getDeviceOperationCounts() -> [String: [String: Int]] {
        queue.sync { deviceOperationCounts }
    }
    
    // MARK: - Scene Operation Metrics
    
    public func recordSceneOperation(sceneId: String, operation: String, status: String) {
        queue.async {
            if self.sceneOperationCounts[sceneId] == nil {
                self.sceneOperationCounts[sceneId] = [:]
            }
            let key = "\(operation)_\(status)"
            self.sceneOperationCounts[sceneId]?[key, default: 0] += 1
        }
    }
    
    public func getSceneOperationCounts() -> [String: [String: Int]] {
        queue.sync { sceneOperationCounts }
    }
    
    // MARK: - Group Operation Metrics
    
    public func recordGroupOperation(groupId: String, operation: String, status: String) {
        queue.async {
            if self.groupOperationCounts[groupId] == nil {
                self.groupOperationCounts[groupId] = [:]
            }
            let key = "\(operation)_\(status)"
            self.groupOperationCounts[groupId]?[key, default: 0] += 1
        }
    }
    
    public func getGroupOperationCounts() -> [String: [String: Int]] {
        queue.sync { groupOperationCounts }
    }
    
    // MARK: - Latency Metrics
    
    public func recordOperationLatency(_ operation: String, latency: TimeInterval) {
        queue.async {
            if self.operationLatencies[operation] == nil {
                self.operationLatencies[operation] = []
            }
            self.operationLatencies[operation]?.append(latency)
        }
    }
    
    public func getOperationLatencies() -> [String: [TimeInterval]] {
        queue.sync { operationLatencies }
    }
    
    public func getAverageLatency(for operation: String) -> TimeInterval? {
        queue.sync {
            guard let latencies = operationLatencies[operation], !latencies.isEmpty else {
                return nil
            }
            return latencies.reduce(0, +) / Double(latencies.count)
        }
    }
    
    // MARK: - Metrics Summary
    
    public func getMetricsSummary() -> [String: Any] {
        queue.sync {
            [
                "errorCounts": errorCounts,
                "deviceOperationCounts": deviceOperationCounts,
                "sceneOperationCounts": sceneOperationCounts,
                "groupOperationCounts": groupOperationCounts,
                "averageLatencies": operationLatencies.mapValues { latencies in
                    latencies.reduce(0, +) / Double(latencies.count)
                }
            ]
        }
    }
    
    // MARK: - Reset Metrics
    
    public func resetMetrics() {
        queue.async {
            self.errorCounts.removeAll()
            self.deviceOperationCounts.removeAll()
            self.sceneOperationCounts.removeAll()
            self.groupOperationCounts.removeAll()
            self.operationLatencies.removeAll()
        }
    }
    
    // ADDED: Generic counter increment method
    public func incrementCounter(named counterName: String) {
        queue.async {
            // For simplicity, let's use deviceOperationCounts with a generic deviceId like "appCounters"
            // Or, you can add a new dictionary specifically for general counters.
            let genericDeviceId = "appCounters"
            if self.deviceOperationCounts[genericDeviceId] == nil {
                self.deviceOperationCounts[genericDeviceId] = [:]
            }
            self.deviceOperationCounts[genericDeviceId]?[counterName, default: 0] += 1
            // print("Incremented counter: \(counterName)") // Optional: for debugging
        }
    }
} 