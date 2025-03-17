import XCTest
@testable import Models

final class LockDeviceTests: XCTestCase {
    // Test device properties
    var lockDevice: LockDevice!
    var testUser: User!
    
    override func setUp() {
        super.setUp()
        
        testUser = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .owner,
            properties: ["test-property-id"],
            assignedRooms: ["Living Room"]
        )
        
        lockDevice = LockDevice(
            id: "test-lock-id",
            name: "Test Lock",
            room: "Living Room",
            manufacturer: "Test Manufacturer",
            model: "Test Model",
            firmwareVersion: "1.0.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: ["propertyId": "test-property-id"],
            currentState: .locked,
            batteryLevel: 80,
            lastStateChange: Date(),
            isRemoteOperationEnabled: true
        )
    }
    
    override func tearDown() {
        lockDevice = nil
        testUser = nil
        super.tearDown()
    }
    
    // MARK: - Basic Property Tests
    
    func testInitialization() {
        XCTAssertEqual(lockDevice.id, "test-lock-id")
        XCTAssertEqual(lockDevice.name, "Test Lock")
        XCTAssertEqual(lockDevice.room, "Living Room")
        XCTAssertEqual(lockDevice.manufacturer, "Test Manufacturer")
        XCTAssertEqual(lockDevice.model, "Test Model")
        XCTAssertEqual(lockDevice.firmwareVersion, "1.0.0")
        XCTAssertEqual(lockDevice.batteryLevel, 80)
        XCTAssertEqual(lockDevice.currentState, .locked)
        XCTAssertTrue(lockDevice.isRemoteOperationEnabled)
        XCTAssertEqual(lockDevice.accessHistory.count, 0)
    }
    
    // MARK: - State Change Tests
    
    func testUpdateLockState() {
        lockDevice.updateLockState(to: .unlocked, initiatedBy: "another-user-id")
        
        XCTAssertEqual(lockDevice.currentState, .unlocked)
        XCTAssertNotNil(lockDevice.lastStateChange)
        
        // Verify access history was updated
        XCTAssertEqual(lockDevice.accessHistory.count, 1)
        XCTAssertEqual(lockDevice.accessHistory[0].operation, .unlock)
        XCTAssertEqual(lockDevice.accessHistory[0].userId, "another-user-id")
        XCTAssertTrue(lockDevice.accessHistory[0].success)
    }
    
    func testUpdateBatteryLevel() {
        lockDevice.updateBatteryLevel(to: 50)
        XCTAssertEqual(lockDevice.batteryLevel, 50)
        
        // Test upper bound
        lockDevice.updateBatteryLevel(to: 120)
        XCTAssertEqual(lockDevice.batteryLevel, 100)
        
        // Test lower bound
        lockDevice.updateBatteryLevel(to: -10)
        XCTAssertEqual(lockDevice.batteryLevel, 0)
    }
    
    // MARK: - Security Tests
    
    func testCanPerformRemoteOperation_Owner() {
        // Owner with matching property should be allowed
        XCTAssertTrue(lockDevice.canPerformRemoteOperation(by: testUser))
        
        // Owner with incorrect property should be denied
        let userWithWrongProperty = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .owner,
            properties: ["wrong-property"],
            assignedRooms: ["Living Room"]
        )
        XCTAssertFalse(lockDevice.canPerformRemoteOperation(by: userWithWrongProperty))
    }
    
    func testCanPerformRemoteOperation_Tenant() {
        // Tenant with matching property and room should be allowed
        let tenantUser = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .tenant,
            properties: ["test-property-id"],
            assignedRooms: ["Living Room"]
        )
        XCTAssertTrue(lockDevice.canPerformRemoteOperation(by: tenantUser))
        
        // Tenant with correct property but wrong room should be denied
        let tenantWithWrongRoom = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .tenant,
            properties: ["test-property-id"],
            assignedRooms: ["Bedroom"]
        )
        XCTAssertFalse(lockDevice.canPerformRemoteOperation(by: tenantWithWrongRoom))
    }
    
    func testCanPerformRemoteOperation_Guest() {
        // Create guest access
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        let guestAccess = User.GuestAccess(
            validFrom: yesterday,
            validUntil: tomorrow,
            deviceIds: ["test-lock-id"]
        )
        
        // Guest with valid access should be allowed
        let guestUser = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .guest,
            properties: ["test-property-id"],
            assignedRooms: ["Living Room"],
            guestAccess: guestAccess
        )
        XCTAssertTrue(lockDevice.canPerformRemoteOperation(by: guestUser))
        
        // Guest with expired access should be denied
        let expiredAccess = User.GuestAccess(
            validFrom: Calendar.current.date(byAdding: .day, value: -2, to: now)!,
            validUntil: yesterday,
            deviceIds: ["test-lock-id"]
        )
        
        let expiredGuest = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .guest,
            properties: ["test-property-id"],
            assignedRooms: ["Living Room"],
            guestAccess: expiredAccess
        )
        XCTAssertFalse(lockDevice.canPerformRemoteOperation(by: expiredGuest))
        
        // Guest with wrong device ID should be denied
        let wrongDeviceAccess = User.GuestAccess(
            validFrom: yesterday,
            validUntil: tomorrow,
            deviceIds: ["wrong-device-id"]
        )
        
        let wrongDeviceGuest = User(
            id: "test-user-id",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .guest,
            properties: ["test-property-id"],
            assignedRooms: ["Living Room"],
            guestAccess: wrongDeviceAccess
        )
        XCTAssertFalse(lockDevice.canPerformRemoteOperation(by: wrongDeviceGuest))
    }
    
    func testCanPerformRemoteOperation_RemoteDisabled() {
        // Create a lock with remote operations disabled
        let disabledLock = LockDevice(
            id: "disabled-lock-id",
            name: "Disabled Lock",
            room: "Living Room",
            manufacturer: "Test Manufacturer",
            model: "Test Model",
            firmwareVersion: "1.0.0",
            isOnline: true,
            lastSeen: Date(),
            dateAdded: Date(),
            metadata: ["propertyId": "test-property-id"],
            currentState: .locked,
            batteryLevel: 80,
            lastStateChange: Date(),
            isRemoteOperationEnabled: false
        )
        
        // Even owner should be denied if remote operations are disabled
        XCTAssertFalse(disabledLock.canPerformRemoteOperation(by: testUser))
    }
} 