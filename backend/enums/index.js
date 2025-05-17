const AssociatedEntityType = Object.freeze({
    PORTFOLIO: 'PORTFOLIO',
    PROPERTY: 'PROPERTY',
    UNIT: 'UNIT',
});

const Role = Object.freeze({
    OWNER: 'OWNER',
    PORTFOLIO_ADMIN: 'PORTFOLIO_ADMIN',
    PROPERTY_MANAGER: 'PROPERTY_MANAGER',
    TENANT: 'TENANT',
    SUPER_ADMIN: 'SUPER_ADMIN',
    // Add other roles as needed, e.g., SUPER_ADMIN
});

module.exports = {
    AssociatedEntityType,
    Role,
}; 