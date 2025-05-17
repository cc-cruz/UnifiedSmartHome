import { Role } from '../enums/Role';

// Base interface or class for common fields (id, createdAt, updatedAt) assumed to be handled by ORM or a base class.

export interface Portfolio {
    id: string; // Primary Key (UUID/ObjectID)
    name: string; // Required, indexed
    // As per app-submission-steps.md, administratorUserIds is an option.
    // However, the preferred method for tenancy is UserRoleAssociation.
    // If direct admin links are simpler for a Portfolio's top-level admins, this can be kept.
    // Otherwise, roles like OWNER or PORTFOLIO_ADMIN for a portfolio would be managed via UserRoleAssociation.
    administratorUserIds?: string[]; // UserIDs, indexed. 
    propertyIds?: string[]; // PropertyIDs, indexed
    createdAt: Date;
    updatedAt: Date;
}

// Example Mongoose-style schema (illustrative)
/*
import mongoose, { Schema, Document } from 'mongoose';

export interface IPortfolio extends Document {
    name: string;
    administratorUserIds?: mongoose.Types.ObjectId[];
    propertyIds?: mongoose.Types.ObjectId[];
    // createdAt and updatedAt are typically handled by { timestamps: true } in Mongoose
}

const PortfolioSchema: Schema = new Schema(
    {
        name: { type: String, required: true, index: true },
        administratorUserIds: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
        propertyIds: [{ type: Schema.Types.ObjectId, ref: 'Property', index: true }],
    },
    { timestamps: true } // Adds createdAt and updatedAt automatically
);

// If using Mongoose, you would export the model:
// export default mongoose.model<IPortfolio>('Portfolio', PortfolioSchema);
*/ 