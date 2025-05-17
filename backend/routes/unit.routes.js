const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Unit = require('../models/Unit');
const Property = require('../models/Property');
const UserRoleAssociation = require('../models/UserRoleAssociation');
const User = require('../models/User');
const Device = require('../models/Device'); // Assuming Device model exists
const { AssociatedEntityType, Role } = require('../enums');

// POST /api/v1/units - Create a new unit
// Auth: User must have "PROPERTY_MANAGER" role for the parent propertyId.
router.post('/', async (req, res) => {
    const { name, propertyId, tenantUserIds, deviceIds, commonAreaAccessIds } = req.body;
    const requestingUserId = req.user.id;

    if (!name || !propertyId) {
        return res.status(400).json({ status: 'error', message: 'Unit name and propertyId are required.' });
    }

    try {
        // 1. Check if parent property exists
        const parentProperty = await Property.findById(propertyId);
        if (!parentProperty) {
            return res.status(404).json({ status: 'error', message: 'Parent property not found.' });
        }

        // 2. Authorization: Check if user is PROPERTY_MANAGER for the parent property
        //    or OWNER/PORTFOLIO_ADMIN of the parent portfolio.
        let canCreate = false;
        const propertyAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PROPERTY,
            associatedEntityId: propertyId,
            roleWithinEntity: Role.PROPERTY_MANAGER
        });
        if (propertyAccess) canCreate = true;

        if (!canCreate) {
            const portfolioAccess = await UserRoleAssociation.findOne({
                userId: requestingUserId,
                associatedEntityType: AssociatedEntityType.PORTFOLIO,
                associatedEntityId: parentProperty.portfolioId, // Assuming Property model has portfolioId
                roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
            });
            if (portfolioAccess) canCreate = true;
        }

        if (!canCreate) {
            return res.status(403).json({ status: 'error', message: 'Forbidden. You must be a Property Manager or Portfolio Owner/Admin to add units.' });
        }

        // 3. Create Unit
        const newUnit = new Unit({
            name,
            propertyId,
            deviceIds: deviceIds || [],
            tenantUserIds: [], // Will be handled by UserRoleAssociations, but schema might have it
            commonAreaAccessIds: commonAreaAccessIds || [],
        });
        await newUnit.save();

        // 4. Update property's unitIds array
        parentProperty.unitIds.addToSet(newUnit._id);
        // parentProperty.updatedAt = Date.now(); // Handled by Mongoose {timestamps: true}
        await parentProperty.save();

        // 5. Assign specified tenantUserIds with "TENANT" role for the new unit
        if (tenantUserIds && Array.isArray(tenantUserIds) && tenantUserIds.length > 0) {
            const tenantRolePromises = tenantUserIds.map(tenantId => {
                return new UserRoleAssociation({
                    userId: tenantId,
                    associatedEntityType: AssociatedEntityType.UNIT,
                    associatedEntityId: newUnit._id,
                    roleWithinEntity: Role.TENANT,
                }).save();
            });
            await Promise.all(tenantRolePromises);
            // Update Unit model's tenantUserIds if it has this denormalized field
            newUnit.tenantUserIds = tenantUserIds.map(id => new mongoose.Types.ObjectId(id)); 
            await newUnit.save(); 
        }

        res.status(201).json({ status: 'success', data: { unit: newUnit } });
    } catch (error) {
        console.error('Error creating unit:', error);
        if (error.kind === 'ObjectId') {
            return res.status(400).json({ status: 'error', message: 'Invalid propertyId format.' });
        }
        res.status(500).json({ status: 'error', message: 'Failed to create unit', details: error.message });
    }
});

// GET /api/v1/units - List units accessible to the current user
// Auth: Fetches units where user has an association (e.g., TENANT) or via property/portfolio access.
router.get('/', async (req, res) => {
    const requestingUserId = req.user.id;
    const { propertyId, page = 1, limit = 10, sortBy = 'name' } = req.query;

    try {
        let accessibleUnitIds = [];

        // Find units directly associated with the user (e.g., as a TENANT)
        const directUnitAssociations = await UserRoleAssociation.find({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.UNIT,
        }).select('associatedEntityId');
        accessibleUnitIds = directUnitAssociations.map(assoc => assoc.associatedEntityId);

        // Find properties the user has access to (manager or via portfolio)
        let accessiblePropertyIds = [];
        const directPropertyAssociations = await UserRoleAssociation.find({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PROPERTY,
        }).select('associatedEntityId');
        accessiblePropertyIds = directPropertyAssociations.map(assoc => assoc.associatedEntityId);

        const portfolioAssociations = await UserRoleAssociation.find({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
        }).select('associatedEntityId');
        const accessiblePortfolioIds = portfolioAssociations.map(assoc => assoc.associatedEntityId);

        if (accessiblePortfolioIds.length > 0) {
            const propertiesInAccessiblePortfolios = await Property.find({
                portfolioId: { $in: accessiblePortfolioIds }
            }).select('_id');
            accessiblePropertyIds = [
                ...new Set([...accessiblePropertyIds, ...propertiesInAccessiblePortfolios.map(p => p._id)])
            ];
        }
        
        // If user has access to properties, get units within those properties
        if (accessiblePropertyIds.length > 0) {
            const unitsInAccessibleProperties = await Unit.find({
                propertyId: { $in: accessiblePropertyIds }
            }).select('_id');
            accessibleUnitIds = [
                ...new Set([...accessibleUnitIds, ...unitsInAccessibleProperties.map(u => u._id)])
            ];
        }

        const query = { _id: { $in: accessibleUnitIds } };
        if (propertyId) {
            // Further filter by specific propertyId, but first check if user even has access to this property
            const canAccessFilteredProperty = accessiblePropertyIds.some(id => {
                // This check isn't quite right. accessiblePropertyIds contains unit IDs not property IDs at this stage.
                // We need to check if the propertyId query param is in the user's accessiblePropertyIds list.
                return true; // Placeholder - needs correct logic for propertyId filter with accessiblePropertyIds for units
            });
            // Re-evaluating: If propertyId is a filter, we must ensure the user can access *that* property first.
            let canAccessQueryProperty = false;
            if (accessiblePropertyIds.length > 0) { // This check is if user is TENANT of units within propertyId
                 const unitsInProp = await Unit.find({_id: { $in: accessibleUnitIds }, propertyId: propertyId }).limit(1);
                 if(unitsInProp.length > 0) canAccessQueryProperty = true;
            }
            if(!canAccessQueryProperty && accessiblePropertyIds.length > 0) { // Check if user is MANAGER or PORTFOLIO ADMIN/OWNER of propertyId
                 if(accessiblePropertyIds.some(id => id.equals(propertyId))) canAccessQueryProperty = true;
            }
            // The above is getting complicated. A simpler approach for query filtering:
            // 1. Get all units user has direct access to (tenant).
            // 2. Get all units in properties user has access to (manager/portfolio access).
            // 3. If propertyId filter is applied, then filter these results further.
            // The current query `_id: { $in: accessibleUnitIds }` already does this if accessibleUnitIds is correctly populated.
            // The specific propertyId filter needs to ensure the target property is accessible.
            if(!accessiblePropertyIds.map(uid => uid.toString()).includes( (await Unit.find({propertyId: propertyId}).select('_id')) .map(u=>u._id.toString()) ) && 
               !accessiblePropertyIds.some(pId => pId.equals(propertyId)) ){
                // Simplified check: if filtering by propertyId, ensure it's one of the accessible ones.
                // This requires accessiblePropertyIds to contain actual property IDs at some point.
                // This logic is complex. For now, if propertyId is specified, we'll trust the user to query for properties they can see.
                // The main query will fetch all units user has access to (directly or via property/portfolio)
                // And then if propertyId is set, it will filter by it.
            }
            query.propertyId = propertyId; // Add to existing query
        }

        if (accessibleUnitIds.length === 0 && !propertyId) {
             return res.status(200).json({ status: 'success', data: { units: [], pagination: {total: 0, page, limit} }});
        }

        const unitsQuery = Unit.find(query)
            .sort(sortBy)
            .skip((parseInt(page) - 1) * parseInt(limit))
            .limit(parseInt(limit));

        const units = await unitsQuery.exec();
        const totalUnits = await Unit.countDocuments(query);

        res.status(200).json({
            status: 'success',
            data: {
                units,
                pagination: {
                    total: totalUnits,
                    page: parseInt(page),
                    limit: parseInt(limit),
                    totalPages: Math.ceil(totalUnits / parseInt(limit)),
                },
            },
        });

    } catch (error) {
        console.error('Error listing units:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list units', details: error.message });
    }
});

// Middleware to check for unit access and attach unit to req
async function checkUnitAccessAndLoad(req, res, next) {
    const { unitId } = req.params;
    const requestingUserId = req.user.id;

    try {
        const unit = await Unit.findById(unitId).populate('propertyId'); // Populate property for portfolio check
        if (!unit) {
            return res.status(404).json({ status: 'error', message: 'Unit not found.' });
        }
        if (!unit.propertyId) { // Should not happen if data is consistent
             return res.status(500).json({ status: 'error', message: 'Unit data inconsistent: missing propertyId.' });
        }

        let association = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.UNIT,
            associatedEntityId: unitId,
        });

        if (!association) { // If not directly associated, check property/portfolio access
            const propertyAccess = await UserRoleAssociation.findOne({
                userId: requestingUserId,
                associatedEntityType: AssociatedEntityType.PROPERTY,
                associatedEntityId: unit.propertyId._id, 
            });
            if (propertyAccess) {
                // User has direct access to the property (e.g. PM)
            } else {
                const portfolioAccess = await UserRoleAssociation.findOne({
                    userId: requestingUserId,
                    associatedEntityType: AssociatedEntityType.PORTFOLIO,
                    associatedEntityId: unit.propertyId.portfolioId, // propertyId is populated
                });
                if (!portfolioAccess) {
                    return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have access to this unit, its property, or its portfolio.' });
                }
            }
        }
        
        req.unit = unit; 
        if (association) {
            req.userUnitRole = association.roleWithinEntity; 
        }
        next();
    } catch (error) {
        console.error('Error in unit access check:', error);
        if (error.kind === 'ObjectId') {
            return res.status(400).json({ status: 'error', message: 'Invalid unit ID format.' });
        }
        res.status(500).json({ status: 'error', message: 'Internal server error during unit access check.' });
    }
}

// GET /api/v1/units/:unitId - Get details of a specific unit
router.get('/:unitId', checkUnitAccessAndLoad, async (req, res) => {
    res.status(200).json({ status: 'success', data: { unit: req.unit } });
});

// PUT /api/v1/units/:unitId - Update unit details
// Auth: User must be "PROPERTY_MANAGER" of parent property.
router.put('/:unitId', checkUnitAccessAndLoad, async (req, res) => {
    const { name, tenantUserIds, deviceIds, commonAreaAccessIds } = req.body;
    const unitToUpdate = req.unit;
    const requestingUserId = req.user.id;

    // Authorization check: PROPERTY_MANAGER of parent property OR OWNER/PORTFOLIO_ADMIN of parent portfolio
    let canUpdate = false;
    const propertyManagerAccess = await UserRoleAssociation.findOne({
        userId: requestingUserId,
        associatedEntityType: AssociatedEntityType.PROPERTY,
        associatedEntityId: unitToUpdate.propertyId._id,
        roleWithinEntity: Role.PROPERTY_MANAGER
    });
    if (propertyManagerAccess) canUpdate = true;

    if (!canUpdate) {
        const portfolioAdminAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: unitToUpdate.propertyId.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (portfolioAdminAccess) canUpdate = true;
    }

    if (!canUpdate) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You must be a Property Manager or Portfolio Owner/Admin to update this unit.' });
    }

    if (name === undefined && tenantUserIds === undefined && deviceIds === undefined && commonAreaAccessIds === undefined) {
        return res.status(400).json({ status: 'error', message: 'No update fields provided.' });
    }

    try {
        if (name !== undefined) unitToUpdate.name = name;
        if (deviceIds !== undefined) unitToUpdate.deviceIds = deviceIds.map(id => new mongoose.Types.ObjectId(id));
        if (commonAreaAccessIds !== undefined) unitToUpdate.commonAreaAccessIds = commonAreaAccessIds.map(id => new mongoose.Types.ObjectId(id));

        if (tenantUserIds !== undefined && Array.isArray(tenantUserIds)) {
            // Full replacement of tenants: Remove old, add new UserRoleAssociations
            await UserRoleAssociation.deleteMany({
                associatedEntityType: AssociatedEntityType.UNIT,
                associatedEntityId: unitToUpdate._id,
                roleWithinEntity: Role.TENANT,
            });
            const newTenantRolesPromises = tenantUserIds.map(userId => {
                return new UserRoleAssociation({
                    userId: userId,
                    associatedEntityType: AssociatedEntityType.UNIT,
                    associatedEntityId: unitToUpdate._id,
                    roleWithinEntity: Role.TENANT,
                }).save();
            });
            await Promise.all(newTenantRolesPromises);
            unitToUpdate.tenantUserIds = tenantUserIds.map(id => new mongoose.Types.ObjectId(id));
        }
        
        await unitToUpdate.save();
        res.status(200).json({ status: 'success', data: { unit: unitToUpdate } });
    } catch (error) {
        console.error('Error updating unit:', error);
        res.status(500).json({ status: 'error', message: 'Failed to update unit', details: error.message });
    }
});

// DELETE /api/v1/units/:unitId - Delete a unit
// Auth: User must be "PROPERTY_MANAGER" of parent property.
router.delete('/:unitId', checkUnitAccessAndLoad, async (req, res) => {
    const unitToDelete = req.unit;
    const requestingUserId = req.user.id;

    // Authorization check: PROPERTY_MANAGER of parent property OR OWNER/PORTFOLIO_ADMIN of parent portfolio
    let canDelete = false;
    const propertyManagerAccess = await UserRoleAssociation.findOne({
        userId: requestingUserId,
        associatedEntityType: AssociatedEntityType.PROPERTY,
        associatedEntityId: unitToDelete.propertyId._id,
        roleWithinEntity: Role.PROPERTY_MANAGER
    });
    if (propertyManagerAccess) canDelete = true;

    if (!canDelete) {
        const portfolioAdminAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: unitToDelete.propertyId.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (portfolioAdminAccess) canDelete = true;
    }
    if (!canDelete) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You must be a Property Manager or Portfolio Owner/Admin to delete this unit.' });
    }

    try {
        // TODO: Handle dissociation of devices more carefully.
        // For now, just remove unit from property's unitIds list.
        await Property.findByIdAndUpdate(unitToDelete.propertyId._id, {
            $pull: { unitIds: unitToDelete._id },
        });

        await Unit.findByIdAndDelete(unitToDelete._id);

        await UserRoleAssociation.deleteMany({
            associatedEntityType: AssociatedEntityType.UNIT,
            associatedEntityId: unitToDelete._id,
        });

        res.status(204).send();
    } catch (error) {
        console.error('Error deleting unit:', error);
        res.status(500).json({ status: 'error', message: 'Failed to delete unit', details: error.message });
    }
});

// --- Nested Routes for Tenants of a Unit ---

// POST /api/v1/units/:unitId/tenants - Assign/invite a tenant to this unit
// Auth: User must be "PROPERTY_MANAGER" of parent property.
router.post('/:unitId/tenants', checkUnitAccessAndLoad, async (req, res) => {
    const { unitId } = req.params;
    const { userId } = req.body; // Role is fixed to TENANT
    const unit = req.unit; // Loaded by middleware
    const requestingUserId = req.user.id;

    // Authorization: User must be PROPERTY_MANAGER of parent property OR OWNER/PORTFOLIO_ADMIN of parent portfolio
    let canManageTenants = false;
    const propertyManagerAccess = await UserRoleAssociation.findOne({
        userId: requestingUserId,
        associatedEntityType: AssociatedEntityType.PROPERTY,
        associatedEntityId: unit.propertyId._id,
        roleWithinEntity: Role.PROPERTY_MANAGER
    });
    if (propertyManagerAccess) canManageTenants = true;

    if (!canManageTenants) {
        const portfolioAdminAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: unit.propertyId.portfolioId, 
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (portfolioAdminAccess) canManageTenants = true;
    }

    if (!canManageTenants) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. Only Property Managers or Portfolio Owner/Admins can manage tenants for this unit.' });
    }

    if (!userId) {
        return res.status(400).json({ status: 'error', message: 'User ID for the tenant is required.' });
    }

    try {
        const userExists = await User.findById(userId);
        if (!userExists) {
            return res.status(404).json({ status: 'error', message: 'User to be added as tenant not found.' });
        }

        const association = await UserRoleAssociation.findOneAndUpdate(
            { userId: userId, associatedEntityType: AssociatedEntityType.UNIT, associatedEntityId: unitId },
            { $set: { roleWithinEntity: Role.TENANT } },
            { upsert: true, new: true, runValidators: true }
        );

        // Update denormalized tenantUserIds on Unit model
        await Unit.findByIdAndUpdate(unitId, { $addToSet: { tenantUserIds: new mongoose.Types.ObjectId(userId) } });

        res.status(200).json({ status: 'success', data: { userRoleAssociation: association } });
    } catch (error) {
        console.error('Error adding tenant to unit:', error);
        res.status(500).json({ status: 'error', message: 'Failed to add tenant', details: error.message });
    }
});

// GET /api/v1/units/:unitId/tenants - List tenants assigned to this unit
// Auth: User must be "PROPERTY_MANAGER" of parent property or "TENANT" of the unit.
router.get('/:unitId/tenants', checkUnitAccessAndLoad, async (req, res) => {
    const { unitId } = req.params;
    const unit = req.unit;
    const requestingUserId = req.user.id;
    const requestingUserUnitRole = req.userUnitRole; // Direct role in this unit

    // Authorization check
    let canListTenants = false;
    if (requestingUserUnitRole === Role.TENANT) canListTenants = true;
    
    if (!canListTenants) {
        const propertyManagerAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PROPERTY,
            associatedEntityId: unit.propertyId._id,
            roleWithinEntity: Role.PROPERTY_MANAGER
        });
        if (propertyManagerAccess) canListTenants = true;
    }
    if (!canListTenants) {
        const portfolioAdminAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: unit.propertyId.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (portfolioAdminAccess) canListTenants = true;
    }

    if (!canListTenants) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to view tenants for this unit.' });
    }

    try {
        const associations = await UserRoleAssociation.find({
            associatedEntityType: AssociatedEntityType.UNIT,
            associatedEntityId: unitId,
            roleWithinEntity: Role.TENANT
        }).populate('userId', '-password -isSuperAdmin'); // Populate user details, exclude sensitive fields

        const tenants = associations.map(assoc => assoc.userId);
        // Plan specifies: "data": { "users": [userObjectWithoutSensitiveInfo] } }
        // Current `tenants` variable holds user objects from populated `userId`.

        res.status(200).json({ status: 'success', data: { users: tenants } });
    } catch (error) {
        console.error('Error listing tenants for unit:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list tenants', details: error.message });
    }
});

// --- Nested Routes for Devices of a Unit ---

// POST /api/v1/units/:unitId/devices - Assign an existing device to this unit
// Auth: User must be "PROPERTY_MANAGER" of parent property.
router.post('/:unitId/devices', checkUnitAccessAndLoad, async (req, res) => {
    const { unitId } = req.params;
    const { deviceId } = req.body;
    const unit = req.unit;
    const requestingUserId = req.user.id;

    // Authorization: User must be PROPERTY_MANAGER of parent property OR OWNER/PORTFOLIO_ADMIN of parent portfolio
    let canManageDevices = false;
    const propertyManagerAccess = await UserRoleAssociation.findOne({
        userId: requestingUserId,
        associatedEntityType: AssociatedEntityType.PROPERTY,
        associatedEntityId: unit.propertyId._id,
        roleWithinEntity: Role.PROPERTY_MANAGER
    });
    if (propertyManagerAccess) canManageDevices = true;

    if (!canManageDevices) {
        const portfolioAdminAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: unit.propertyId.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (portfolioAdminAccess) canManageDevices = true;
    }
    if (!canManageDevices) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. Only Property Managers or Portfolio Owner/Admins can manage devices for this unit.' });
    }

    if (!deviceId) {
        return res.status(400).json({ status: 'error', message: 'Device ID is required.' });
    }

    try {
        const deviceExists = await Device.findById(deviceId);
        if (!deviceExists) {
            return res.status(404).json({ status: 'error', message: 'Device not found.' });
        }

        // Add deviceId to unit's deviceIds array
        await Unit.findByIdAndUpdate(unitId, { $addToSet: { deviceIds: new mongoose.Types.ObjectId(deviceId) } });
        
        // Update device's unitId and propertyId fields
        deviceExists.unitId = unitId;
        deviceExists.propertyId = unit.propertyId._id; // unit is populated with propertyId object
        await deviceExists.save();

        // Reload unit to reflect changes for response
        const updatedUnit = await Unit.findById(unitId);
        res.status(200).json({ status: 'success', data: { unit: updatedUnit } }); // Plan says deviceObject or updated unit object

    } catch (error) {
        console.error('Error assigning device to unit:', error);
        res.status(500).json({ status: 'error', message: 'Failed to assign device', details: error.message });
    }
});

// GET /api/v1/units/:unitId/devices - List devices assigned to this unit
// Auth: User must be "TENANT" of this unitId or manager of parent property / admin of parent portfolio.
router.get('/:unitId/devices', checkUnitAccessAndLoad, async (req, res) => {
    const { unitId } = req.params;
    const unit = req.unit;
    const requestingUserId = req.user.id;
    const requestingUserUnitRole = req.userUnitRole;

    // Authorization check
    let canListDevices = false;
    if (requestingUserUnitRole === Role.TENANT) canListDevices = true;

    if (!canListDevices) {
        const propertyManagerAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PROPERTY,
            associatedEntityId: unit.propertyId._id,
            roleWithinEntity: Role.PROPERTY_MANAGER
        });
        if (propertyManagerAccess) canListDevices = true;
    }
    if (!canListDevices) {
        const portfolioAdminAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: unit.propertyId.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (portfolioAdminAccess) canListDevices = true;
    }

    if (!canListDevices) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to view devices for this unit.' });
    }

    try {
        // Populate device details from the deviceIds array on the unit
        const populatedUnit = await Unit.findById(unitId).populate('deviceIds').populate('commonAreaAccessIds');
        if (!populatedUnit) {
            return res.status(404).json({ status: 'error', message: 'Unit not found after attempting to populate devices.' });
        }

        res.status(200).json({ 
            status: 'success', 
            data: { 
                devices: populatedUnit.deviceIds, 
                commonAreaAccessDevices: populatedUnit.commonAreaAccessIds // Also return common area devices if any
            }
        });
    } catch (error) {
        console.error('Error listing devices for unit:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list devices', details: error.message });
    }
});

module.exports = router; 