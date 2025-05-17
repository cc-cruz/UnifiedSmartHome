import { UserRoleAssociation } from './UserRoleAssociation';

// Note: The existing User.js uses an embedded array of roleAssociations.
// The plan (app-submission-steps.md) recommends a separate UserRoleAssociation collection/table
// for better query flexibility, especially with many-to-many role assignments.
// This User interface reflects that separation, where UserRoleAssociation records would reference userId.

export interface User {
    id: string; // PK (UUID/ObjectID)
    firstName: string;
    lastName: string;
    email: string; // Unique, indexed
    passwordHash: string; // Store a hash, not plain password

    // Multi-tenancy default navigation preferences
    defaultPortfolioId?: string | null; // Optional, FK to Portfolio
    defaultPropertyId?: string | null; // Optional, FK to Property
    defaultUnitId?: string | null; // Optional, FK to Unit

    // Timestamps
    createdAt: Date;
    updatedAt: Date;

    // Deprecated fields (as per User.js and plan):
    // role?: string; (simple role)
    // properties?: string[]; (direct property links)

    // Instead of a direct array here like in the current User.js,
    // role associations are managed in the separate UserRoleAssociation model/collection.
    // An ORM might provide a way to easily fetch these, e.g., user.getRoleAssociations().
    // roleAssociations?: UserRoleAssociation[]; // This would be populated by a query, not stored directly on User document if following separate collection model.

    // Guest access fields - these were in User.js, align with plan if necessary.
    // If guest access is also managed by UserRoleAssociation with a GUEST role, these might be redundant or refactored.
    guestAccess?: {
        deviceIds: string[];
        validFrom?: Date | null;
        validUntil?: Date | null;
        propertyId?: string | null;
        unitId?: string | null;
    };
}

// Example Mongoose-style schema (illustrative, and showing changes from current User.js)
/*
import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
    firstName: string;
    lastName: string;
    email: string;
    passwordHash: string;
    defaultPortfolioId?: mongoose.Types.ObjectId | null;
    defaultPropertyId?: mongoose.Types.ObjectId | null;
    defaultUnitId?: mongoose.Types.ObjectId | null;
    guestAccess?: {
        deviceIds: string[];
        validFrom?: Date | null;
        validUntil?: Date | null;
        propertyId?: mongoose.Types.ObjectId | null;
        unitId?: mongoose.Types.ObjectId | null;
    };
    // createdAt, updatedAt managed by timestamps: true

    // Note: roleAssociations array is REMOVED from User schema if using a separate collection.
}

const UserSchema: Schema = new Schema(
    {
        firstName: { type: String, required: true, trim: true },
        lastName: { type: String, required: true, trim: true },
        email: { type: String, required: true, unique: true, trim: true, lowercase: true },
        passwordHash: { type: String, required: true }, // Password field name changed for clarity
        defaultPortfolioId: { type: Schema.Types.ObjectId, ref: 'Portfolio', default: null },
        defaultPropertyId: { type: Schema.Types.ObjectId, ref: 'Property', default: null },
        defaultUnitId: { type: Schema.Types.ObjectId, ref: 'Unit', default: null },
        guestAccess: {
            deviceIds: [{ type: String }], // Assuming device IDs are strings
            validFrom: { type: Date, default: null },
            validUntil: { type: Date, default: null },
            propertyId: { type: Schema.Types.ObjectId, ref: 'Property', default: null },
            unitId: { type: Schema.Types.ObjectId, ref: 'Unit', default: null },
        },
        // roleAssociations: [UserRoleAssociationSchema] // This line is REMOVED.
    },
    { timestamps: true }
);

// UserSchema.methods.toJSON and pre-save hooks would be similar to existing User.js

// export default mongoose.model<IUser>('User', UserSchema);
*/ 