import { AssociatedEntityType } from '../enums/AssociatedEntityType';
import { Role } from '../enums/Role';

export interface UserRoleAssociation {
    id: string; // PK
    userId: string; // FK to User, indexed, required
    associatedEntityType: AssociatedEntityType; // String Enum: "PORTFOLIO", "PROPERTY", "UNIT", required, indexed
    associatedEntityId: string; // Refers to ID in Portfolio/Property/Unit, required, indexed
    roleWithinEntity: Role; // String Enum mirroring iOS User.Role, required, indexed
    createdAt: Date;
    updatedAt: Date;
}

// Example Mongoose-style schema (illustrative)
/*
import mongoose, { Schema, Document } from 'mongoose';

export interface IUserRoleAssociation extends Document {
    userId: mongoose.Types.ObjectId;
    associatedEntityType: AssociatedEntityType;
    associatedEntityId: mongoose.Types.ObjectId; // Or String if IDs are not ObjectIds for all associated types
    roleWithinEntity: Role;
}

const UserRoleAssociationSchema: Schema = new Schema(
    {
        userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
        associatedEntityType: { type: String, enum: Object.values(AssociatedEntityType), required: true, index: true },
        associatedEntityId: { type: Schema.Types.ObjectId, required: true, index: true }, // Needs to dynamically refPath if using Mongoose refs to different collections
        roleWithinEntity: { type: String, enum: Object.values(Role), required: true, index: true },
    },
    {
        timestamps: true, // Handles createdAt and updatedAt
        // Potentially add compound indexes for efficient querying as suggested in the plan
        // e.g., indexes: [ { fields: { userId: 1, associatedEntityType: 1, associatedEntityId: 1 } } ]
    }
);

// If using Mongoose and need dynamic refs for associatedEntityId based on associatedEntityType:
// UserRoleAssociationSchema.path('associatedEntityId').refPath = 'associatedEntityType';
// This requires associatedEntityType values to match model names if using Mongoose string refs.

// export default mongoose.model<IUserRoleAssociation>('UserRoleAssociation', UserRoleAssociationSchema);
*/ 