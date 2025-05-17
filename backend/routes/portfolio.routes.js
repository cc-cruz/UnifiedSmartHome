const express = require('express');
const router = express.Router();
const Portfolio = require('../models/Portfolio'); // Assuming Portfolio.js
const UserRoleAssociation = require('../models/UserRoleAssociation'); // Assuming UserRoleAssociation.js
const User = require('../models/User'); // Assuming User.js
const Property = require('../models/Property'); // Assuming Property.js
const { AssociatedEntityType, Role } = require('../enums'); // Assuming enums are defined and exported
const mongoose = require('mongoose'); // Assuming mongoose is imported

// Middleware to simulate JWT authentication and populate req.user
// In a real app, this would be actual JWT middleware
// const authenticateJWT = (req, res, next) => {
//     // For development, we can simulate a user or allow it to be set via headers/query
//     // For now, let's assume req.user is populated by a preceding actual auth middleware
//     // Example: req.user = { id: 'someUserId', roles: [...] };
//     if (!req.user) {
//         // Simulate a super admin for initial portfolio creation if no user is present
//         // This is a placeholder for actual role checking for initial portfolio creation
//         // As per plan: "Auth: Requires global \"SuperAdmin\" or similar high-level role"
//         // For other endpoints, req.user MUST be present and have appropriate roles.
//         console.warn("Simulating super admin for initial POST /portfolios. Ensure actual auth middleware populates req.user.");
//     }
//     next();
// };

// router.use(authenticateJWT); // Apply to all portfolio routes - REMOVED, handled by global middleware in server.js

// POST /api/v1/portfolios - Create a new portfolio
router.post('/', async (req, res) => {
    // req.user.id is from JWT (guaranteed by protect middleware)
    // req.userDbRecord is the full user model instance (guaranteed by protect middleware)
    const requestingUser = req.userDbRecord;

    // Authorization: Requires global SuperAdmin role
    // Assuming User model has `isSuperAdmin: Boolean` or `globalRole: String`
    // Adjust check as per your User schema for identifying SuperAdmin
    if (!requestingUser || !(requestingUser.isSuperAdmin === true || requestingUser.globalRole === Role.SUPER_ADMIN)) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. Only a SuperAdmin can create new portfolios.' });
    }

    const { name, administratorUserIds } = req.body;
    
    if (!name) {
        return res.status(400).json({ status: 'error', message: 'Portfolio name is required.' });
    }

    try {
        const newPortfolio = new Portfolio({ name });
        await newPortfolio.save();

        const adminRolesPromises = [];

        if (administratorUserIds && administratorUserIds.length > 0) {
            // Assign specified administrators
            administratorUserIds.forEach((adminId, index) => {
                const roleToAssign = index === 0 ? Role.OWNER : Role.PORTFOLIO_ADMIN;
                adminRolesPromises.push(
                    new UserRoleAssociation({
                        userId: adminId,
                        associatedEntityType: AssociatedEntityType.PORTFOLIO,
                        associatedEntityId: newPortfolio._id,
                        roleWithinEntity: roleToAssign,
                    }).save()
                );
            });
        } else {
            // If no admins specified, assign the requesting SuperAdmin as OWNER
            adminRolesPromises.push(
                new UserRoleAssociation({
                    userId: requestingUser._id, // or req.user.id, both are available
                    associatedEntityType: AssociatedEntityType.PORTFOLIO,
                    associatedEntityId: newPortfolio._id,
                    roleWithinEntity: Role.OWNER,
                }).save()
            );
        }

        await Promise.all(adminRolesPromises);

        res.status(201).json({ status: 'success', data: { portfolio: newPortfolio } });
    } catch (error) {
        console.error('Error creating portfolio:', error);
        res.status(500).json({ status: 'error', message: 'Failed to create portfolio', details: error.message });
    }
});

// GET /api/v1/portfolios - List portfolios accessible to the current authenticated user
router.get('/', async (req, res) => {
    // req.user.id is from JWT, req.userDbRecord also available
    const userId = req.user.id;
    const { page = 1, limit = 10, sortBy = 'name' } = req.query;

    try {
        // Find all portfolio associations for the user
        const userPortfolioAssociations = await UserRoleAssociation.find({
            userId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
        }).select('associatedEntityId');

        const portfolioIds = userPortfolioAssociations.map(assoc => assoc.associatedEntityId);

        if (portfolioIds.length === 0) {
            return res.status(200).json({ status: 'success', data: { portfolios: [], pagination: { total: 0, page, limit } } });
        }

        // Fetch portfolios based on these IDs
        const portfoliosQuery = Portfolio.find({ _id: { $in: portfolioIds } })
            .sort(sortBy)
            .skip((page - 1) * limit)
            .limit(parseInt(limit));

        const portfolios = await portfoliosQuery.exec();
        const totalPortfolios = await Portfolio.countDocuments({ _id: { $in: portfolioIds } });

        res.status(200).json({
            status: 'success',
            data: {
                portfolios,
                pagination: {
                    total: totalPortfolios,
                    page: parseInt(page),
                    limit: parseInt(limit),
                    totalPages: Math.ceil(totalPortfolios / limit),
                },
            },
        });
    } catch (error) {
        console.error('Error listing portfolios:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list portfolios', details: error.message });
    }
});

// Middleware to check for portfolio access and attach portfolio to req
async function checkPortfolioAccessAndLoad(req, res, next) {
    const { portfolioId } = req.params;
    if (!req.user || !req.user.id) {
        return res.status(401).json({ status: 'error', message: 'Authentication required.' });
    }
    const userId = req.user.id;

    try {
        const portfolio = await Portfolio.findById(portfolioId);
        if (!portfolio) {
            return res.status(404).json({ status: 'error', message: 'Portfolio not found.' });
        }

        const association = await UserRoleAssociation.findOne({
            userId,
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: portfolioId,
        });

        if (!association) {
            return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have access to this portfolio.' });
        }

        req.portfolio = portfolio; // Attach portfolio to request object
        req.userPortfolioRole = association.roleWithinEntity; // Attach user's role in this portfolio
        next();
    } catch (error) {
        console.error('Error in portfolio access check:', error);
        if (error.kind === 'ObjectId') {
            return res.status(400).json({ status: 'error', message: 'Invalid portfolio ID format.' });
        }
        res.status(500).json({ status: 'error', message: 'Internal server error during access check.' });
    }
}

// GET /api/v1/portfolios/:portfolioId - Get details of a specific portfolio
router.get('/:portfolioId', checkPortfolioAccessAndLoad, async (req, res) => {
    // The checkPortfolioAccessAndLoad middleware already verifies access and loads the portfolio.
    res.status(200).json({ status: 'success', data: { portfolio: req.portfolio } });
});

// PUT /api/v1/portfolios/:portfolioId - Update portfolio details
router.put('/:portfolioId', checkPortfolioAccessAndLoad, async (req, res) => {
    const { name, administratorUserIds } = req.body;
    const { portfolioId } = req.params;
    const portfolioToUpdate = req.portfolio; // Loaded by checkPortfolioAccessAndLoad

    // Authorization: User must have "OWNER" or "PORTFOLIO_ADMIN" role for this portfolioId.
    if (req.userPortfolioRole !== Role.OWNER && req.userPortfolioRole !== Role.PORTFOLIO_ADMIN) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to update this portfolio.' });
    }

    if (name === undefined && administratorUserIds === undefined) { // Check for undefined to allow empty array for admins
        return res.status(400).json({ status: 'error', message: 'No update fields provided (name or administratorUserIds).' });
    }

    try {
        if (name !== undefined) {
            portfolioToUpdate.name = name;
        }

        if (administratorUserIds !== undefined && Array.isArray(administratorUserIds)) {
            // Validate user IDs if necessary (e.g., check if they are valid ObjectIds)
            // This is a full replacement of administrators as per plan.
            // 1. Remove existing OWNER/PORTFOLIO_ADMIN UserRoleAssociations for this portfolio
            await UserRoleAssociation.deleteMany({
                associatedEntityType: AssociatedEntityType.PORTFOLIO,
                associatedEntityId: portfolioId,
                roleWithinEntity: { $in: [Role.OWNER, Role.PORTFOLIO_ADMIN] },
            });

            // 2. Add new administrator UserRoleAssociations
            const newAdminRolesPromises = administratorUserIds.map((userId, index) => {
                const roleToAssign = index === 0 ? Role.OWNER : Role.PORTFOLIO_ADMIN;
                return new UserRoleAssociation({
                    userId: userId,
                    associatedEntityType: AssociatedEntityType.PORTFOLIO,
                    associatedEntityId: portfolioId,
                    roleWithinEntity: roleToAssign,
                }).save();
            });
            await Promise.all(newAdminRolesPromises);
            
            // 3. Update the Portfolio document's administratorUserIds field
            portfolioToUpdate.administratorUserIds = administratorUserIds.map(id => new mongoose.Types.ObjectId(id)); // Ensure they are ObjectIds
        }

        portfolioToUpdate.updatedAt = Date.now();
        await portfolioToUpdate.save();
        res.status(200).json({ status: 'success', data: { portfolio: portfolioToUpdate } });
    } catch (error) {
        console.error('Error updating portfolio:', error);
        res.status(500).json({ status: 'error', message: 'Failed to update portfolio', details: error.message });
    }
});

// DELETE /api/v1/portfolios/:portfolioId - Delete a portfolio
router.delete('/:portfolioId', checkPortfolioAccessAndLoad, async (req, res) => {
    const { portfolioId } = req.params;

    // Authorization: User must have "OWNER" role for this portfolioId.
    if (req.userPortfolioRole !== Role.OWNER) {
        // The plan also mentions "SuperAdmin", which is not implemented yet as a generic role.
        // For now, only OWNER of the portfolio can delete.
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to delete this portfolio.' });
    }

    try {
        // TODO: Implement soft delete or add more robust deletion logic.
        // For now, a hard delete is performed.
        // Plan: "Also handle dissociation of properties, units, devices, and user role associations carefully (cascade or prevent if dependencies exist)."
        // This is a placeholder for that more complex logic.
        // For now, we'll just delete the portfolio and its direct role associations.

        // 1. Find all properties in this portfolio
        const propertiesInPortfolio = await Property.find({ portfolioId }).select('_id');
        const propertyIds = propertiesInPortfolio.map(p => p._id);

        if (propertyIds.length > 0) {
            // For now, prevent deletion if properties exist, as cascade logic is complex for this step.
            // A more robust implementation would delete or disassociate them.
            return res.status(400).json({
                status: 'error',
                message: 'Portfolio cannot be deleted as it contains properties. Please delete properties first.'
            });
        }

        // Delete the portfolio
        await Portfolio.findByIdAndDelete(portfolioId);

        // Delete all UserRoleAssociations related to this portfolio
        await UserRoleAssociation.deleteMany({
            associatedEntityType: AssociatedEntityType.PORTFOLIO,
            associatedEntityId: portfolioId,
        });

        res.status(204).send(); // No content
    } catch (error) {
        console.error('Error deleting portfolio:', error);
        res.status(500).json({ status: 'error', message: 'Failed to delete portfolio', details: error.message });
    }
});

// --- Nested Routes for Properties within a Portfolio ---

// POST /api/v1/portfolios/:portfolioId/properties - Create and add a new property to this portfolio
router.post('/:portfolioId/properties', checkPortfolioAccessAndLoad, async (req, res) => {
    const { portfolioId } = req.params;
    const { name, address, managerUserIds } = req.body;
    const currentPortfolio = req.portfolio; // Loaded by checkPortfolioAccessAndLoad

    // Authorization: User must have "OWNER" or "PORTFOLIO_ADMIN" role for this portfolioId.
    if (req.userPortfolioRole !== Role.OWNER && req.userPortfolioRole !== Role.PORTFOLIO_ADMIN) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. You do not have permission to add properties to this portfolio.' });
    }

    if (!name) {
        return res.status(400).json({ status: 'error', message: 'Property name is required.' });
    }

    try {
        const newProperty = new Property({
            name,
            portfolioId: currentPortfolio._id,
            address, 
        });
        await newProperty.save();

        // Add propertyId to the portfolio's propertyIds array
        currentPortfolio.propertyIds.addToSet(newProperty._id); // addToSet prevents duplicates
        currentPortfolio.updatedAt = Date.now();
        await currentPortfolio.save();

        const propertyManagerRolesPromises = [];
        if (managerUserIds && managerUserIds.length > 0) {
            managerUserIds.forEach(managerId => {
                propertyManagerRolesPromises.push(
                    new UserRoleAssociation({
                        userId: managerId,
                        associatedEntityType: AssociatedEntityType.PROPERTY,
                        associatedEntityId: newProperty._id,
                        roleWithinEntity: Role.PROPERTY_MANAGER,
                    }).save()
                );
            });
            await Promise.all(propertyManagerRolesPromises);
        }

        res.status(201).json({ status: 'success', data: { property: newProperty } });
    } catch (error) {
        console.error('Error creating property in portfolio:', error);
        res.status(500).json({ status: 'error', message: 'Failed to create property', details: error.message });
    }
});

// GET /api/v1/portfolios/:portfolioId/properties - List all properties within this portfolio
router.get('/:portfolioId/properties', checkPortfolioAccessAndLoad, async (req, res) => {
    const { portfolioId } = req.params;
    // Access is already verified by checkPortfolioAccessAndLoad middleware.

    try {
        const properties = await Property.find({ portfolioId });
        res.status(200).json({ status: 'success', data: { properties } });
    } catch (error) {
        console.error('Error listing properties in portfolio:', error);
        res.status(500).json({ status: 'error', message: 'Failed to list properties', details: error.message });
    }
});

// --- Nested Routes for Admins of a Portfolio ---

// POST /api/v1/portfolios/:portfolioId/admins - Add/invite an administrator to this portfolio
router.post('/:portfolioId/admins', checkPortfolioAccessAndLoad, async (req, res) => {
    const { portfolioId } = req.params;
    const { userId, role } = req.body; 
    const currentPortfolio = req.portfolio; // Loaded by checkPortfolioAccessAndLoad

    // Authorization: User must be "OWNER" of this portfolioId.
    if (req.userPortfolioRole !== Role.OWNER) {
        return res.status(403).json({ status: 'error', message: 'Forbidden. Only the portfolio owner can manage administrators.' });
    }

    if (!userId || !role) {
        return res.status(400).json({ status: 'error', message: 'User ID and role are required.' });
    }

    if (role !== Role.PORTFOLIO_ADMIN && role !== Role.OWNER) {
        return res.status(400).json({ status: 'error', message: `Invalid role. Must be ${Role.PORTFOLIO_ADMIN} or ${Role.OWNER}.` });
    }

    try {
        const userExists = await User.findById(userId);
        if (!userExists) {
            return res.status(404).json({ status: 'error', message: 'User to be added as admin not found.' });
        }

        let association = await UserRoleAssociation.findOneAndUpdate(
            { // find condition
                userId: userId,
                associatedEntityType: AssociatedEntityType.PORTFOLIO,
                associatedEntityId: portfolioId,
            },
            { // update or insert
                $set: { roleWithinEntity: role }
            },
            { upsert: true, new: true, runValidators: true } // options
        );
        
        // Add userId to portfolio's administratorUserIds array if not already present
        currentPortfolio.administratorUserIds.addToSet(new mongoose.Types.ObjectId(userId));
        currentPortfolio.updatedAt = Date.now();
        await currentPortfolio.save();

        res.status(200).json({ status: 'success', data: { userRoleAssociation: association } });
    } catch (error) {
        console.error('Error adding portfolio admin:', error);
        if (error.kind === 'ObjectId') {
             return res.status(400).json({ status: 'error', message: 'Invalid userId format.' });
        }
        res.status(500).json({ status: 'error', message: 'Failed to add portfolio administrator', details: error.message });
    }
});

module.exports = router; 