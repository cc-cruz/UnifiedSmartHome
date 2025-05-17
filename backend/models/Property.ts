// Corresponds to iOS PropertyAddress, and as specified in app-submission-steps.md for backend.
export interface PropertyAddress {
    street: string;
    city: string;
    state: string;
    postalCode: string;
    country: string;
}

export interface Property {
    id: string; // PK (UUID/ObjectID)
    name: string; // Required, indexed
    portfolioId: string; // FK to Portfolio, indexed, required
    address?: PropertyAddress; // Optional, structured object. Plan mentions "String or structured object".
    // Similar to Portfolio, managerUserIds is an option vs. UserRoleAssociation.
    // PROPERTY_MANAGER roles for this property would be via UserRoleAssociation.
    managerUserIds?: string[]; // UserIDs, indexed.
    unitIds?: string[]; // UnitIDs, indexed
    defaultTimeZone?: string; // Optional
    createdAt: Date;
    updatedAt: Date;
}

// Example Mongoose-style schema (illustrative)
/*
import mongoose, { Schema, Document } from 'mongoose';

// Assuming PropertyAddress is defined as a sub-schema if using Mongoose
const PropertyAddressSchema: Schema = new Schema({
    street: { type: String, required: true },
    city: { type: String, required: true },
    state: { type: String, required: true },
    postalCode: { type: String, required: true },
    country: { type: String, required: true },
}, { _id: false }); // _id: false if it's an embedded subdocument without its own ID

export interface IProperty extends Document {
    name: string;
    portfolioId: mongoose.Types.ObjectId; // Reference to Portfolio document
    address?: PropertyAddress; // Embeds the PropertyAddress schema
    managerUserIds?: mongoose.Types.ObjectId[];
    unitIds?: mongoose.Types.ObjectId[];
    defaultTimeZone?: string;
}

const PropertySchema: Schema = new Schema(
    {
        name: { type: String, required: true, index: true },
        portfolioId: { type: Schema.Types.ObjectId, ref: 'Portfolio', required: true, index: true },
        address: { type: PropertyAddressSchema, required: false }, // Embed the address schema
        managerUserIds: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
        unitIds: [{ type: Schema.Types.ObjectId, ref: 'Unit', index: true }],
        defaultTimeZone: { type: String, required: false },
    },
    { timestamps: true } // Handles createdAt and updatedAt
);

// export default mongoose.model<IProperty>('Property', PropertySchema);
*/ 