import XCTest
@testable import UnifiedSmartHome

final class DeviceCommandTests: XCTestCase {
    func testDeviceCommandDescription() {
        // Command with no parameters
        let turnOnCommand = DeviceCommand(name: "turnOn")
        XCTAssertEqual(turnOnCommand.description, "turnOn")
        
        // Command with a single parameter
        let setBrightnessCommand = DeviceCommand(name: "setBrightness", parameters: ["brightness": 75])
        XCTAssertEqual(setBrightnessCommand.description, "setBrightness [brightness: 75]")
        
        // Command with multiple parameters
        let setColorCommand = DeviceCommand(
            name: "setColor", 
            parameters: ["color": "#FFFFFF", "brightness": 100]
        )
        
        // Since dictionary iteration order is not guaranteed, we need to check that both parameters are present
        XCTAssertTrue(setColorCommand.description.contains("setColor"))
        XCTAssertTrue(setColorCommand.description.contains("color: #FFFFFF"))
        XCTAssertTrue(setColorCommand.description.contains("brightness: 100"))
    }
    
    func testDeviceOperationErrorEquality() {
        // Test same error types
        XCTAssertEqual(DeviceOperationError.authenticationRequired, DeviceOperationError.authenticationRequired)
        XCTAssertEqual(DeviceOperationError.deviceNotFound, DeviceOperationError.deviceNotFound)
        XCTAssertEqual(DeviceOperationError.invalidCommandParameters, DeviceOperationError.invalidCommandParameters)
        
        // Test server errors with same status code
        XCTAssertEqual(
            DeviceOperationError.serverError(statusCode: 500),
            DeviceOperationError.serverError(statusCode: 500)
        )
        
        // Test server errors with different status codes
        XCTAssertNotEqual(
            DeviceOperationError.serverError(statusCode: 500),
            DeviceOperationError.serverError(statusCode: 503)
        )
        
        // Test different error types
        XCTAssertNotEqual(DeviceOperationError.authenticationRequired, DeviceOperationError.deviceNotFound)
        XCTAssertNotEqual(DeviceOperationError.rateLimitExceeded, DeviceOperationError.networkError)
    }
} 