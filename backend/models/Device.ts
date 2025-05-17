export interface DeviceCapability {
    type: string;
    attributes?: any; // Can be more specific if attributes structure is known
}

export enum DeviceManufacturer {
    SAMSUNG = "SAMSUNG",
    LG = "LG",
    GE = "GE",
    GOOGLE_NEST = "GOOGLE_NEST",
    PHILIPS_HUE = "PHILIPS_HUE",
    AMAZON = "AMAZON",
    APPLE = "APPLE",
    OTHER = "OTHER",
}

export enum DeviceType {
    LIGHT = "LIGHT",
    THERMOSTAT = "THERMOSTAT",
    LOCK = "LOCK",
    CAMERA = "CAMERA",
    DOORBELL = "DOORBELL",
    SPEAKER = "SPEAKER",
    TV = "TV",
    APPLIANCE = "APPLIANCE",
    SENSOR = "SENSOR",
    OTHER = "OTHER",
}

export enum DeviceStatus {
    ONLINE = "ONLINE",
    OFFLINE = "OFFLINE",
    ERROR = "ERROR",
}

export interface Device {
    id: string; // PK (UUID/ObjectID)
    name: string;
    manufacturer: DeviceManufacturer;
    type: DeviceType;
    status: DeviceStatus;
    capabilities?: DeviceCapability[];
    integrationData?: any; // Integration-specific data
    metadata?: any; // Device-specific metadata

    // Multi-tenancy links (as per app-submission-steps.md)
    propertyId?: string | null; // FK to Property, indexed, nullable
    unitId?: string | null; // FK to Unit, indexed, nullable (replaces/aligns with old `room` field)

    // Timestamps
    createdAt: Date;
    updatedAt: Date;
}

// Example Mongoose-style schema (illustrative, showing changes from current Device.js)
/*
import mongoose, { Schema, Document } from 'mongoose';

// DeviceCapabilitySchema can be kept as is from Device.js or typed if needed
const DeviceCapabilitySchema: Schema = new Schema({
    type: { type: String, required: true, trim: true },
    attributes: { type: Schema.Types.Mixed, default: {} }
});

export interface IDevice extends Document {
    name: string;
    manufacturer: DeviceManufacturer;
    type: DeviceType;
    status: DeviceStatus;
    capabilities?: any[]; // Assuming DeviceCapability becomes a typed array
    integrationData?: any;
    metadata?: any;
    propertyId?: mongoose.Types.ObjectId | null;
    unitId?: mongoose.Types.ObjectId | null;
    // createdAt, updatedAt managed by timestamps: true
}

const DeviceSchema: Schema = new Schema(
    {
        name: { type: String, required: true, trim: true },
        manufacturer: { type: String, enum: Object.values(DeviceManufacturer), required: true },
        type: { type: String, enum: Object.values(DeviceType), required: true },
        status: { type: String, enum: Object.values(DeviceStatus), default: DeviceStatus.OFFLINE },
        capabilities: [DeviceCapabilitySchema],
        integrationData: { type: Schema.Types.Mixed, default: {} },
        metadata: { type: Schema.Types.Mixed, default: {} },

        // Updated fields for multi-tenancy
        propertyId: { type: Schema.Types.ObjectId, ref: 'Property', index: true, default: null }, // Was 'property', now nullable
        unitId: { type: Schema.Types.ObjectId, ref: 'Unit', index: true, default: null },       // Was 'room', ref changed to 'Unit', now nullable
    },
    { timestamps: true }
);

// export default mongoose.model<IDevice>('Device', DeviceSchema);
*/ 