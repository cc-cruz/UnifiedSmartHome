const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Property = require('../models/Property');
const Portfolio = require('../models/Portfolio');
const UserRoleAssociation = require('../models/UserRoleAssociation');
const Unit = require('../models/Unit');
const User = require('../models/User');
const { AssociatedEntityType, Role } = require('../enums');

// POST /api/v1/properties - Create a new property
// Auth: User must have "OWNER" or "PORTFOLIO_ADMIN" role for the parent portfolioId.
router.post('/', async (req, res) => {
    const { name, portfolioId, address, managerUserIds } = req.body;
    const requestingUserId = req.user.id; // From JWT, ensured by global protect middleware

    if (!name || !portfolioId) {
        return res.status(400).json({ status: 'error', message: 'Property name and portfolioId are required.' });
    }

    try {
        // 1. Check if portfolio exists
        const parentPortfolio = await Portfolio.findById(portfolioId);
        if (!parentPortfolio) {
            return res.status(404).json({ status: 'error', message: 'Parent portfolio not found.' });
        }

        // 2. Authorization: Check if user is OWNER or PORTFOLIO_ADMIN of the parent portfolio
        const portfolioAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });

        if (!portfolioAccess) {
            return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to add properties to this portfolio.' });
        }

        // 3. Create Property
        const newProperty = new Property({
            name,
            portfolioId,
            address, // Assuming address structure matches Property model
            // managerUserIds will be handled by creating UserRoleAssociations below
        });
        await newProperty.save();

        // 4. Update portfolio's propertyIds array
        parentPortfolio.propertyIds.addToSet(newProperty._id);
        parentPortfolio.updatedAt = Date.now();
        await parentPortfolio.save();

        // 5. Assign specified managerUserIds with "PROPERTY_MANAGER" role for the new property
        if (managerUserIds && Array.isArray(managerUserIds) && managerUserIds.length > 0) {
            const managerRolePromises = managerUserIds.map(managerId => {
                return new UserRoleAssociation({
                    userId: managerId,
                    associatedEntityType: AssociatedEntityType.PROPERTY,
                    associatedEntityId: newProperty._id,
                    roleWithinEntity: Role.PROPERTY_MANAGER,
                }).save();
            });
            await Promise.all(managerRolePromises);
            // Optionally, update Property model's managerUserIds if it has such a denormalized field
            // newProperty.managerUserIds = managerUserIds.map(id => new mongoose.Types.ObjectId(id));
            // await newProperty.save();
        }

        res.status(201).json({ status: 'success', data: { property: newProperty } });
    } catch (error) {
        console.error('Error creating property:', error);
        if (error.kind === 'ObjectId') {
            return res.status(400).json({ status: 'error', message: 'Invalid portfolioId format.' });
        }
        res.status(500).json({ status: 'error', message: 'Failed to create property', details: error.message });
    }
});

// GET /api/v1/properties - List properties accessible to the current user
// Auth: Fetches properties where user has an association (e.g., PROPERTY_MANAGER) or via portfolio access.
router.get('/', async (req, res) => {
    const requestingUserId = req.user.id;
    const { portfolioId, page = 1, limit = 10, sortBy = 'name' } = req.query;

    try {
        let accessiblePropertyIds = [];

        // Find properties directly managed by the user
        const directPropertyAssociations = await UserRoleAssociation.find({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PROPERTY,
        }).select('associatedEntityId');
        accessiblePropertyIds = directPropertyAssociations.map(assoc => assoc.associatedEntityId);

        // Find portfolios accessible to the user
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
        
        // Construct query based on filters and accessible IDs
        const query = { _id: { $in: accessiblePropertyIds } };
        if (portfolioId) {
             // Further filter by a specific portfolioId if the user has access to it
            if (!accessiblePortfolioIds.some(id => id.equals(portfolioId))) {
                return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have access to the specified portfolio.' });
            }
            query.portfolioId = portfolioId;
        }

        if (accessiblePropertyIds.length === 0 && !portfolioId) { // if no accessible properties and no specific portfolio filter that might yield results
            return res.status(200).json({ status: 'success', data: { properties: [], pagination: {total: 0, page, limit} }});
        }

        const propertiesQuery = Property.find(query)
            .sort(sortBy)
            .skip((parseInt(page) - 1) * parseInt(limit))
            .limit(parseInt(limit));

        const properties = await propertiesQuery.exec();
        const totalProperties = await Property.countDocuments(query);

        res.status(200).json({
            status: 'success',
            data: {
                properties,
                pagination: {
                    total: totalProperties,
                    page: parseInt(page),
                    limit: parseInt(limit),
                    totalPages: Math.ceil(totalProperties / parseInt(limit)),
                },
            },
        });

    } catch (error) {
        console.error('Error listing properties:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list properties', details: error.message });
    }
});

// Middleware to check for property access and attach property to req
async function checkPropertyAccessAndLoad(req, res, next) {
    const { propertyId } = req.params;
    const requestingUserId = req.user.id;

    try {
        const property = await Property.findById(propertyId);
        if (!property) {
            return res.status(404).json({ status: 'error', message: 'Property not found.' });
        }

        // Option 1: Direct association with the property
        let association = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PROPERTY,
            associatedEntityId: propertyId,
        });

        // Option 2: Access via parent portfolio
        if (!association) {
            const parentPortfolioAssociation = await UserRoleAssociation.findOne({
                userId: requestingUserId,
                associatedEntityType: AssociatedEntityType.PORTFOLIO,
                associatedEntityId: property.portfolioId,
                // Any role in portfolio grants visibility to its properties for GET
            });
            if (parentPortfolioAssociation) {
                // User has access to the portfolio, so they can view the property.
                // We don't set req.userPropertyRole here as it's indirect access for GET.
            } else {
                 return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have access to this property or its portfolio.' });
            }
        }
        
        req.property = property; // Attach property to request object
        if (association) {
             req.userPropertyRole = association.roleWithinEntity; // Attach user's direct role in this property
        }
        // If access is only via portfolio, req.userPropertyRole will be undefined.
        // Specific endpoints will need to check this and req.userDbRecord (e.g. for portfolio owner rights)

        next();
    } catch (error) {
        console.error('Error in property access check:', error);
        if (error.kind === 'ObjectId') {
            return res.status(400).json({ status: 'error', message: 'Invalid property ID format.' });
        }
        res.status(500).json({ status: 'error', message: 'Internal server error during property access check.' });
    }
}

// GET /api/v1/properties/:propertyId - Get details of a specific property
router.get('/:propertyId', checkPropertyAccessAndLoad, async (req, res) => {
    // The checkPropertyAccessAndLoad middleware already verifies access and loads the property.
    res.status(200).json({ status: 'success', data: { property: req.property } });
});

// PUT /api/v1/properties/:propertyId - Update property details
// Auth: User must have "PROPERTY_MANAGER" role for this propertyId or admin/owner of parent portfolio.
router.put('/:propertyId', checkPropertyAccessAndLoad, async (req, res) => {
    const { name, address, managerUserIds } = req.body;
    const propertyToUpdate = req.property; // Loaded by middleware
    const requestingUserId = req.user.id;

    // Authorization check
    let canUpdate = false;
    if (req.userPropertyRole === Role.PROPERTY_MANAGER) {
        canUpdate = true;
    }
    if (!canUpdate) {
        const parentPortfolioAccess = await UserRoleAssociation.findOne({
            userId: requestingUserId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: propertyToUpdate.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (parentPortfolioAccess) {
            canUpdate = true;
        }
    }

    if (!canUpdate) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to update this property.' });
    }

    if (name === undefined && address === undefined && managerUserIds === undefined) {
        return res.status(400).json({ status: 'error', message: 'No update fields provided.' });
    }

    try {
        if (name !== undefined) propertyToUpdate.name = name;
        if (address !== undefined) propertyToUpdate.address = address; // Assuming full address object replacement or partial update if schema supports
        
        // Handle managerUserIds update (full replacement logic)
        if (managerUserIds !== undefined && Array.isArray(managerUserIds)) {
            // 1. Remove existing PROPERTY_MANAGER roles for this property
            await UserRoleAssociation.deleteMany({
                associatedEntityType: AssociatedEntityType.PROPERTY,
                associatedEntityId: propertyToUpdate._id,
                roleWithinEntity: Role.PROPERTY_MANAGER,
            });

            // 2. Add new manager roles
            const newManagerRolesPromises = managerUserIds.map(userId => {
                // TODO: Validate userIds exist if necessary
                return new UserRoleAssociation({
                    userId: userId,
                    associatedEntityType: AssociatedEntityType.PROPERTY,
                    associatedEntityId: propertyToUpdate._id,
                    roleWithinEntity: Role.PROPERTY_MANAGER,
                }).save();
            });
            await Promise.all(newManagerRolesPromises);
            
            // 3. Update the Property document's managerUserIds field
            propertyToUpdate.managerUserIds = managerUserIds.map(id => new mongoose.Types.ObjectId(id));
        }
        // propertyToUpdate.updatedAt = Date.now(); // Handled by Mongoose {timestamps: true}
        await propertyToUpdate.save();
        res.status(200).json({ status: 'success', data: { property: propertyToUpdate } });
    } catch (error) {
        console.error('Error updating property:', error);
        res.status(500).json({ status: 'error', message: 'Failed to update property', details: error.message });
    }
});

// DELETE /api/v1/properties/:propertyId - Delete a property
// Auth: User must be "OWNER"/"PORTFOLIO_ADMIN" of parent portfolio.
router.delete('/:propertyId', checkPropertyAccessAndLoad, async (req, res) => {
    const propertyToDelete = req.property;
    const requestingUserId = req.user.id;

    // Authorization: User must be OWNER or PORTFOLIO_ADMIN of the parent portfolio.
    const parentPortfolioAccess = await UserRoleAssociation.findOne({
        userId: requestingUserId,
        associatedEntityType: AssociatedEntityType.PORTFOLIO,
        associatedEntityId: propertyToDelete.portfolioId,
        roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
    });

    if (!parentPortfolioAccess) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to delete this property.' });
    }

    try {
        // TODO: Handle dissociation of units, devices, user role associations more carefully.
        // For now, prevent deletion if units exist.
        const unitsInProperty = await Unit.find({ propertyId: propertyToDelete._id }).limit(1);
        if (unitsInProperty.length > 0) {
            return res.status(400).json({
                status: 'error',
                message: 'Property cannot be deleted as it contains units. Please delete units first.'
            });
        }

        // Remove propertyId from parent portfolio's propertyIds array
        await Portfolio.findByIdAndUpdate(propertyToDelete.portfolioId, {
            $pull: { propertyIds: propertyToDelete._id },
            $set: { updatedAt: Date.now() }
        });

        // Delete the property
        await Property.findByIdAndDelete(propertyToDelete._id);

        // Delete all UserRoleAssociations related to this property
        await UserRoleAssociation.deleteMany({
            associatedEntityType: AssociatedEntityType.PROPERTY,
            associatedEntityId: propertyToDelete._id,
        });

        res.status(204).send(); // No content
    } catch (error) {
        console.error('Error deleting property:', error);
        res.status(500).json({ status: 'error', message: 'Failed to delete property', details: error.message });
    }
});

// --- Nested Routes for Units within a Property ---

// POST /api/v1/properties/:propertyId/units - Create and add a new unit to this property
// Auth: User must have "PROPERTY_MANAGER" role for this propertyId.
router.post('/:propertyId/units', checkPropertyAccessAndLoad, async (req, res) => {
    const { propertyId } = req.params;
    const { name, tenantUserIds, deviceIds } = req.body; // As per plan for Unit endpoints
    const currentProperty = req.property; // Loaded by middleware

    // Authorization: User must have "PROPERTY_MANAGER" role for this propertyId.
    if (req.userPropertyRole !== Role.PROPERTY_MANAGER) {
        // Also allow Portfolio Owner/Admin to perform this action for flexibility
        const portfolioAccess = await UserRoleAssociation.findOne({
            userId: req.user.id,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: currentProperty.portfolioId,
            roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
        });
        if (!portfolioAccess) {
            return res.status(403).json({ status: 'error', message: 'Forbidden. You must be a Property Manager for this property or an admin/owner of the portfolio to add units.' });
        }
    }

    if (!name) {
        return res.status(400).json({ status: 'error', message: 'Unit name is required.' });
    }

    try {
        const newUnit = new Unit({
            name,
            propertyId,
            deviceIds: deviceIds || [], // Ensure it's an array
            // tenantUserIds will be handled by creating UserRoleAssociations below
        });
        await newUnit.save();

        // Update property's unitIds array (if Property model has it)
        // Assuming Property model has a field like: unitIds: [{ type: Schema.Types.ObjectId, ref: 'Unit' }]
        // currentProperty.unitIds.addToSet(newUnit._id);
        // await currentProperty.save();
        // Let's check Property.js schema for unitIds.
        // Based on plan: `Property` Model/Schema: `unitIds` ([UnitID], indexed).
        // So, yes, we should update it.
        await Property.findByIdAndUpdate(propertyId, {
            $addToSet: { unitIds: newUnit._id },
            $set: { updatedAt: Date.now() }
        });

        // Assign specified tenantUserIds with "TENANT" role for the new unit
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
            // Optionally, update Unit model's tenantUserIds if it has such a denormalized field
            // newUnit.tenantUserIds = tenantUserIds.map(id => new mongoose.Types.ObjectId(id));
            // await newUnit.save();
        }

        res.status(201).json({ status: 'success', data: { unit: newUnit } });
    } catch (error) {
        console.error('Error creating unit in property:', error);
        res.status(500).json({ status: 'error', message: 'Failed to create unit', details: error.message });
    }
});

// GET /api/v1/properties/:propertyId/units - List all units within this property
// Auth: User must have an association with this propertyId (or its parent portfolio).
router.get('/:propertyId/units', checkPropertyAccessAndLoad, async (req, res) => {
    const { propertyId } = req.params;
    // Access is already verified by checkPropertyAccessAndLoad middleware.

    try {
        const units = await Unit.find({ propertyId });
        res.status(200).json({ status: 'success', data: { units } });
    } catch (error) {
        console.error('Error listing units in property:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list units', details: error.message });
    }
});

// --- Nested Routes for Managers of a Property ---

// POST /api/v1/properties/:propertyId/managers - Add/invite a manager to this property
// Auth: User must be "OWNER"/"PORTFOLIO_ADMIN" of parent portfolio.
router.post('/:propertyId/managers', checkPropertyAccessAndLoad, async (req, res) => {
    const { propertyId } = req.params;
    const { userId } = req.body; // Role is fixed to PROPERTY_MANAGER as per plan
    const currentProperty = req.property; // Loaded by middleware
    const requestingUserId = req.user.id;

    // Authorization: User must be OWNER or PORTFOLIO_ADMIN of the parent portfolio.
    const parentPortfolioAccess = await UserRoleAssociation.findOne({
        userId: requestingUserId,
        associatedEntityType: AssociatedEntityType.PORTFOLIO,
        associatedEntityId: currentProperty.portfolioId,
        roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] }
    });

    if (!parentPortfolioAccess) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. Only portfolio owner/admin can manage property managers.' });
    }

    if (!userId) {
        return res.status(400).json({ status: 'error', message: 'User ID is required.' });
    }

    try {
        const userExists = await User.findById(userId);
        if (!userExists) {
            return res.status(404).json({ status: 'error', message: 'User to be added as manager not found.' });
        }

        const association = await UserRoleAssociation.findOneAndUpdate(
            {
                userId: userId,
                associatedEntityType: AssociatedEntityType.PROPERTY,
                associatedEntityId: propertyId,
            },
            { $set: { roleWithinEntity: Role.PROPERTY_MANAGER } },
            { upsert: true, new: true, runValidators: true }
        );

        // Update Property model's managerUserIds array
        await Property.findByIdAndUpdate(propertyId, 
           { 
               $addToSet: { managerUserIds: new mongoose.Types.ObjectId(userId) }, 
               // $set: { updatedAt: Date.now() } // Handled by Mongoose {timestamps: true}
           }
        );

        res.status(200).json({ status: 'success', data: { userRoleAssociation: association } });
    } catch (error) {
        console.error('Error adding property manager:', error);
        if (error.kind === 'ObjectId') {
             return res.status(400).json({ status: 'error', message: 'Invalid userId format.' });
        }
        res.status(500).json({ status: 'error', message: 'Failed to add property manager', details: error.message });
    }
});

module.exports = router; 