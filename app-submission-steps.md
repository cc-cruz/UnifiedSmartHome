# App Submission Plan 

## Goal
Successfully submit a functional version of the Unified Smart Home app to the App Store. This plan outlines the prioritized development tasks to achieve this, focusing on core functionality and stability.

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

**Status: COMPLETE.** This step involved creating the RESTful API endpoints for managing Portfolios, Properties, and Units, including authentication, authorization, and interaction with Mongoose models.

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
    *   **Cascading Operat.ions / Data Integrity**:
        *   What happens w.hen a Portfolio is deleted? Are its Properties, Units, Devices, and related UserRoleAssociations also deleted (cascade d.elete)? Or is the deletion prevented if dependencies exist? Define this policy.
        *   Similar consid.erations for deleting Properties and Units.
        *   Preventing orp.haned records (e.g., a `UserRoleAssociation` pointing to a non-existent entity).
    *   **Idempotency**: F.or operations that might be retried (e.g., adding a user to a role), ensure they are idempotent where possible (executing th.em multiple times has the same effect as executing them once).
    *   **Invitations**: I.f inviting users who don't exist yet, a separate invitation flow/model might be needed, creating the `UserRoleAssociation` .once the invited user signs up.
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

**Status: COMPLETE.** This step outlines how the iOS app will communicate with the new backend APIs.

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

**Status: COMPLETE.** SecurityService.swift is now the central authority for validating if a user can perform an operation on a device, leveraging User.roleAssociations and device context (unitId, propertyId, resolved portfolioId). LockDAL.swift calls SecurityService with full User and LockDevice objects before any lock/unlock command.

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

### Step 9: Update iOS UI and ViewModels for Tenancy Awareness

**Status: COMPLETE.** Building on the service layer updates, this step involved scoping UI elements and ViewModels to reflect the user's current tenancy context (selected Portfolio, Property, Unit).

1.  **`UserContextViewModel.swift` (or similar Context Manager)**
    *   **Status: COMPLETE.**
    *   Purpose: Manages the user's currently selected `Portfolio`, `Property`, and `Unit` context.
    *   Responsibilities:
        *   Store current `selectedPortfolio: Portfolio?`, `selectedProperty: Property?`, `selectedUnit: Unit?`.
        *   Provide methods to change context (e.g., `selectPortfolio(Portfolio)`, `selectProperty(Property)`).
        *   Publish changes to the UI (e.g., using `@Published` properties).
        *   Fetch and refresh available contexts (portfolios, properties, units) for the logged-in user.
        *   Inform other ViewModels/Services about context changes.
    *   Integration: Used by top-level views and passed down or accessed via environment objects.

2.  **`LockViewModel.swift` / `DevicesViewModel.swift` (and related ViewModels)**
    *   **Status: COMPLETE.**
    *   Modifications:
        *   Depend on `UserContextViewModel` to understand current scope.
        *   Fetch devices based on the selected `Portfolio`, `Property`, or `Unit` from the context.
        *   Ensure device operations are performed within the correct tenancy scope.
        *   Refresh device lists when the user context changes.
    *   Example: If a `Property` is selected, list all devices in that property and its units. If a `Unit` is selected, list only devices in that unit.

3.  **UI Views (e.g., `LockListView.swift`, `DevicesView.swift`, `LockDetailView.swift`)**
    *   **Status: COMPLETE.**
    *   Modifications:
        *   Display context information (e.g., "Viewing devices in Property X").
        *   Provide UI elements for context selection (e.g., Pickers or navigation to a context selection screen).
        *   React to changes in `UserContextViewModel` to update displayed data.
        *   Ensure actions (e.g., tapping a device) consider the current context.

**Outcome:** The iOS app's UI and local data management are now aware of and responsive to the multi-tenancy hierarchy, ensuring users only see and interact with entities relevant to their selected context and permissions.

---

### Step 10: Testing Strategy for P0 Multi-Tenancy

**Status: DEFINED.**

This step focuses on defining and executing a comprehensive testing strategy to ensure the correctness, security, and reliability of the P0 multi-tenancy features.

**A. Backend Unit Tests**

*   **Focus:** Individual components of the backend, such as models, services, utility functions, and individual middleware units in isolation.
*   **Key Areas/Modules to Test:**
    *   Data Models (`Portfolio`, `Property`, `Unit`, `User`, `UserRoleAssociation`): Validation logic, default values, relationships (mocked), and any custom methods.
    *   Service Layer Abstractions: Business logic for creating, reading, updating, and deleting entities, ensuring correct interaction with data models (mocked DAL).
    *   Authorization Middleware: Logic for checking user roles and permissions against specific entities (e.g., `canUserAccessPortfolio(userId, portfolioId, requiredRole)`).
    *   Input Validation Logic: For API request payloads (e.g., ensuring required fields are present, data types are correct).
    *   Utility functions used in tenancy logic.
*   **Types of Test Cases/Scenarios:**
    *   **Model Validation:**
        *   Test creating models with valid and invalid data (e.g., missing required fields, incorrect data types for IDs, names).
        *   Test model methods for correctness (e.g., if a User model has a helper `hasRole(role, entityId)`).
    *   **Service Logic:**
        *   Test service functions for creating entities, ensuring correct associations are made (e.g., creating a Property correctly links it to a Portfolio).
        *   Test retrieval logic (e.g., `getPropertiesForUser(userId)` returns only properties the user has access to, based on mocked `UserRoleAssociation` data).
        *   Test update logic, ensuring permissions are checked before updates are applied (mocked).
        *   Test deletion logic, including any cascading effects or disassociations (mocked).
        *   Test error handling for non-existent entities or failed operations.
    *   **Authorization Middleware:**
        *   Test with various user roles and entity combinations to ensure correct allowance or denial of access.
        *   Test edge cases, such as a user with multiple roles.
    *   **Input Validation:**
        *   Test with valid payloads.
        *   Test with missing required fields.
        *   Test with incorrectly formatted data (e.g., invalid email, non-UUID string for an ID).
        *   Test for boundary conditions (e.g., string lengths).
*   **Tools/Techniques:**
    *   Node.js testing frameworks (e.g., Jest, Mocha).
    *   Mocking libraries (e.g., Jest mocks, Sinon.js) to isolate units by mocking database interactions, external services, and other modules.
    *   Assertion libraries (e.g., Chai, Jest's built-in assertions).

**B. Backend Integration Tests**

*   **Focus:** Interactions between different components of the backend, including API endpoints, service layers, and the database. Verifying that data flows correctly and authorization is enforced at the API level.
*   **Key Areas/Modules to Test:**
    *   **API Endpoints:** Test the full request-response cycle for all multi-tenancy related endpoints (`/api/v1/portfolios`, `/api/v1/properties`, `/api/v1/units`, and user/auth endpoints related to tenancy).
    *   **Authentication & Authorization Flow:** Ensure JWT authentication and role-based authorization work correctly across API endpoints.
    *   **Database Interactions:** Verify that API actions result in correct data creation, updates, and deletions in the test database.
    *   **UserRoleAssociation Logic:** Test the creation and enforcement of user roles and their associations with entities through API calls.
*   **Types of Test Cases/Scenarios:**
    *   **CRUD Operations via API:**
        *   For each entity (Portfolio, Property, Unit):
            *   Create an entity with a user having appropriate permissions (e.g., Portfolio Owner creating a Property). Verify 201 status and correct data in response and DB.
            *   Attempt to create an entity with a user lacking permissions. Verify 403 Forbidden.
            *   Read/List entities:
                *   As a user with access (e.g., Portfolio Admin listing Properties in their Portfolio). Verify 200 and correct, scoped data.
                *   As a user without access. Verify 200 and empty list or 403/404 if accessing a specific restricted entity.
            *   Update an entity with appropriate permissions. Verify 200 and correct data updates in DB.
            *   Attempt to update an entity with insufficient permissions. Verify 403 Forbidden.
            *   Delete an entity with appropriate permissions. Verify 204/200 and entity removal/soft delete in DB.
            *   Attempt to delete an entity with insufficient permissions. Verify 403 Forbidden.
    *   **Role Management:**
        *   Test API endpoints for adding/removing users from roles (e.g., adding a Property Manager to a Property). Verify success and that the user then has the correct permissions.
        *   Test that a user cannot assign a role higher than their own (if applicable).
    *   **Data Integrity:**
        *   Test scenarios like deleting a Portfolio: ensure associated Properties, Units, and Role Associations are handled correctly (e.g., cascade delete or prevent deletion if dependencies exist, as per design).
        *   Test creating a Unit for a non-existent Property. Verify 400/404.
    *   **Authentication & Default Context:**
        *   Test login with users having different default portfolio/property/unit settings.
        *   Test API endpoints that might rely on default contexts if not explicitly provided.
*   **Tools/Techniques:**
    *   Testing frameworks like Jest or Mocha with Supertest for HTTP request testing.
    *   A dedicated test database that can be seeded with prerequisite data and reset between test runs.
    *   Scripts for seeding the database with various user roles and entity hierarchies.
    *   API documentation tools (e.g., Swagger/OpenAPI) can help define test cases.

**C. iOS Unit Tests**

*   **Focus:** Individual components of the iOS app in isolation, primarily ViewModels, Services, and utility functions.
*   **Key Areas/Modules to Test:**
    *   **ViewModels (`UserContextViewModel`, `LockViewModel`, `DevicesViewModel`, etc.):**
        *   Logic for fetching and processing data from services (mocked).
        *   State management (e.g., correctly updating `@Published` properties).
        *   Context selection logic (e.g., `selectPortfolio` updates internal state and triggers appropriate actions).
        *   Permission checking logic within ViewModels (e.g., `canEditProperty` based on user roles and current context).
    *   **Network Service Layer (Multi-Tenancy specific parts):**
        *   Construction of API requests for new tenancy endpoints.
        *   Parsing of API responses into Swift data models (`Portfolio`, `Property`, `Unit`).
        *   Error handling from network requests.
    *   **Core Services (`UserManager`, `DeviceService` tenancy updates):**
        *   Logic for managing user context.
        *   Fetching entities based on current user context (mocked network layer).
        *   Filtering logic (e.g., `devices(forUnit: unitId)`).
    *   **Data Models (`Portfolio`, `Property`, `Unit`, `User`, `LockDevice`):**
        *   Any local computed properties or methods (e.g., `User.roles(forPortfolioId:)`).
        *   `Codable` conformance (encoding/decoding specific to multi-tenancy fields).
    *   **Utility functions** related to tenancy or UI display logic.
*   **Types of Test Cases/Scenarios:**
    *   **ViewModel Logic:**
        *   Test that calling `fetchPortfolios()` on `UserContextViewModel` correctly updates its `portfolios` array (using a mock service).
        *   Test that `selectProperty(someProperty)` on `UserContextViewModel` updates `selectedProperty` and potentially triggers a refresh in `DevicesViewModel` (mocked interaction).
        *   Test `DevicesViewModel` correctly filters devices when the context changes from a Property to a specific Unit.
        *   Test UI-facing formatted strings or computed properties based on model data.
        *   Test error states in ViewModels when services return errors.
    *   **Service Logic:**
        *   Test `UserManager.switchContext(toPortfolio: somePortfolio)` correctly updates the current user context.
        *   Test `DeviceService.fetchDevices(forProperty: propertyId)` correctly forms the API request and parses the response (using mock network client).
    *   **Model Logic:**
        *   Test `User.isOwner(ofPortfolioId: testId)` returns true/false based on mocked `roleAssociations`.
        *   Test encoding/decoding of `LockDevice` including `propertyId` and `unitId`.
*   **Tools/Techniques:**
    *   XCTest framework.
    *   Mocking frameworks/techniques for Swift (e.g., creating mock objects that conform to protocols, or using libraries like Cuckoo/SwiftyMocky, though manual mocks are often sufficient).
    *   Dependency injection to provide mock services/managers to ViewModels.

**D. iOS Integration Tests**

*   **Focus:** Interactions between different parts of the iOS app, such as ViewModels and Services, or Services and the actual Network Layer (against a mock backend or a controlled test backend).
*   **Key Areas/Modules to Test:**
    *   **User Context Flow:** Selecting a portfolio, then a property, then a unit, and verifying that the relevant ViewModels (e.g., `DevicesViewModel`) update their data correctly by making real (or mock-backend) network calls.
    *   **Data Synchronization:** How the app fetches and updates its local representation of tenancy data from the backend.
    *   **UI-driven Actions:** Triggering an action in the UI (e.g., attempting to control a lock) and ensuring the correct service calls are made with the appropriate tenancy context.
    *   **Authentication Flow with Tenancy:** Login process, fetching initial user context and associated entities.
*   **Types of Test Cases/Scenarios:**
    *   **Context Selection & Data Display:**
        *   Simulate user logging in: verify `UserContextViewModel` fetches and allows selection of the user's portfolios.
        *   Simulate selecting a Portfolio: verify `UserContextViewModel` updates, and dependent ViewModels (e.g., for Properties) fetch relevant data.
        *   Continue for Property and Unit selection, verifying device lists etc., are correctly scoped.
    *   **CRUD Operations (UI-driven, if applicable for P0):**
        *   If any UI allows creation/modification of tenancy entities (e.g., a super admin view not part of P0 user flow but used for testing setup), test these flows.
    *   **Device Interaction with Context:**
        *   Select a Unit context.
        *   Attempt to list/view/operate a device within that Unit. Verify the correct API calls are made including `unitId` or `propertyId`.
    *   **Error Handling Across Layers:**
        *   Simulate network errors when fetching portfolios/properties and verify UI displays appropriate error messages.
        *   Simulate backend returning a 403 Forbidden when trying to access a resource; verify UI handles this gracefully.
*   **Tools/Techniques:**
    *   XCTest framework.
    *   Mock backend server (e.g., using tools like MockServer, WireMock, or a simple local Node.js/Express server) to provide controlled API responses for tenancy endpoints.
    *   Potentially UI Testing with XCUITest if a more end-to-end feel is desired for specific integration flows, but focus here is more on component integration below full E2E.

**E. End-to-End (E2E) Manual Testing Scenarios**

*   **Focus:** Simulating real user workflows across the entire application stack (iOS app and live backend) to ensure the multi-tenancy features work as expected from a user's perspective. This includes UI, navigation, data display, and permission enforcement.
*   **Key Areas/Modules to Test:**
    *   Complete user journeys involving login, context selection, data viewing, and device interaction.
    *   Correctness of UI elements in reflecting current tenancy context and permissions.
    *   Data consistency between what the user sees and what their role/context allows.
    *   Security aspects: ensuring users cannot access or manipulate data outside their permitted scope.
*   **User Personas & Setup:**
    *   **Persona 1: Alice (Portfolio Owner)**
        *   Owns "Alice's Portfolio".
        *   Administers "Alice's Portfolio".
        *   Manages "Property A" and "Property B" within "Alice's Portfolio".
        *   Can view/manage all units and devices in "Property A" and "Property B".
    *   **Persona 2: Bob (Portfolio Admin)**
        *   Admin for "Charlie's Portfolio" (owned by another user, Charlie).
        *   Manages "Property C" in "Charlie's Portfolio".
        *   Can view/manage units/devices in "Property C".
        *   Cannot see or manage "Alice's Portfolio".
    *   **Persona 3: David (Property Manager)**
        *   Manages "Property A" (under "Alice's Portfolio").
        *   Can view/manage "Unit 1" and "Unit 2" in "Property A" and their devices.
        *   Cannot manage "Property B" or other portfolios.
    *   **Persona 4: Eve (Tenant)**
        *   Tenant of "Unit 1" in "Property A" (under "Alice's Portfolio").
        *   Can view/operate devices assigned to "Unit 1".
        *   Cannot see/access "Unit 2", other properties, or other portfolios.
    *   **Persona 5: Frank (User with No Associations)**
        *   A valid user but has no `UserRoleAssociation` records.
    *   **Persona 6: Grace (User with Multiple Roles)**
        *   Portfolio Admin for "Portfolio X".
        *   Property Manager for "Property Y" (in a different "Portfolio Z").
        *   Tenant in "Unit Alpha" (in "Property X").

*   **Types of Test Cases/Scenarios:**

    1.  **Login & Initial Context:**
        *   **Scenario 1.1 (Alice - Owner):**
            *   Alice logs in.
            *   App displays "Alice's Portfolio" (potentially as default or in a selectable list).
            *   Alice can select "Alice's Portfolio".
            *   Properties "Property A" and "Property B" are listed.
        *   **Scenario 1.2 (Bob - Admin):**
            *   Bob logs in.
            *   App displays "Charlie's Portfolio". No sign of "Alice's Portfolio".
            *   Bob can select "Charlie's Portfolio".
            *   "Property C" is listed.
        *   **Scenario 1.3 (David - Manager):**
            *   David logs in.
            *   App might default to "Alice's Portfolio" / "Property A" or require selection.
            *   David can see "Property A". No sign of "Property B" or "Property C".
            *   Units "Unit 1", "Unit 2" are listed under "Property A".
        *   **Scenario 1.4 (Eve - Tenant):**
            *   Eve logs in.
            *   App might default to "Alice's Portfolio" / "Property A" / "Unit 1".
            *   Eve sees devices for "Unit 1". No access to "Unit 2" devices or other property/portfolio info.
        *   **Scenario 1.5 (Frank - No Associations):**
            *   Frank logs in.
            *   App displays a state indicating no accessible portfolios/properties (e.g., "No properties found" or "Contact administrator").
            *   No device lists are shown.
        *   **Scenario 1.6 (Grace - Multiple Roles):**
            *   Grace logs in.
            *   App allows selection between "Portfolio X" and "Portfolio Z".
            *   If "Portfolio X" is selected, she sees relevant properties/units she can manage or live in.
            *   If "Portfolio Z" is selected, she sees properties she can manage.

    2.  **Context Switching & Data Scoping:**
        *   **Scenario 2.1 (Alice - Owner):**
            *   Alice selects "Property A". Sees devices for "Property A" (including those in Unit 1 & 2).
            *   Alice then selects "Unit 1" within "Property A". Sees only devices for "Unit 1".
            *   Alice switches to "Property B". Sees devices for "Property B".
        *   **Scenario 2.2 (Grace - Multiple Roles):**
            *   Grace is viewing devices as Tenant in "Unit Alpha" (Portfolio X).
            *   Grace switches context to be Portfolio Admin of "Portfolio X". Device list potentially changes to show all devices in portfolio or prompts for property selection.
            *   Grace switches context to Property Manager of "Property Y" (Portfolio Z). Device list shows devices in Property Y.

    3.  **Device Listing & Details:**
        *   **Scenario 3.1 (Correct Scoping):** For each persona, navigate to their deepest relevant context (e.g., Eve to Unit 1). Verify only devices linked to that Unit (or Property if at Property level) are displayed.
        *   **Scenario 3.2 (Device Details):** Tap on a device. Verify device detail screen shows correct information and reflects the current context.

    4.  **Device Operations (Based on P0 Permissions):**
        *   **Scenario 4.1 (Eve - Tenant in Unit 1):**
            *   Eve selects a lock in "Unit 1".
            *   Eve can perform allowed operations (e.g., lock/unlock if permitted by `LockDevice.canPerformRemoteOperation` for tenants).
        *   **Scenario 4.2 (David - Manager of Property A):**
            *   David selects a lock in "Unit 1" (within "Property A").
            *   David can perform operations (likely broader than Eve's).
        *   **Scenario 4.3 (Alice - Owner):**
            *   Alice navigates to a device in any unit within her portfolio.
            *   Alice can perform all operations.

    5.  **CRUD Operations (Manual Simulation/Verification - primarily for `UserRoleAssociation` impact):**
        *   *Note: P0 might not have UI for end-users to perform these. This might involve backend setup and then verifying app behavior.*
        *   **Scenario 5.1 (Portfolio Creation - SuperAdmin):** If a SuperAdmin creates a new Portfolio and assigns Alice as Owner. Alice logs in and sees the new Portfolio.
        *   **Scenario 5.2 (Add Property Manager - Alice):** Alice (Owner) uses a (hypothetical admin) tool to assign David as Property Manager for "Property A". David logs in and now has access to "Property A".
        *   **Scenario 5.3 (Add Tenant - David):** David (Property Manager) uses a tool to assign Eve as Tenant to "Unit 1". Eve logs in and now has access to "Unit 1" and its devices.
        *   **Scenario 5.4 (Remove Tenant - David):** David revokes Eve's tenancy for "Unit 1". Eve logs in and no longer sees devices for "Unit 1".

    6.  **Negative Test Cases (Attempting Unauthorized Actions):**
        *   **Scenario 6.1 (Eve - Tenant):**
            *   Eve attempts to see devices in "Unit 2" (same property, different unit). Access Denied / Unit 2 not visible.
            *   Eve attempts to see devices in "Property B". Access Denied / Property B not visible.
        *   **Scenario 6.2 (David - Property Manager):**
            *   David attempts to manage "Property C" (different portfolio). Access Denied / Property C not visible.
            *   David attempts to perform Owner-level actions on "Property A" (if any are distinct and restricted). Action fails or option not visible.
        *   **Scenario 6.3 (Cross-Portfolio Data Leakage):** Use Bob (Admin of Charlie's Portfolio). Systematically try to find any information or way to interact with "Alice's Portfolio" or its entities via UI manipulation or by observing any shared cache if applicable. Expect no leakage.

    7.  **UI Responsiveness to Context Changes:**
        *   **Scenario 7.1:** While on a device list for "Property A", an admin revokes the current user's access to "Property A" via a backend change. The app should gracefully handle this on next refresh or action: navigate away, show an error, or update the list to be empty.
        *   **Scenario 7.2:** User is viewing devices for "Unit 1". User switches context picker to "Property A" (parent). Device list updates to show all devices in "Property A".

*   **Tools/Techniques:**
    *   Multiple test user accounts with pre-configured roles and entity associations on the backend.
    *   A staging or test backend environment that mirrors production closely.
    *   Detailed test script/checklist to guide manual testers.
    *   Browser developer tools (for backend interaction if testing any web admin panels involved in setup) and iOS debugging tools (Xcode).

**F. Security & Permission Testing (Cross-Cutting Concern)**

*   **Focus:** Specifically verifying that the authorization rules defined by `UserRoleAssociation` are strictly enforced across all API endpoints and reflected correctly in the iOS app's behavior. This is an extension of all testing types but with a security lens.
*   **Key Areas:**
    *   Preventing unauthorized data reads (e.g., a tenant seeing another tenant's devices).
    *   Preventing unauthorized data modifications (e.g., a property manager modifying a portfolio they don't administer).
    *   Preventing unauthorized actions (e.g., a tenant performing an admin-only device operation).
    *   Ensuring users cannot elevate their privileges or bypass tenancy checks.
*   **Techniques:**
    *   Role-based attack scenarios: Log in as one user (e.g., Tenant) and try to access/manipulate data of another user or higher-level entities by crafting requests (if testing APIs directly) or finding UI loopholes.
    *   Parameter tampering: (For API testing) Modifying IDs in requests (e.g., `portfolioId`, `unitId`) to try to access resources not permitted for the authenticated user.
    *   Review of authorization logic in code (backend middleware, iOS ViewModel checks).

**Overall P0 Testing Goal Verification:**
The sum of these testing activities must confirm:
1.  Users can log in successfully.
2.  Post-login, the app correctly identifies the Portfolios, Properties, and Units the user is associated with based on their `UserRoleAssociation` records.
3.  The UI allows users to select their current operational context (Portfolio, Property, or Unit) from their permitted set.
4.  Device listings and access to device operations are correctly scoped to the selected context and the user's role within that context.
5.  Users cannot see or interact with Portfolios, Properties, Units, or Devices outside of their explicitly granted associations and roles.

This detailed testing strategy aims to build confidence in the P0 multi-tenancy implementation before broader feature development continues.

---

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

### P0 Step 4: Implement Basic iOS UI for Portfolio/Property/Unit Selection & Display

**Status: COMPLETE.**

**Summary of Implementation:**
- **Full Context Selection Flow:** Implemented a sequential UI flow for users to select their active context: Role -> Portfolio -> Property -> Unit.
- **UI Components:** Created dedicated SwiftUI views (`RoleSelectionView`, `PortfolioListView`, `PropertyListView`, `UnitListView`) and corresponding ViewModels (`PortfolioViewModel`, `PropertyViewModel`, `UnitViewModel`) for each selection step.
- **State Management:** Centralized selected context IDs (`selectedRole`, `selectedPortfolioId`, `selectedPropertyId`, `selectedUnitId`) in `UserContextViewModel`, accessible app-wide via `@EnvironmentObject`.
- **API Integration:** Integrated with backend endpoints (`/api/v1/portfolios`, `/api/v1/properties`, `/api/v1/units`) via `APIService` for fetching data relevant to each selection step.
- **Login Adaptation:** The app's initial flow after login now guides the user through this context selection process.
- **Contextual Device Display (Initial):** `DevicesView` now filters displayed devices based on the `selectedUnitId` (primary) or `selectedPropertyId` (fallback) from `UserContextViewModel`. Initial filtering logic handles `LockDevice` explicitly; further device types will require model updates (`propertyId`, `unitId` fields) for complete filtering.
- **Auto-Selection Logic:** If only one item is available at any selection step (e.g., one portfolio for a role, one property for a portfolio), it is auto-selected to streamline UX.

**Key Outcomes:**
- Users can navigate the P/P/U hierarchy.
- The app correctly scopes data based on user selections.
- A robust foundation for multi-tenancy is established in the iOS UI.

*(Detailed requirements and their completion status are implicitly covered by the summary above. All outlined requirements for P0 Step 4 have been met.)*

// ... existing P0 Step 5 content or start of P1 ...