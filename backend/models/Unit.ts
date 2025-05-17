export interface Unit {
    id: string; // PK (UUID/ObjectID)
    name: string; // Required, indexed
    propertyId: string; // FK to Property, indexed, required
    deviceIds?: string[]; // DeviceIDs, indexed
    // TENANT roles for this unit would be managed via UserRoleAssociation.
    tenantUserIds?: string[]; // UserIDs, indexed. 
    commonAreaAccessIds?: string[]; // DeviceIDs, optional, indexed (e.g., access to shared amenities)
    createdAt: Date;
    updatedAt: Date;
}

// Example Mongoose-style schema (illustrative)
/*
import mongoose, { Schema, Document } from 'mongoose';

export interface IUnit extends Document {
    name: string;
    propertyId: mongoose.Types.ObjectId; // Reference to Property document
    deviceIds?: mongoose.Types.ObjectId[];
    tenantUserIds?: mongoose.Types.ObjectId[];
    commonAreaAccessIds?: mongoose.Types.ObjectId[];
}

const UnitSchema: Schema = new Schema(
    {
        name: { type: String, required: true, index: true },
        propertyId: { type: Schema.Types.ObjectId, ref: 'Property', required: true, index: true },
        deviceIds: [{ type: Schema.Types.ObjectId, ref: 'Device', index: true }],
        tenantUserIds: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
        commonAreaAccessIds: [{ type: Schema.Types.ObjectId, ref: 'Device', index: true, required: false }],
    },
    { timestamps: true } // Handles createdAt and updatedAt
);

// export default mongoose.model<IUnit>('Unit', UnitSchema);
*/ 