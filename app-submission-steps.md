# App Submission Plan for Sunday

## Goal
Successfully submit a functional version of the Unified Smart Home app to the App Store by Sunday. This plan outlines the prioritized development tasks to achieve this, focusing on core functionality and stability.

## Guiding Principles
1.  **Prioritize Ruthlessly**: Focus on the P0 and P1 tasks first.
2.  **Standard IAP**: All monetization will use Apple's In-App Purchase system for this submission.
3.  **Incremental Changes**: Implement and test features incrementally.
4.  **Clear Definitions**: Ensure data models and APIs are well-defined before implementation.

## High-Level Priorities

*   **P0: Core Multi-Tenancy Implementation (iOS & Backend)**
    *   Goal: Users can log in, and the app correctly scopes their access to devices based on a Portfolio -> Property -> Unit hierarchy.
*   **P1: "$1 Compliance Pack" In-App Purchase (iOS & Backend Stub)**
    *   Goal: Users can purchase a "Compliance Pack" add-on via IAP. The app recognizes the purchase. Actual feature can be minimal for now.
*   **P2: Critical Fixes & Testing for Multi-Tenancy**
    *   Goal: Ensure existing device listing, control, and user management features work correctly with the new multi-tenancy model.

---

## P0: Core Multi-Tenancy Implementation

### Step 1: Define Core Data Models (iOS - Swift)

**Status: COMPLETE.** All planned Swift data models and their required conformances for P0 are implemented.

These are foundational. Files exist in `Sources/Models/`.

1.  **`Portfolio.swift`**:
    *   **Status: EXISTS & UPDATED.**
    *   Represents the highest level of ownership.
    *   Structure: `id: String`, `name: String`, `administratorUserIds: [String]` (aligns with plan's `ownerAdminUserIds`), `propertyIds: [String]`, `createdAt: Date?`, `updatedAt: Date?`.
    *   Conforms to `Codable`, `Identifiable`, `Hashable`.
    *   **Completed:** Added `Hashable` conformance.

2.  **`Property.swift`**:
    *   **Status: EXISTS & UPDATED.**
    *   Represents a distinct building or site.
    *   Structure: `id: String`, `name: String`, `portfolioId: String`, `address: PropertyAddress?` (structured, good!), `managerUserIds: [String]`, `unitIds: [String]`, `defaultTimeZone: String?`, `createdAt: Date?`, `updatedAt: Date?`.
    *   `PropertyAddress` struct also exists and conforms to `Codable`, `Hashable`: `street`, `city`, `state`, `postalCode`, `country`.
    *   Conforms to `Codable`, `Identifiable`, `Hashable`.
    *   **Completed:** Added `Hashable` conformance (to both `Property` and `PropertyAddress`).

3.  **`Unit.swift`**:
    *   **Status: EXISTS & UPDATED.**
    *   Represents an individual apartment, office, or space within a Property.
    *   Structure: `id: String`, `name: String`, `propertyId: String`, `tenantUserIds: [String]`, `deviceIds: [String]` (aligns with plan's `doorLockDeviceIds`), `commonAreaAccessIds: [String]?` (good addition!), `createdAt: Date?`, `updatedAt: Date?`.
    *   Conforms to `Codable`, `Identifiable`, `Hashable`.
    *   **Completed:** Added `Hashable` conformance.

4.  **`User.swift` (`Sources/Models/User.swift`)**:
    *   **Status: EXISTS and significantly updated for multi-tenancy & P0 requirements.**
    *   Uses a robust `roleAssociations: [UserRoleAssociation]?` structure. `UserRoleAssociation` includes `associatedEntityType: AssociatedEntityType`, `associatedEntityId: String`, `roleWithinEntity: User.Role`, and now conforms to `Hashable`.
    *   Includes `defaultPortfolioId: String?`, `defaultPropertyId: String?`, `defaultUnitId: String?`.
    *   `Role` enum is enhanced.
    *   Contains convenience methods, including new ones for portfolio-level role checks (e.g., `roles(forPortfolioId:)`, `isOwner(ofPortfolioId:)`, `isPortfolioAdmin(ofPortfolioId:)`).
    *   **Completed:** Enhancements to role management and convenience methods for P0 UI implemented. Full `Codable` support maintained and `UserRoleAssociation` made `Hashable`.

5.  **`LockDevice.swift` (`Sources/Models/LockDevice.swift`)**:
    *   **Status: EXISTS and updated with tenancy links & robust Codable support.**
    *   Includes `public var propertyId: String?` and `public var unitId: String?`.
    *   The `canPerformRemoteOperation(by user: User)` method has been partially refactored (further review in Step 8).
    *   **Completed:** Robust `Codable` support implemented. This involved making `AbstractDevice` (superclass) `Codable`, ensuring `LockDevice.LockAccessRecord` is `Codable` (with `id` fix), and correctly implementing `Codable` for `LockDevice` itself, including handling for inheritance.

### Step 2: Define Core Data Models (Backend - Node.js/TypeScript)

**Status: TYPESCRIPT INTERFACES DEFINED.** TypeScript interfaces for all core multi-tenancy models (Portfolio, Property, Unit, User, UserRoleAssociation, Device) and related enums (AssociatedEntityType, Role) have been created in `backend/models/` and `backend/enums/` respectively. These definitions align with the plan and consider existing Mongoose schemas.

Mirror the iOS models closely, especially the `UserRoleAssociation` concept for flexible permissions. Assume usage of an ORM/ODM (e.g., Mongoose for MongoDB, Sequelize/TypeORM for SQL).

1.  **`Portfolio` Model/Schema:**
    *   Fields: `id` (primary key, e.g., UUID/ObjectID), `name` (String, required, indexed), `administratorUserIds` ([UserID], indexed - *Note: Consider if this should directly use UserRoleAssociation or if it's a simpler direct admin link*), `propertyIds` ([PropertyID], indexed).
    *   Timestamps: `createdAt`, `updatedAt`.

2.  **`Property` Model/Schema:**
    *   Fields: `id` (PK, UUID/ObjectID), `name` (String, required, indexed), `portfolioId` (FK to Portfolio, indexed, required), `address` (String or structured object similar to iOS `PropertyAddress`), `managerUserIds` ([UserID], indexed - *Note: Consider UserRoleAssociation alignment*), `unitIds` ([UnitID], indexed), `defaultTimeZone` (String, optional).
    *   Timestamps: `createdAt`, `updatedAt`.

3.  **`Unit` Model/Schema:**
    *   Fields: `id` (PK, UUID/ObjectID), `name` (String, required, indexed), `propertyId` (FK to Property, indexed, required), `deviceIds` ([DeviceID], indexed), `tenantUserIds` ([UserID], indexed - *Note: Consider UserRoleAssociation alignment*), `commonAreaAccessIds` ([DeviceID], optional, indexed).
    *   Timestamps: `createdAt`, `updatedAt`.

4.  **`User` Model/Schema:**
    *   Existing fields: `id`, `email`, `firstName`, `lastName`, `passwordHash`, etc.
    *   **Remove/Deprecate simple role field if it exists.**
    *   Add: `defaultPortfolioId` (PortfolioID, optional), `defaultPropertyId` (PropertyID, optional), `defaultUnitId` (UnitID, optional).
    *   **Key Change for Tenancy:** Instead of direct ID arrays like `administeredPortfolioIds`, implement using a separate `UserRoleAssociation` collection/table or an array of embedded documents if your ODM supports it well for querying.

5.  **`UserRoleAssociation` Model/Schema (New Collection/Table):**
    *   Fields: `id` (PK), `userId` (FK to User, indexed, required), `associatedEntityType` (String Enum: "PORTFOLIO", "PROPERTY", "UNIT", required, indexed), `associatedEntityId` (String, refers to ID in Portfolio/Property/Unit collection/table, required, indexed), `roleWithinEntity` (String Enum mirroring iOS `User.Role`: "OWNER", "PORTFOLIO_ADMIN", "PROPERTY_MANAGER", "TENANT", required, indexed).
    *   This structure provides maximum flexibility for assigning multiple roles to a user across different entities.
    *   Consider compound indexes for efficient querying (e.g., `userId` + `associatedEntityType` + `associatedEntityId`).
    *   Timestamps: `createdAt`, `updatedAt`.

6.  **`Device` Model/Schema (Modification):**
    *   Existing fields: `id`, `name`, `type`, etc.
    *   Add: `propertyId` (FK to Property, indexed, nullable), `unitId` (FK to Unit, indexed, nullable).
    *   These fields link a device to the multi-tenancy hierarchy. Ensure they are nullable if a device can be provisioned before full assignment to a unit.

7.  **Data Integrity and Relationships:**
    *   Define clear relationships (one-to-many, many-to-many as appropriate) if using a relational DB or ORM features.
    *   For NoSQL, ensure application-level enforcement of integrity where needed (e.g., when a Property is deleted, how are its Units handled? Cascade deletes or logical separation?).
    *   Consider indexing strategy carefully for all new FKs and fields used in tenancy queries.

**Next Steps After Backend Model Definition:**
*   Update existing Mongoose schemas (in `.js` files) or transition them to TypeScript to match the defined interfaces. **Status: COMPLETE.** (Mongoose .js schemas updated/created as of [Current Date - I'll fill this in spirit during generation, actual date will be when applied])
*   Proceed to P0 Step 3: Develop Backend API Endpoints.
*   Ensure all new models/schemas are integrated with the backend's database initialization and migration strategy (if any).

### Step 3: Develop Backend API Endpoints for Multi-Tenancy

**Status: PENDING DEFINITION.** This step outlines the API structure.

Create RESTful APIs for managing Portfolios, Properties, and Units. Ensure all endpoints are authenticated (e.g., JWT-based) and authorized using the `UserRoleAssociation` model. Use consistent error handling and response structures.

**General Conventions:**
*   Authentication: All endpoints require a valid JWT token.
*   Authorization: Specific roles/associations checked per endpoint using middleware.
*   Request Body: JSON.
*   Response Body: JSON. Success: `200 OK`, `201 Created`. Error: `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `500 Internal Server Error`.
*   Standard success response: `{ "status": "success", "data": { ... } }`
*   Standard error response: `{ "status": "error", "message": "...", "details": { ... } }`

1.  **Portfolio Endpoints (`/api/v1/portfolios`)**:
    *   `POST /`
        *   Description: Create a new portfolio.
        *   Request Body: `{ "name": "String", "administratorUserIds": ["String"] (optional) }`
        *   Response Body (201): `{ "status": "success", "data": { portfolioObject } }`
        *   Auth: Requires global "SuperAdmin" or similar high-level role not tied to a specific portfolio yet.
        *   Logic: Creates Portfolio, assigns requesting user (if an admin) or specified `administratorUserIds` with "OWNER" or "PORTFOLIO_ADMIN" role in `UserRoleAssociation` for this new portfolio.
    *   `GET /`
        *   Description: List portfolios accessible to the current authenticated user.
        *   Query Params: `?page=1&limit=10&sortBy=name` (optional pagination/sorting)
        *   Response Body (200): `{ "status": "success", "data": { "portfolios": [portfolioObject], "pagination": { ... } } }`
        *   Auth: Fetches portfolios where user has an association in `UserRoleAssociation` (e.g., OWNER, PORTFOLIO_ADMIN).
    *   `GET /:portfolioId`
        *   Description: Get details of a specific portfolio.
        *   Response Body (200): `{ "status": "success", "data": { portfolioObject } }`
        *   Auth: User must have an association with this `portfolioId` in `UserRoleAssociation`.
    *   `PUT /:portfolioId`
        *   Description: Update portfolio details.
        *   Request Body: `{ "name": "String" (optional), "administratorUserIds": ["String"] (optional, for replacing/adding admins) }`
        *   Response Body (200): `{ "status": "success", "data": { portfolioObject } }`
        *   Auth: User must have "OWNER" or "PORTFOLIO_ADMIN" role for this `portfolioId`.
    *   `DELETE /:portfolioId`
        *   Description: Delete a portfolio (consider soft delete).
        *   Response Body (204 No Content or 200 with status message).
        *   Auth: User must have "OWNER" role for this `portfolioId` (or SuperAdmin).
        *   Logic: Also handle dissociation of properties, units, devices, and user role associations carefully (cascade or prevent if dependencies exist).
    *   `POST /:portfolioId/properties`
        *   Description: Create and add a new property to this portfolio.
        *   Request Body: `{ "name": "String", "address": { propertyAddressObject } (optional), "managerUserIds": ["String"] (optional) }`
        *   Response Body (201): `{ "status": "success", "data": { propertyObject } }`
        *   Auth: User must have "OWNER" or "PORTFOLIO_ADMIN" role for this `portfolioId`.
        *   Logic: Creates Property, links it to Portfolio. Assigns specified `managerUserIds` with "PROPERTY_MANAGER" role for the new property in `UserRoleAssociation`.
    *   `GET /:portfolioId/properties`
        *   Description: List all properties within this portfolio.
        *   Response Body (200): `{ "status": "success", "data": { "properties": [propertyObject] } }`
        *   Auth: User must have an association with this `portfolioId`.
    *   `POST /:portfolioId/admins`
        *   Description: Add/invite an administrator to this portfolio.
        *   Request Body: `{ "userId": "String", "role": "PORTFOLIO_ADMIN" (or "OWNER" if allowed) }`
        *   Response Body (200): `{ "status": "success", "data": { userRoleAssociationObject } }`
        *   Auth: User must be "OWNER" of this `portfolioId`.

2.  **Property Endpoints (`/api/v1/properties`)**:
    *   `POST /` (Alternative to nested creation, if direct creation is allowed, ensure `portfolioId` is in body)
        *   Description: Create a new property.
        *   Request Body: `{ "name": "String", "portfolioId": "String", "address": { propertyAddressObject } (optional), "managerUserIds": ["String"] (optional) }`
        *   Response Body (201): `{ "status": "success", "data": { propertyObject } }`
        *   Auth: User must have "OWNER" or "PORTFOLIO_ADMIN" role for the parent `portfolioId`.
    *   `GET /`
        *   Description: List properties accessible to the current user (e.g., managed by them, or within their accessible portfolios).
        *   Query Params: `?portfolioId=String (optional filter), ?page=1&limit=10&sortBy=name`
        *   Response Body (200): `{ "status": "success", "data": { "properties": [propertyObject], "pagination": { ... } } }`
        *   Auth: Fetches properties where user has an association (e.g., PROPERTY_MANAGER) or via portfolio access.
    *   `GET /:propertyId`
        *   Description: Get details of a specific property.
        *   Response Body (200): `{ "status": "success", "data": { propertyObject } }`
        *   Auth: User must have an association with this `propertyId` (or its parent portfolio).
    *   `PUT /:propertyId`
        *   Description: Update property details.
        *   Request Body: `{ "name": "String" (optional), "address": { propertyAddressObject } (optional), "managerUserIds": ["String"] (optional for replacing/adding managers) }`
        *   Response Body (200): `{ "status": "success", "data": { propertyObject } }`
        *   Auth: User must have "PROPERTY_MANAGER" role for this `propertyId` or admin/owner of parent portfolio.
    *   `DELETE /:propertyId`
        *   Description: Delete a property.
        *   Response Body (204 No Content or 200 with status message).
        *   Auth: User must be "OWNER"/"PORTFOLIO_ADMIN" of parent portfolio or have specific high-level rights.
        *   Logic: Handle dissociation of units, devices, user role associations.
    *   `POST /:propertyId/units`
        *   Description: Create and add a new unit to this property.
        *   Request Body: `{ "name": "String", "tenantUserIds": ["String"] (optional), "deviceIds": ["String"] (optional) }`
        *   Response Body (201): `{ "status": "success", "data": { unitObject } }`
        *   Auth: User must have "PROPERTY_MANAGER" role for this `propertyId`.
        *   Logic: Creates Unit, links to Property. Assigns `tenantUserIds` with "TENANT" role for new unit.
    *   `GET /:propertyId/units`
        *   Description: List all units within this property.
        *   Response Body (200): `{ "status": "success", "data": { "units": [unitObject] } }`
        *   Auth: User must have an association with this `propertyId`.
    *   `POST /:propertyId/managers`
        *   Description: Add/invite a manager to this property.
        *   Request Body: `{ "userId": "String", "role": "PROPERTY_MANAGER" }`
        *   Response Body (200): `{ "status": "success", "data": { userRoleAssociationObject } }`
        *   Auth: User must be "OWNER"/"PORTFOLIO_ADMIN" of parent portfolio.

3.  **Unit Endpoints (`/api/v1/units`)**:
    *   `POST /` (Alternative to nested creation)
        *   Description: Create a new unit.
        *   Request Body: `{ "name": "String", "propertyId": "String", "tenantUserIds": ["String"] (optional), "deviceIds": ["String"] (optional) }`
        *   Response Body (201): `{ "status": "success", "data": { unitObject } }`
        *   Auth: User must have "PROPERTY_MANAGER" role for the parent `propertyId`.
    *   `GET /`
        *   Description: List units accessible to the current user (e.g., as a tenant or manager).
        *   Query Params: `?propertyId=String (optional filter), ?page=1&limit=10&sortBy=name`
        *   Response Body (200): `{ "status": "success", "data": { "units": [unitObject], "pagination": { ... } } }`
        *   Auth: Fetches units where user has an association (e.g., TENANT, or via property management).
    *   `GET /:unitId`
        *   Description: Get details of a specific unit.
        *   Response Body (200): `{ "status": "success", "data": { unitObject } }`
        *   Auth: User must be "TENANT" of this `unitId` or manager of parent property.
    *   `PUT /:unitId`
        *   Description: Update unit details.
        *   Request Body: `{ "name": "String" (optional), "tenantUserIds": ["String"] (optional for replacing/adding tenants), "deviceIds": ["String"] (optional) }`
        *   Response Body (200): `{ "status": "success", "data": { unitObject } }`
        *   Auth: User must be "PROPERTY_MANAGER" of parent property. Tenants may have very limited update rights (e.g., only their own association, handled differently).
    *   `DELETE /:unitId`
        *   Description: Delete a unit.
        *   Response Body (204 No Content or 200 with status message).
        *   Auth: User must be "PROPERTY_MANAGER" of parent property.
        *   Logic: Handle dissociation of devices, user role associations.
    *   `POST /:unitId/tenants`
        *   Description: Assign/invite a tenant to this unit.
        *   Request Body: `{ "userId": "String", "role": "TENANT" }`
        *   Response Body (200): `{ "status": "success", "data": { userRoleAssociationObject } }`
        *   Auth: User must be "PROPERTY_MANAGER" of parent property.
    *   `GET /:unitId/tenants`
        *   Description: List tenants assigned to this unit.
        *   Response Body (200): `{ "status": "success", "data": { "users": [userObjectWithoutSensitiveInfo] } }`
        *   Auth: User must be "PROPERTY_MANAGER" of parent property.
    *   `POST /:unitId/devices`
        *   Description: Assign an existing device to this unit.
        *   Request Body: `{ "deviceId": "String" }`
        *   Response Body (200): `{ "status": "success", "data": { deviceObject } }` (or updated unit object)
        *   Auth: User must be "PROPERTY_MANAGER" of parent property.
    *   `GET /:unitId/devices`
        *   Description: List devices assigned to this unit.
        *   Response Body (200): `{ "status": "success", "data": { "devices": [deviceObject] } }`
        *   Auth: User must be "TENANT" of this unit or manager of parent property.

### Step 4: Implement Backend Business Logic, Authorization & Validation

**Status: PENDING DEFINITION.** This step details the core backend logic implementation.

1.  **Authorization Middleware (e.g., `authTenant.ts` or similar per route/group)**:
    *   **Purpose**: To protect endpoints by ensuring the authenticated user has the necessary permissions for the requested resource and action.
    *   **Mechanism**:
        *   The middleware should be applied to routes after standard JWT authentication.
        *   It will receive the authenticated `user` object (which should ideally have pre-fetched or easily accessible `UserRoleAssociation` data, or the middleware will fetch it based on `userId`).
        *   It will also need context about the resource being accessed (e.g., `portfolioId`, `propertyId`, `unitId` from route parameters) and the required permission level (e.g., "OWNER_OF_PORTFOLIO", "MANAGER_OF_PROPERTY", "TENANT_OF_UNIT").
    *   **Implementation Details**:
        *   Create reusable middleware functions. Example: `requireRole(entityType, entityIdParamName, requiredRoles)`.
        *   Inside the middleware:
            1.  Extract `entityId` from route parameters (e.g., `req.params[entityIdParamName]`).
            2.  Query the `UserRoleAssociation` collection/table for entries matching `userId`, `associatedEntityType` (e.g., "PORTFOLIO"), `associatedEntityId`, and where `roleWithinEntity` is one of the `requiredRoles`.
            3.  If a matching association exists, call `next()`.
            4.  If not, return a `403 Forbidden` error.
        *   For more complex scenarios (e.g., a user managing a portfolio should be able to access its properties), the middleware might need to check roles at a higher level in the hierarchy.
        *   Example: Accessing a property might require checking if the user is a `PROPERTY_MANAGER` for that specific property OR an `OWNER`/`PORTFOLIO_ADMIN` of the parent portfolio.
    *   **Granularity**: Apply middleware at the route level or even to specific HTTP methods within a route for fine-grained control.
    *   **Logging**: Log authorization failures for security monitoring.

2.  **Input Validation**:
    *   **Purpose**: To ensure data received from clients (request bodies, query parameters, route parameters) is valid, well-formed, and meets business rules before processing.
    *   **Tools**: Use a dedicated validation library like `express-validator` (for Express.js), `Joi`, `Zod`, or built-in features of frameworks like NestJS.
    *   **Implementation Details**:
        *   Define validation schemas or rules for each DTO (Data Transfer Object) or request payload.
        *   Validate for:
            *   Presence of required fields.
            *   Correct data types (string, number, boolean, array, object).
            *   String patterns (regex for emails, specific ID formats).
            *   Min/max lengths for strings, min/max values for numbers.
            *   Enum values (e.g., for roles, entity types).
            *   Array contents (e.g., array of strings for `userIds`).
        *   Apply validation middleware early in the request handling chain (before controllers/services).
        *   If validation fails, return a `400 Bad Request` error with clear messages detailing the validation errors (often provided by the library).
    *   **Custom Validation**: Implement custom validation logic for more complex business rules (e.g., checking if a `userId` in a request actually exists in the User collection).

3.  **Service Layer Abstraction (e.g., `PortfolioService.ts`, `PropertyService.ts`, `UnitService.ts`, `UserRoleAssociationService.ts`)**:
    *   **Purpose**: To decouple business logic from route handlers (controllers), making the codebase cleaner, more testable, and easier to maintain.
    *   **Structure**: Each service will manage the business logic related to its specific domain model.
    *   **Responsibilities**:
        *   Interacting with the database models (CRUD operations via ORM/ODM).
        *   Enforcing complex business rules and data integrity (beyond simple validation).
        *   Orchestrating operations that involve multiple models (e.g., when creating a property, also update the parent portfolio's `propertyIds` array, or create `UserRoleAssociation` entries for managers).
        *   Handling errors from database operations and re-throwing them as custom application errors if needed.
    *   **Example (`PortfolioService.createPortfolio(data, creatingUserId)`)**:
        1.  Validate input `data` (though primary validation should be at controller level).
        2.  Create `Portfolio` record in the database.
        3.  If `administratorUserIds` are provided, or if `creatingUserId` should be an admin:
            *   Call `UserRoleAssociationService.createAssociation(userId, portfolioId, "PORTFOLIO", "PORTFOLIO_ADMIN" or "OWNER")` for each admin.
        4.  Return the created `Portfolio` object (or a DTO).
    *   **Dependency Injection**: Use dependency injection to provide services to controllers and other services to each other. This improves testability (services can be mocked).

4.  **Key Business Logic Examples & Considerations**:
    *   **UserRoleAssociation Management**: This is central.
        *   When a user is assigned as a portfolio admin, property manager, or tenant, corresponding entries must be created in `UserRoleAssociation`.
        *   When assignments are revoked, entries must be removed.
        *   Ensure atomicity if multiple database operations are involved (e.g., creating a user and then assigning them a role).
    *   **Cascading Operations / Data Integrity**:
        *   What happens when a Portfolio is deleted? Are its Properties, Units, Devices, and related UserRoleAssociations also deleted (cascade delete)? Or is the deletion prevented if dependencies exist? Define this policy.
        *   Similar considerations for deleting Properties and Units.
        *   Preventing orphaned records (e.g., a `UserRoleAssociation` pointing to a non-existent entity).
    *   **Idempotency**: For operations that might be retried (e.g., adding a user to a role), ensure they are idempotent where possible (executing them multiple times has the same effect as executing them once).
    *   **Invitations**: If inviting users who don't exist yet, a separate invitation flow/model might be needed, creating the `UserRoleAssociation` once the invited user signs up.
    *   **Default Entities**: Logic to set/update `defaultPortfolioId`, `defaultPropertyId`, `defaultUnitId` on the User model when new associations are made or context changes.

5.  **Consistent Error Handling**: (Reinforce from API conventions)
    *   Use a global error handling middleware to catch errors thrown from services/controllers.
    *   Map custom application errors or database errors to appropriate HTTP status codes and structured error responses.
    *   Avoid leaking stack traces or sensitive error details to the client in production.

### Step 5: Update Backend Authentication & Device Endpoints for Tenancy

**Status: PENDING DEFINITION.** This step focuses on making existing auth and device APIs tenant-aware.

1.  **Modify Login/Authentication Response (`POST /api/v1/auth/login` or similar)**:
    *   **Current Behavior (Assumed)**: Returns user object and JWT token.
    *   **Required Enhancement**: The user object in the login response MUST now include their full tenancy context to enable the iOS app to function correctly.
    *   **Response Body Modification**: Ensure the `user` object within the auth response (e.g., `{ "status": "success", "data": { "user": { ... }, "token": "..." } }`) includes:
        *   `roleAssociations: [UserRoleAssociationObject]` (as defined in Backend Model Step 2.5). This is critical for the client to understand all permissions.
        *   `defaultPortfolioId: String?`
        *   `defaultPropertyId: String?`
        *   `defaultUnitId: String?`
    *   **Implementation**: The login controller/service will need to:
        1.  Authenticate the user (check credentials).
        2.  Fetch the basic user profile.
        3.  Fetch all `UserRoleAssociation` entries for this `userId`.
        4.  Fetch/determine the `defaultPortfolioId`, `defaultPropertyId`, and `defaultUnitId` (this logic might reside in `UserService` based on user preferences or recent activity if applicable, or derived from their primary roles).
        5.  Construct the user object with all this tenancy information.
        6.  Generate JWT and return the comprehensive response.
    *   **JWT Payload**: Consider if any essential, non-sensitive tenancy identifiers (like `defaultPropertyId` or primary role context) should be included in the JWT payload itself for quick access by backend middleware. However, `roleAssociations` is likely too large for a JWT; the full details should come from the login response and subsequent `/users/me` calls.

2.  **Update User Profile Endpoint (`GET /api/v1/users/me` or similar)**:
    *   **Purpose**: To allow the client to re-fetch the current user's full profile, including tenancy context, at any time.
    *   **Response Body**: Must be consistent with the user object structure returned in the login response, including `roleAssociations` and default entity IDs.
    *   **Implementation**: Similar to login, fetch the user and all their associated tenancy data.

3.  **Refactor Device Listing Endpoint (e.g., `GET /api/v1/devices`)**:
    *   **Current Behavior (Assumed)**: May list all devices or devices for a single user without clear tenant scoping.
    *   **Required Enhancement**: This endpoint must now only return devices accessible to the authenticated user based on their tenancy.
    *   **Logic**: The service handling this request will:
        1.  Get the authenticated `userId`.
        2.  Fetch the user's `roleAssociations`.
        3.  Based on these associations, compile a list of all `propertyId`s and `unitId`s the user has access to (as manager, tenant, etc.).
        4.  Query the `Devices` collection/table for devices where `propertyId` OR `unitId` is in the compiled list of accessible IDs.
        5.  Implement pagination and filtering (e.g., `?propertyId=`, `?unitId=`) as previously defined in API design (Step 3), ensuring the provided filter IDs are also within the user's allowed scope.
    *   **Authorization**: Implicitly handled by the logic above; only accessible devices are returned.

4.  **Refactor Specific Device Operation Endpoints (e.g., `GET /api/v1/devices/:deviceId`, `POST /api/v1/devices/:deviceId/lock`, `POST /api/v1/devices/:deviceId/unlock`, etc.)**:
    *   **Current Behavior (Assumed)**: May only check if the user owns the device or has a direct link.
    *   **Required Enhancement**: All operations on a specific device must be strictly authorized based on the user's tenancy relationship to the device (via its linked `Unit` and `Property`).
    *   **Implementation (using Authorization Middleware from Step 4.1)**:
        1.  Apply the `authTenant` middleware to these routes.
        2.  The middleware needs to:
            *   Fetch the `deviceId` from `req.params`.
            *   Fetch the `Device` from the database to get its `propertyId` and `unitId`.
            *   Check if the authenticated user has appropriate `UserRoleAssociation` for either the `unitId` (e.g., TENANT of the unit) or the `propertyId` (e.g., PROPERTY_MANAGER of the property). This includes guest access logic if applicable (a guest role association to the unit/property for specific devices).
            *   The required role might differ based on the operation (e.g., viewing status might be more lenient than locking/unlocking).
    *   **Alternative/Combined Approach**: The controller/service for these endpoints can explicitly perform these checks if the middleware is too generic.
        1.  Fetch device, get its `unitId` and `propertyId`.
        2.  Fetch user's `roleAssociations`.
        3.  Loop through associations to see if any grant access to this device's unit or property with a sufficient role.
        4.  If no authorizing association is found, return `403 Forbidden`.

5.  **Review Other User-Specific Endpoints**: Any other endpoints that return lists of resources tied to a user (e.g., user's rooms, if that concept is still separate from Units) must be refactored to respect tenancy boundaries.

### Step 6: Implement iOS Network Service Layer for Multi-Tenancy APIs

**Status: PENDING DEFINITION.** This step outlines how the iOS app will communicate with the new backend APIs.

This involves updating `NetworkService.swift` (or your primary API interaction service, e.g., `APIService.swift`) to include functions for all the new multi-tenancy CRUD endpoints defined in P0 Step 3, and ensuring existing calls correctly handle modified responses (especially for user authentication).

**General Considerations:**
*   **Base URL**: Ensure it points to the correct API version (e.g., `/api/v1`).
*   **Authentication**: All requests should include the JWT token in the appropriate header (e.g., `Authorization: Bearer <token>`). The `NetworkService` should have a mechanism to automatically add this token, possibly fetched from `UserManager` or a keychain service.
*   **Request/Response Types**: Use `Codable` structs for request bodies and parsing response data, corresponding to the DTOs expected/returned by the backend.
*   **Error Handling**: Implement robust error handling. This includes:
    *   Parsing backend error responses (e.g., `{ "status": "error", "message": "..." }`).
    *   Handling network errors (no connectivity, timeouts).
    *   Handling HTTP status codes (401 for unauthorized, 403 for forbidden, 404 for not found, 400 for bad request, 5xx for server errors).
    *   Propagating errors back to the calling service/ViewModel in a structured way (e.g., using a custom `NetworkError` enum or `Result` type).
*   **Combine/Async/Await**: Use modern Swift concurrency (Combine publishers or async/await) for network calls.

1.  **Update Authentication Functions (e.g., `login`, `fetchCurrentUserProfile`)**:
    *   **`login(credentials: LoginCredentials) async throws -> AuthResponse`**: (Or similar Combine-based signature)
        *   Request: Hits `POST /api/v1/auth/login`.
        *   Response Parsing: The `AuthResponse` struct (already exists in iOS `User.swift` based on verification) should now correctly parse the enhanced `User` object from the backend, including `roleAssociations`, `defaultPortfolioId`, `defaultPropertyId`, and `defaultUnitId`. Ensure `User.swift` and its nested structs (`UserRoleAssociation`, `AssociatedEntityType`, `Role`) are fully `Codable` and match the backend's JSON structure.
    *   **`fetchCurrentUserProfile() async throws -> User`**:
        *   Request: Hits `GET /api/v1/users/me`.
        *   Response Parsing: Parses the full `User` object, including all tenancy details, identical to how it's handled in the login response.

2.  **Portfolio Functions (`NetworkService+Portfolio.swift` or similar extension/section)**:
    *   `createPortfolio(name: String, administratorUserIds: [String]?) async throws -> Portfolio`
    *   `fetchPortfolios(page: Int?, limit: Int?, sortBy: String?) async throws -> PaginatedResponse<Portfolio>` (assuming a generic `PaginatedResponse<T>` struct)
    *   `fetchPortfolioDetails(portfolioId: String) async throws -> Portfolio`
    *   `updatePortfolio(portfolioId: String, name: String?, administratorUserIds: [String]?) async throws -> Portfolio`
    *   `deletePortfolio(portfolioId: String) async throws -> Void`
    *   `addPropertyToPortfolio(portfolioId: String, propertyName: String, address: PropertyAddress?, managerUserIds: [String]?) async throws -> Property`
    *   `fetchPropertiesForPortfolio(portfolioId: String) async throws -> [Property]`
    *   `addPortfolioAdmin(portfolioId: String, userId: String, role: User.Role) async throws -> UserRoleAssociation`

3.  **Property Functions (`NetworkService+Property.swift` or similar)**:
    *   `createProperty(name: String, portfolioId: String, address: PropertyAddress?, managerUserIds: [String]?) async throws -> Property` (if allowing direct creation not nested under portfolio route)
    *   `fetchProperties(portfolioId: String?, page: Int?, limit: Int?, sortBy: String?) async throws -> PaginatedResponse<Property>`
    *   `fetchPropertyDetails(propertyId: String) async throws -> Property`
    *   `updateProperty(propertyId: String, name: String?, address: PropertyAddress?, managerUserIds: [String]?) async throws -> Property`
    *   `deleteProperty(propertyId: String) async throws -> Void`
    *   `addUnitToProperty(propertyId: String, unitName: String, tenantUserIds: [String]?, deviceIds: [String]?) async throws -> Unit`
    *   `fetchUnitsForProperty(propertyId: String) async throws -> [Unit]`
    *   `addPropertyManager(propertyId: String, userId: String, role: User.Role) async throws -> UserRoleAssociation`

4.  **Unit Functions (`NetworkService+Unit.swift` or similar)**:
    *   `createUnit(name: String, propertyId: String, tenantUserIds: [String]?, deviceIds: [String]?) async throws -> Unit` (if allowing direct creation)
    *   `fetchUnits(propertyId: String?, page: Int?, limit: Int?, sortBy: String?) async throws -> PaginatedResponse<Unit>`
    *   `fetchUnitDetails(unitId: String) async throws -> Unit`
    *   `updateUnit(unitId: String, name: String?, tenantUserIds: [String]?, deviceIds: [String]?) async throws -> Unit`
    *   `deleteUnit(unitId: String) async throws -> Void`
    *   `addTenantToUnit(unitId: String, userId: String, role: User.Role) async throws -> UserRoleAssociation`
    *   `fetchTenantsForUnit(unitId: String) async throws -> [User]` (ensure `User` object here doesn't contain sensitive info if not needed by client)
    *   `assignDeviceToUnit(unitId: String, deviceId: String) async throws -> Device` (or updated `Unit`)
    *   `fetchDevicesForUnit(unitId: String) async throws -> [Device]`

5.  **Device Fetching Functions (Update existing, e.g., in `NetworkService+Device.swift`)**:
    *   **`fetchDevices(propertyId: String?, unitId: String?, page: Int?, limit: Int?) async throws -> PaginatedResponse<LockDevice>`** (or generic `Device`)
        *   This function will now hit the refactored `GET /api/v1/devices` endpoint.
        *   It can take optional `propertyId` or `unitId` parameters to scope the fetch. If both are nil, the backend will return all devices accessible to the user based on their full tenancy context.
    *   Ensure parsing of `LockDevice` (or other device types) correctly handles any (unlikely) backend model changes.

6.  **Helper Structs for Payloads and Responses**:
    *   Define `Codable` structs for any specific request payloads not directly matching a full model (e.g., `AddAdminToPortfolioRequest { userId: String, role: User.Role }`).
    *   Define a generic `PaginatedResponse<T: Codable>: Codable` struct if the backend uses a consistent pagination wrapper: `struct PaginatedResponse<T: Codable>: Codable { let items: [T]; let pagination: PaginationInfo } struct PaginationInfo: Codable { let totalItems: Int; let totalPages: Int; let currentPage: Int; let pageSize: Int }`.

### Step 7: Update iOS Core Services (UserManager, DeviceService/Manager)

**Status: PENDING DEFINITION.** This step adapts core iOS services to use new network functions and manage tenancy context.

With the Network Service updated to fetch tenancy-aware data, the iOS app's core services need to consume and utilize this information.

1.  **`UserManager.swift` Modifications**:
    *   **Storing Full User Context**: The `currentUser: User?` property (or however the current user is stored, possibly as a `@Published` property if using Combine) must now hold the `User` object that includes `roleAssociations`, `defaultPortfolioId`, `defaultPropertyId`, and `defaultUnitId` as fetched from the backend.
    *   **Login/Logout Process**: 
        *   The `login()` method should call the updated `NetworkService.login()` function and store the complete `User` object (including tenancy info) upon success. It should also securely store the JWT token.
        *   `fetchCurrentUser()` (if it exists, or called on app start) should use `NetworkService.fetchCurrentUserProfile()` to get the full user context.
        *   `logout()` should clear the `currentUser` object and the JWT token.
    *   **Accessing Tenancy Information**: 
        *   The existing convenience methods in `User.swift` (like `roles(forPropertyId:)`, `isManager(ofPropertyId:)`) will be directly usable on the `currentUser` object.
        *   `UserManager` can expose computed properties or functions to provide easy access to the current user's active context or specific roles if needed by ViewModels, e.g.:
            *   `var currentUserRoleAssociations: [User.UserRoleAssociation]? { currentUser?.roleAssociations }`
            *   `var currentUserDefaultPropertyId: String? { currentUser?.defaultPropertyId }`
            *   `func hasRole(_ role: User.Role, inEntityId id: String, ofType type: User.AssociatedEntityType) -> Bool` (This could centralize permission checking logic based on `roleAssociations`).
    *   **Managing Active Context (If Applicable)**:
        *   If the user can belong to multiple properties/portfolios and switch between them, `UserManager` might need to manage the "currently selected" context (e.g., `selectedPropertyId: String?`).
        *   This could be a separate settable property, potentially persisted in `UserDefaults`.
        *   The `defaultPropertyId` from the `User` object can initialize this selected context.

2.  **`DeviceService.swift` / `DeviceManager.swift` (or equivalent `LockDeviceProviderProtocol` implementer) Modifications**:
    *   **Dependency on `UserManager`**: This service will likely need a strong reference to `UserManager` to access the `currentUser`'s tenancy context.
    *   **Fetching Devices Based on Tenancy**: 
        *   Methods like `fetchLocks()` or `getAllDevices()` must be significantly refactored.
        *   They should now use `UserManager.currentUser` to understand the user's scope.
        *   **Primary Strategy**: Call the updated `NetworkService.fetchDevices(propertyId: String?, unitId: String?, ...)` function.
            *   If a `selectedPropertyId` (from `UserManager` or passed in) is available, use that to scope the fetch: `NetworkService.fetchDevices(propertyId: selectedPropertyId, ...)`.
            *   If a `selectedUnitId` is available, use that: `NetworkService.fetchDevices(unitId: selectedUnitId, ...)`.
            *   If no specific context is provided by the UI, it might fetch all accessible devices by calling `NetworkService.fetchDevices(propertyId: nil, unitId: nil, ...)` (relying on the backend to correctly filter based on the user's full tenancy).
        *   The service should then update its internal list of devices (e.g., a `@Published [LockDevice]` array).
    *   **Device Grouping/Filtering**: The service might need to provide functions to filter or group devices by property or unit if the UI requires it, using the `propertyId` and `unitId` fields now available on `LockDevice`.
    *   **Specific Context Device Fetching**: Consider adding functions like `fetchDevices(forProperty propertyId: String)` or `fetchDevices(forUnit unitId: String)` if ViewModels need to request devices for a context other than the user's default/selected one.

3.  **`SecurityService.swift` Interaction (Related to Step 8)**:
    *   While `SecurityService` itself will be updated in Step 8, `UserManager` will be the source of the `User` object (with `roleAssociations`) that `SecurityService` needs to perform its validation checks.
    *   `DeviceService` might provide the `LockDevice` (with its `propertyId` and `unitId`) to `SecurityService`.

4.  **Caching and Data Synchronization**:
    *   Consider if/how tenancy information (like the `UserRoleAssociation` list) should be cached on the client to avoid re-fetching on every permission check.
    *   Strategize when to refresh the `currentUser` object from the backend (e.g., on app foreground, after certain operations).

### Step 8: Modify iOS DAL (`LockDAL.swift`) for Tenancy-Aware Security

**Status: Partially addressed in `LockDevice.swift` model, but `SecurityService.swift` requires full implementation.**

The `SecurityService.swift` is the central authority for validating if a user can perform an operation on a device. It needs to be significantly enhanced to use the detailed multi-tenancy context.

1.  **`SecurityService.swift` - Core Validation Logic**: 
    *   **Primary Method (Example Signature)**: `func canUser(_ user: User, performOperation operation: LockOperationType, onDevice device: LockDevice) -> Bool` (or an async version if it needs to fetch additional data, though ideally, `user` and `device` objects are passed in fully populated).
    *   **Input**: 
        *   `user: User`: The complete User object, including `roleAssociations` and default entity IDs (provided by `UserManager`).
        *   `device: LockDevice`: The complete LockDevice object, including its `propertyId` and `unitId` (provided by `DeviceService`).
        *   `operation: LockOperationType`: The specific operation being attempted (e.g., lock, unlock, viewStatus, changeSettings).
    *   **Logic Flow**:
        1.  **Basic Checks**: 
            *   Is the device online (if required for the operation)?
            *   Is remote operation enabled on the device (`device.isRemoteOperationEnabled`)?
        2.  **Leverage `LockDevice.canPerformRemoteOperation` (as a preliminary check if kept)**: The existing logic in `LockDevice.canPerformRemoteOperation(by user: User)` can serve as an initial filter or be merged/refactored into `SecurityService`.
        3.  **Comprehensive Role-Based Access Control (RBAC) using `user.roleAssociations`**:
            *   Iterate through `user.roleAssociations`.
            *   For each association, check if it grants permission for the `operation` on the `device`:
                *   **Unit-Level Access (e.g., Tenant)**:
                    *   If `association.associatedEntityType == .unit` and `association.associatedEntityId == device.unitId`:
                        *   Check if `association.roleWithinEntity == .tenant`. If so, allow operations typically permitted for tenants (e.g., lock/unlock their own unit's door). Certain operations might be restricted (e.g., changing device settings).
                *   **Property-Level Access (e.g., Property Manager)**:
                    *   If `association.associatedEntityType == .property` and `association.associatedEntityId == device.propertyId`:
                        *   Check if `association.roleWithinEntity == .propertyManager`. If so, allow broader operations on devices within that property (e.g., lock/unlock any unit door, manage common area devices, potentially settings).
                *   **Portfolio-Level Access (e.g., Portfolio Admin/Owner)**:
                    *   If `association.associatedEntityType == .portfolio`:
                        *   To check this, `SecurityService` would need a way to determine if `device.propertyId` belongs to the `association.associatedEntityId` (the portfolioId).
                        *   This might require `SecurityService` to have access to a (potentially cached) list of properties per portfolio, or a helper function in another service (e.g., `PropertyService.isProperty(_ propertyId: String, inPortfolio portfolioId: String) -> Bool`).
                        *   If the device is within an authorized portfolio and the role is `PORTFOLIO_ADMIN` or `OWNER`, grant extensive permissions.
                *   **Guest Access**: If `user.role == .guest` (or a specific guest association type):
                    *   Check `user.guestAccess` details: `validFrom`, `validUntil`, `deviceIds` array, and if `unitId` or `propertyId` in `guestAccess` matches the device's context.
            *   **Operation-Specific Permissions**: The set of allowed operations will vary by role. Maintain a clear mapping of which roles can do what.
        4.  **Default Deny**: If no association explicitly grants permission, return `false`.
    *   **Return Value**: `true` if allowed, `false` otherwise. Could also return a `Result<Void, SecurityError>` to provide reasons for denial.

2.  **Integration with `LockDAL.swift`**:
    *   The methods in `LockDAL.swift` (e.g., `lock(deviceId: String, userId: String)`, `unlock(...)`) should call the `SecurityService.canUser(...)` method before attempting to send a command to a lock adapter.
    *   `LockDAL` will need to fetch the full `User` object (from `UserManager`) and `LockDevice` object (from `DeviceService`) to pass to `SecurityService`.
    *   If `SecurityService` denies the operation, `LockDAL` should throw an appropriate error (e.g., `LockDALError.accessDenied`).

3.  **Refinement of `LockDevice.canPerformRemoteOperation`**: 
    *   Decide if this method on the `LockDevice` model should remain as a convenience/preliminary check or if its logic should be fully consolidated into `SecurityService`.
    *   If kept, ensure it's clear that `SecurityService` is the final arbiter.
    *   The current comments in `LockDevice.canPerformRemoteOperation` about portfolio-level checks needing a service layer align with `SecurityService` taking on this broader responsibility.

4.  **Error Types**: Define specific error types (e.g., `SecurityError.permissionDenied`, `SecurityError.invalidRoleForOperation`) that can be thrown and handled by the UI layer to provide meaningful feedback.

### Step 9: Initial UI/ViewModel Scoping for Multi-Tenancy

**Status: PENDING DEFINITION.** This step outlines necessary UI and ViewModel adaptations for multi-tenancy.

The introduction of multi-tenancy will require changes to the UI to allow users to navigate and interact with data within their permitted contexts (portfolios, properties, units). ViewModels will need to be updated to manage and provide this context-specific data to the Views.

**General UI/UX Principles for Multi-Tenancy:**
*   **Clear Context Indication**: The user should always understand which portfolio, property, or unit context they are currently viewing/managing.
*   **Easy Context Switching**: If a user has access to multiple entities (e.g., a property manager for several properties), switching between these contexts should be intuitive.
*   **Scoped Data Display**: Lists of devices, units, etc., must only display items relevant to the current active context and permitted by the user's roles.
*   **Role-Appropriate Actions**: UI elements for actions (buttons, menus) should only be enabled/visible if the user's role in the current context permits that action.

1.  **Context Selection UI (If Applicable)**:
    *   **Scenario**: For users who can access multiple entities at the same level (e.g., a Portfolio Admin for multiple Portfolios, or a Property Manager for multiple Properties).
    *   **Implementation Ideas**:
        *   **Dropdown/Picker**: A `Picker` in the main navigation bar or a settings screen to select the active Portfolio or Property.
        *   **List View with Navigation**: A dedicated view listing all accessible Portfolios/Properties, allowing the user to drill down.
        *   **Tab Bar (Less Likely for Deep Hierarchy)**: If a user only has a few top-level contexts.
    *   **State Management**: The selected context (e.g., `selectedPortfolioId`, `selectedPropertyId`) should be managed, possibly by `UserManager` or a dedicated UI state service, and ViewModels should observe this state.
    *   `UserManager.defaultPortfolioId` or `UserManager.defaultPropertyId` can be used to set the initial selection.

2.  **Device List View (`LockListView.swift`, `DevicesView.swift`, or similar)**:
    *   **ViewModel (`LockListViewModel.swift`, etc.) Changes**:
        *   The ViewModel will now depend on `UserManager` to know the `currentUser` and their selected/default context (e.g., `selectedPropertyId` or `selectedUnitId`).
        *   It will call the updated `DeviceService.fetchDevices(propertyId: ..., unitId: ...)` method, passing the appropriate context ID.
        *   If no specific context is selected (and the user role allows a broader view, e.g., a portfolio admin), it might fetch all devices accessible to the user, with the UI potentially grouping them by property/unit.
    *   **View Changes**:
        *   The title or a header in the view should indicate the current context (e.g., "Devices in Property X").
        *   If displaying devices from multiple sub-contexts (e.g., all units in a property), use sections or other visual grouping.

3.  **Unit List View (If a distinct view for listing units within a property exists or is needed)**:
    *   **ViewModel Changes**:
        *   Will fetch units for a specific `propertyId` (obtained from the current context).
        *   Uses `NetworkService.fetchUnitsForProperty(propertyId: ...)` via a corresponding `PropertyService` or `UnitService` method.
    *   **View Changes**: Displays a list of `Unit` items, allowing navigation to a `UnitDetailView` or `DeviceListView` scoped to that unit.

4.  **Property List View (If applicable for high-level admins)**:
    *   **ViewModel Changes**:
        *   Fetches properties for a specific `portfolioId` or all accessible properties based on user role.
        *   Uses `NetworkService.fetchPropertiesForPortfolio(portfolioId: ...)` or `NetworkService.fetchProperties(...)` via a service.

5.  **Detail Views (`LockDetailView.swift`, `UnitDetailView.swift`, `PropertyDetailView.swift`)**:
    *   **ViewModel Changes**:
        *   Ensure the ViewModel is initialized with the correct entity ID (e.g., `LockDetailViewModel(deviceId: String, unitId: String, propertyId: String)`).
        *   Actions (e.g., toggling a lock) will call `LockDAL` methods, which now internally use `SecurityService` for authorization. The ViewModel should be prepared to handle potential `SecurityError.permissionDenied` errors and update the UI accordingly (e.g., show an alert, disable the control).
    *   **View Changes**: No major changes expected unless displaying context-specific information or actions.

6.  **User Profile / Settings View**:
    *   May need to display the user's current roles and associations (e.g., "Manager of Property X", "Tenant of Unit Y").
    *   If context switching is managed here, provide UI for it.

7.  **Role-Based UI Elements**: 
    *   ViewModels should expose properties indicating if the current user can perform certain actions based on their role in the current context (e.g., `canEditPropertyDetails: Bool`, `canAddUnit: Bool`).
    *   Views will use these properties to conditionally enable/disable or show/hide buttons and other interactive elements (e.g., an "Edit" button might be disabled if the user is not a manager of the current property).
    *   This relies on `UserManager` and `SecurityService` (or convenience methods on `User` model) providing the necessary permission checks.

8.  **Handling Empty States**: If a user has access to a property but there are no units or devices, or if a tenant has no assigned devices, the UI should display a clear empty state message, possibly with guidance on next steps (e.g., "No devices found in Unit X. Contact your property manager.").

### Step 10: Testing Strategy for P0 Multi-Tenancy

**Status: PENDING DEFINITION.** This step outlines the testing approach for the multi-tenancy features.

A comprehensive testing strategy is essential to ensure the multi-tenancy implementation is correct, secure, and reliable.

1.  **Backend - Unit Tests**:
    *   **Focus**: Test individual modules, services, and helper functions in isolation.
    *   **Models**: 
        *   Validation logic (e.g., can a `UserRoleAssociation` be created with an invalid `associatedEntityType`?).
        *   Any custom methods or virtual properties on models.
    *   **Services (e.g., `PortfolioService`, `PropertyService`, `UnitService`, `UserRoleAssociationService`, `UserService`)**: 
        *   Mock database interactions (ORM/ODM calls) to test business logic purely.
        *   Test creation, retrieval, update, and deletion logic for each service.
        *   Verify correct creation/deletion of `UserRoleAssociation` entries when parent entities are managed.
        *   Test error handling (e.g., what happens if a dependent record is not found?).
        *   Test logic for determining default portfolio/property/unit for a user.
    *   **Authorization Middleware Helpers (if any logic is extracted)**: Test functions that determine access based on roles and associations.
    *   **Input Validation Helpers**: Test any custom validation functions.

2.  **Backend - Integration Tests**:
    *   **Focus**: Test the interaction between different components, including API endpoints, services, and the database.
    *   **Setup**: Use a dedicated test database seeded with appropriate test data (various user roles, portfolios, properties, units, devices, and role associations).
    *   **API Endpoint Tests**:
        *   For each endpoint defined in Step 3:
            *   Test successful CRUD operations (POST, GET, PUT, DELETE) with valid inputs and appropriate user roles/permissions.
            *   Test authorization: Attempt to access/modify resources with insufficient permissions (wrong role, no association, wrong user) and verify `403 Forbidden` or `401 Unauthorized` responses.
            *   Test input validation: Send invalid/missing data and verify `400 Bad Request` responses with clear error messages.
            *   Test edge cases (e.g., deleting a portfolio with properties, trying to create entities with non-existent parent IDs).
            *   Verify correct data is returned, including populated fields and correct filtering for list endpoints.
        *   **Specific Scenarios**: 
            *   Login (`/auth/login`): Verify the response includes the correct `roleAssociations` and default entity IDs.
            *   Device Listing (`/devices`): Verify it only returns devices accessible to the authenticated user based on their tenancy.
            *   Device Operations (`/devices/:id/action`): Verify operations are blocked/allowed correctly based on tenancy.
    *   **Data Integrity**: Test that relationships between entities are correctly maintained (e.g., creating a property correctly links to a portfolio).

3.  **iOS - Unit Tests**:
    *   **Focus**: Test individual Swift classes, structs, and functions in isolation.
    *   **Models (`Portfolio`, `Property`, `Unit`, `User`, `LockDevice`, `UserRoleAssociation`)**: 
        *   `Codable` conformance (encoding and decoding to/from mock JSON).
        *   Initialization logic.
        *   Any computed properties or helper methods (e.g., `User.isManager(ofPropertyId:)`).
    *   **ViewModels (e.g., `LockListViewModel`, `PropertyViewModel`, etc.)**: 
        *   Mock services (`NetworkService`, `UserManager`, `DeviceService`, `SecurityService`).
        *   Test that ViewModels correctly call service methods based on input or state changes.
        *   Test logic for transforming data from services into UI-publishable properties.
        *   Test state management (e.g., `isLoading`, error states).
        *   Test permission-based properties (e.g., `canEditPropertyDetails`).
    *   **Services (`UserManager`, `DeviceService`, `SecurityService`, `NetworkService` - Mocked Network Layer)**:
        *   `UserManager`: Test login/logout logic, storage/retrieval of `currentUser` with tenancy info, management of selected context.
        *   `DeviceService`: Test logic for fetching devices based on different tenancy contexts (mocking `NetworkService` responses).
        *   `SecurityService`: Test the core validation logic (`canUserPerformOperation`) with various `User` and `LockDevice` mock objects representing different roles and scenarios. (This is critical).
        *   `NetworkService`: While harder to unit test directly (often requires integration tests), any internal data mapping or request-building logic can be unit tested with mocked inputs/outputs.

4.  **iOS - Integration Tests**:
    *   **Focus**: Test interactions between different components of the app, typically with a mocked backend.
    *   **ViewModel-Service Interactions**: Verify that ViewModels correctly interact with Services (`UserManager`, `DeviceService`, `SecurityService`, `NetworkService`) and handle their responses (success/error).
        *   Example: Simulate a login, ensure `UserManager` updates, then a `LockListViewModel` fetches devices, and `DeviceService` uses the tenancy context from `UserManager` to make the (mocked) network call.
    *   **Data Flow**: Ensure data flows correctly from mocked network responses -> `NetworkService` -> `Data Services` -> `ViewModels` -> UI properties.
    *   **Security Flow**: Test that attempting an action in a ViewModel correctly triggers `LockDAL` -> `SecurityService` checks, and the UI reacts appropriately to permission denial (using mocked `SecurityService` responses).
    *   **Context Switching**: If UI for context switching exists, test that changing the active context correctly updates data displayed in relevant ViewModels.

5.  **End-to-End (E2E) Manual Testing Scenarios (Crucial for UX and complex interactions)**:
    *   **User Persona-Based Testing**: Define key user personas (Portfolio Owner, Portfolio Admin, Property Manager, Tenant, Guest) and test their complete flows.
    *   **Scenario 1: Portfolio Owner/Admin Setup**
        1.  Owner signs up/logs in.
        2.  Owner creates a new Portfolio.
        3.  Owner adds another user as a Portfolio Admin to this Portfolio.
        4.  New Portfolio Admin logs in, can see and manage the assigned Portfolio.
        5.  Owner/Admin creates a Property within the Portfolio.
        6.  Owner/Admin assigns a user as a Property Manager for this Property.
    *   **Scenario 2: Property Manager Operations**
        1.  Property Manager logs in, sees only their assigned Properties.
        2.  PM selects a Property.
        3.  PM creates a Unit within the Property.
        4.  PM assigns a Device (Lock) to the Unit.
        5.  PM assigns a Tenant to the Unit.
        6.  PM views/operates devices within their managed Property.
    *   **Scenario 3: Tenant Experience**
        1.  Tenant logs in, sees only their assigned Unit(s) and associated devices.
        2.  Tenant can operate locks in their Unit.
        3.  Tenant attempts to access devices in another Unit or Property (should be denied).
    *   **Scenario 4: Guest Access (If implemented in P0)**
        1.  Tenant or PM grants guest access to a specific lock for a limited time.
        2.  Guest logs in (or uses guest link), can only operate the permitted lock during the valid window.
    *   **Scenario 5: Negative Cases - Permission Denials**
        *   Systematically try actions that should be denied based on role and context (e.g., Tenant trying to add a new Unit, Property Manager trying to delete a Portfolio they don't own).
        *   Verify clear error messages or disabled UI elements.
    *   **Scenario 6: Context Switching (If UI supports it)**
        *   User with multiple property assignments switches active property context.
        *   Verify all relevant views (device lists, unit lists) update to reflect the new context.
    *   **Cross-Cutting Concerns**: Test across different device types, network conditions (simulated offline/slow network).

---
*(This concludes the detailed planning for P0. P1 and P2 will be detailed next.)*

## P1: "$1 Compliance Pack" In-App Purchase (iOS & Backend Stub)

**Goal**: Users can purchase a "Compliance Pack" add-on via standard Apple In-App Purchase. The app recognizes the purchase, and a placeholder for the feature is visible. The actual detailed compliance report generation can be a future enhancement.

**Status: PENDING DEFINITION.**

### Step 1: App Store Connect Setup (Manual Task)

1.  **Define IAP Product**:
    *   Log in to App Store Connect.
    *   Navigate to "App Store" -> "In-App Purchases" for your app.
    *   Create a new **Non-Consumable** In-App Purchase product.
    *   **Reference Name**: E.g., "Compliance Pack Add-on"
    *   **Product ID**: E.g., `com.unifiedsmarthome.compliancepack1` (must be unique).
    *   **Pricing**: Set to $0.99 (or desired tier).
    *   **Localization**: Add display name (e.g., "Compliance Pack") and description for the App Store.
    *   **Review Information**: Add a screenshot and notes for the Apple review team.
    *   **Availability**: Make sure it's marked as "Cleared for Sale".

### Step 2: Backend Stub for IAP Validation & Feature Flag (Minimal)

While full server-side receipt validation is best practice, for a Sunday deadline and a stubbed feature, the backend might only need minimal involvement initially if client-side unlocking is temporarily accepted. However, aiming for a simple validation endpoint is better.

1.  **Optional: Simple Receipt Validation Endpoint (`POST /api/v1/iap/validate-receipt`)**:
    *   **Purpose**: Allow the iOS app to send the App Store receipt for server-side validation and to record/flag the feature enablement for the user.
    *   **Request Body**: `{ "receiptData": "String" (base64 encoded receipt), "productId": "String" }`
    *   **Logic (Simplified for Stub)**:
        1.  Receive receipt data.
        2.  (Highly Recommended) Forward to Apple's `verifyReceipt` endpoint (`https://buy.itunes.apple.com/verifyReceipt` or `https://sandbox.itunes.apple.com/verifyReceipt`).
        3.  Parse Apple's response. If valid for the `productId`:
            *   Update a flag on the `User` model (e.g., `hasCompliancePack: Bool = true`) or in a separate `UserFeatures` collection.
            *   Return success to the client.
        4.  If invalid, return an error.
    *   **Response Body (200)**: `{ "status": "success", "data": { "message": "Feature enabled", "user": updatedUserObject (optional) } }`
    *   **Auth**: Requires authenticated user.

2.  **Update User Model (Backend - Step P0.2 Revisited)**:
    *   Add: `hasCompliancePack: Boolean` (default `false`) to the `User` model/schema.

3.  **Update Auth/User Profile Responses (Backend - Step P0.5 Revisited)**:
    *   Ensure `POST /api/v1/auth/login` and `GET /api/v1/users/me` responses include the `hasCompliancePack` field in the user object. This allows the client to know the feature status immediately on login/refresh.

### Step 3: iOS In-App Purchase Implementation

Use Apple's `StoreKit` framework.

1.  **Create `IAPManager.swift` (or similar service)**:
    *   **Responsibilities**: 
        *   Fetching product information from App Store Connect.
        *   Initiating purchase flows.
        *   Handling transaction updates (purchased, failed, restored).
        *   Validating receipts (client-side for P1 MVP if server-side is deferred, but strongly advise against for production; or calling the backend validation endpoint).
        *   Persisting purchase status (e.g., in `UserDefaults` or by relying on `UserManager.currentUser.hasCompliancePack`).
        *   Providing a way for ViewModels to observe purchase status.
    *   **Fetch Products**: 
        *   Use `SKProductsRequest` to fetch details of the "Compliance Pack" IAP product using its Product ID.
        *   Store the `SKProduct` object for display and purchase.
    *   **Initiate Purchase**: 
        *   When a user taps a "Buy Compliance Pack" button, create an `SKPayment` with the fetched `SKProduct` and add it to the `SKPaymentQueue.default()`.
    *   **Handle Transaction Updates (`SKPaymentTransactionObserver`)**: 
        *   Conform `IAPManager` to `SKPaymentTransactionObserver`.
        *   Implement `paymentQueue(_:updatedTransactions:)`:
            *   Switch on `transaction.transactionState`:
                *   `.purchased`: 
                    1.  **Receipt Validation**: 
                        *   (Preferred) Send `transaction.transactionReceipt` (if available) or `Bundle.main.appStoreReceiptURL` to your backend validation endpoint (`POST /api/v1/iap/validate-receipt`).
                        *   (Fallback/Temporary for P1 stub if backend is not ready - NOT FOR PRODUCTION) Perform minimal client-side checks or assume valid for stub.
                    2.  **Unlock Feature**: If valid, update `UserManager.currentUser.hasCompliancePack = true` (or a local flag observed by UI). Call `UserManager.updateUserLocally(user)` or similar if `currentUser` is a struct.
                    3.  `SKPaymentQueue.default().finishTransaction(transaction)`.
                *   `.failed`: Handle error (e.g., user cancelled, payment failed). `SKPaymentQueue.default().finishTransaction(transaction)`.
                *   `.restored`: Similar to `.purchased` - validate receipt, unlock feature. `SKPaymentQueue.default().finishTransaction(transaction)`.
                *   `.purchasing`, `.deferred`: Update UI if necessary (e.g., show loading indicator).
    *   **Restore Purchases**: Implement a "Restore Purchases" button that calls `SKPaymentQueue.default().restoreCompletedTransactions()`.

2.  **Update `UserManager.swift` (iOS - Step P0.7 Revisited)**:
    *   Add `var hasCompliancePack: Bool` to the local `User` struct/class if not already there (should mirror backend).
    *   The `currentUser` object should reflect this status, updated after successful purchase/validation or fetched from login/profile API.
    *   Potentially add a method `updateUserPurchaseStatus(hasCompliancePack: Bool)`.

### Step 4: UI for Compliance Pack Feature

1.  **Purchase Button/UI Element**: 
    *   In a relevant part of the app (e.g., Settings screen, or a dedicated "Add-ons" section).
    *   Display the name and price of the Compliance Pack (fetched via `SKProduct`).
    *   Button action: `IAPManager.shared.purchaseProduct(product: compliancePackProduct)`.
    *   Disable/hide this button if `UserManager.currentUser.hasCompliancePack` is true.

2.  **Indication of Enabled Feature (Placeholder)**:
    *   If `UserManager.currentUser.hasCompliancePack` is true:
        *   Show a new section/item in the UI, e.g., "View Compliance Report" (even if it navigates to an empty/"Coming Soon" view for P1).
        *   Alternatively, a simple toggle/checkmark in settings indicating the pack is active.

3.  **"Restore Purchases" Button**: 
    *   Typically in the Settings screen.
    *   Calls `IAPManager.shared.restorePurchases()`.

---

## P2: Critical Fixes & Testing (Post-P0 & P1 Implementation)

**Goal**: Ensure the stability, correctness, and usability of all P0 (Multi-Tenancy) and P1 (IAP) features before submission. This is an iterative phase of testing, bug fixing, and refinement.

**Status: PENDING EXECUTION.**

1.  **Execute P0 Testing Strategy**: 
    *   Systematically go through all test types and scenarios defined in **P0 Step 10** (Backend Unit/Integration, iOS Unit/Integration, E2E Manual Testing).
    *   Log all bugs and issues encountered.

2.  **IAP Testing (P1)**:
    *   **Sandbox Environment**: Use App Store Connect sandbox tester accounts.
    *   Test the entire purchase flow for the Compliance Pack.
    *   Test purchase restoration.
    *   Test UI updates correctly based on purchase status.
    *   Verify (if backend validation exists) that the backend user record is updated.
    *   Test with different sandbox scenarios (e.g., interrupted purchase, payment failure).

3.  **Bug Fixing**: 
    *   Prioritize and fix bugs identified during P0 and P1 testing. Focus on critical and high-priority issues first.
    *   Perform regression testing after fixes to ensure no new issues were introduced.

4.  **UI/UX Refinement**: 
    *   Based on E2E testing, identify any areas where the multi-tenancy UI or IAP flow is confusing, inefficient, or error-prone.
    *   Make necessary adjustments to views, navigation, and user feedback (error messages, loading states).

5.  **Performance Testing (Basic)**:
    *   Ensure key list views (devices, units, properties) load reasonably quickly, especially with a moderate amount of test data reflecting multi-tenancy.
    *   Monitor app responsiveness during core operations.

6.  **Security Review (High-Level for Sunday)**:
    *   Double-check that all new backend APIs have appropriate authentication and authorization middleware (as per P0 Step 4).
    *   Ensure sensitive data is not being inadvertently exposed in API responses.
    *   Review IAP receipt validation logic for robustness (server-side is key long-term).

7.  **Final Sanity Checks**: 
    *   Test on multiple device types and iOS versions (if possible).
    *   Review all UI text for typos and clarity.
    *   Ensure app icons, launch screens, and App Store metadata are prepared.

*(This concludes the high-level planning for P1 and P2. Implementation will require diving deep into StoreKit and thorough testing of all tenancy and IAP flows.)* 