const SmartThingsToken = require('../models/SmartThingsToken');
const logger = require('../logger');

class SmartThingsService {
  constructor() {
    this.baseUrl = 'https://api.smartthings.com/v1';
  }

  // Get headers for SmartThings API calls
  getHeaders(accessToken) {
    return {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
  }

  // Get active token for user/property/unit
  async getActiveToken(userId, propertyId = null, unitId = null) {
    return await SmartThingsToken.findActiveToken(userId, propertyId, unitId)
      .select('+accessToken +refreshToken');
  }

  // Transform device capabilities to iOS-compatible format
  transformDeviceCapabilities(capabilities) {
    return capabilities.map(capability => {
      const transformed = {
        id: capability.id,
        version: capability.version
      };

      // Add capability-specific transformations
      switch (capability.id) {
        case 'switch':
          transformed.commands = ['on', 'off'];
          transformed.attributes = ['switch'];
          break;
        case 'switchLevel':
          transformed.commands = ['setLevel'];
          transformed.attributes = ['level'];
          break;
        case 'colorControl':
          transformed.commands = ['setColor', 'setHue', 'setSaturation'];
          transformed.attributes = ['color', 'hue', 'saturation'];
          break;
        case 'thermostat':
          transformed.commands = ['setHeatingSetpoint', 'setCoolingSetpoint', 'setThermostatMode'];
          transformed.attributes = ['temperature', 'heatingSetpoint', 'coolingSetpoint', 'thermostatMode'];
          break;
        case 'lock':
          transformed.commands = ['lock', 'unlock'];
          transformed.attributes = ['lock'];
          break;
        default:
          // Generic capability handling
          transformed.commands = [];
          transformed.attributes = [];
      }

      return transformed;
    });
  }

  // Transform device status to iOS-compatible format
  transformDeviceStatus(status) {
    const transformed = {};
    
    if (status.switch) {
      transformed.switch = {
        value: status.switch.value,
        timestamp: status.switch.timestamp
      };
    }
    
    if (status.level) {
      transformed.level = {
        value: status.level.value,
        unit: status.level.unit,
        timestamp: status.level.timestamp
      };
    }
    
    if (status.color) {
      transformed.color = {
        value: status.color.value,
        timestamp: status.color.timestamp
      };
    }
    
    if (status.temperature) {
      transformed.temperature = {
        value: status.temperature.value,
        unit: status.temperature.unit,
        timestamp: status.temperature.timestamp
      };
    }
    
    if (status.lock) {
      transformed.lock = {
        value: status.lock.value,
        timestamp: status.lock.timestamp
      };
    }
    
    return transformed;
  }

  // Execute device command with iOS-compatible format
  async executeDeviceCommand(userId, deviceId, commandType, parameters, propertyId = null, unitId = null) {
    try {
      // Get active token
      const tokenRecord = await this.getActiveToken(userId, propertyId, unitId);
      if (!tokenRecord) {
        throw new Error('SmartThings integration not found');
      }

      if (tokenRecord.isExpired()) {
        throw new Error('Token expired');
      }

      // Transform iOS command format to SmartThings format
      const smartThingsCommand = this.transformCommand(commandType, parameters);
      
      // Send command to SmartThings
      const response = await fetch(`${this.baseUrl}/devices/${deviceId}/commands`, {
        method: 'POST',
        headers: this.getHeaders(tokenRecord.accessToken),
        body: JSON.stringify({
          commands: [smartThingsCommand]
        })
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`SmartThings command failed: ${error}`);
      }

      const result = await response.json();
      
      logger.info('SmartThings command executed successfully', {
        userId,
        deviceId,
        commandType,
        parameters,
        result
      });

      return {
        success: true,
        commandId: result.id,
        status: 'COMPLETED'
      };

    } catch (error) {
      logger.error('SmartThings command execution failed', {
        userId,
        deviceId,
        commandType,
        parameters,
        error: error.message
      });
      throw error;
    }
  }

  // Transform iOS command format to SmartThings format
  transformCommand(commandType, parameters) {
    const command = {
      component: 'main',
      capability: this.getCapabilityForCommand(commandType),
      command: commandType
    };

    // Add command-specific arguments
    switch (commandType) {
      case 'on':
      case 'off':
        // No arguments needed for switch commands
        break;
      
      case 'setLevel':
        command.arguments = [parameters.level];
        break;
      
      case 'setColor':
        command.arguments = [parameters.color];
        break;
      
      case 'setHue':
        command.arguments = [parameters.hue];
        break;
      
      case 'setSaturation':
        command.arguments = [parameters.saturation];
        break;
      
      case 'setHeatingSetpoint':
        command.arguments = [parameters.temperature];
        break;
      
      case 'setCoolingSetpoint':
        command.arguments = [parameters.temperature];
        break;
      
      case 'setThermostatMode':
        command.arguments = [parameters.mode];
        break;
      
      case 'lock':
      case 'unlock':
        // No arguments needed for lock commands
        break;
      
      default:
        // Generic command handling
        if (parameters.arguments) {
          command.arguments = parameters.arguments;
        }
    }

    return command;
  }

  // Get capability name for command
  getCapabilityForCommand(commandType) {
    const commandCapabilityMap = {
      'on': 'switch',
      'off': 'switch',
      'setLevel': 'switchLevel',
      'setColor': 'colorControl',
      'setHue': 'colorControl',
      'setSaturation': 'colorControl',
      'setHeatingSetpoint': 'thermostat',
      'setCoolingSetpoint': 'thermostat',
      'setThermostatMode': 'thermostat',
      'lock': 'lock',
      'unlock': 'lock'
    };

    return commandCapabilityMap[commandType] || 'switch';
  }

  // Get device health status
  async getDeviceHealth(userId, deviceId, propertyId = null, unitId = null) {
    try {
      const tokenRecord = await this.getActiveToken(userId, propertyId, unitId);
      if (!tokenRecord) {
        throw new Error('SmartThings integration not found');
      }

      const response = await fetch(`${this.baseUrl}/devices/${deviceId}/health`, {
        headers: this.getHeaders(tokenRecord.accessToken)
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Failed to get device health: ${error}`);
      }

      const healthData = await response.json();
      
      return {
        deviceId,
        state: healthData.state,
        lastUpdatedDate: healthData.lastUpdatedDate,
        healthStatus: healthData.healthStatus
      };

    } catch (error) {
      logger.error('Failed to get device health', {
        userId,
        deviceId,
        error: error.message
      });
      throw error;
    }
  }

  // Batch command execution for multiple devices
  async executeBatchCommands(userId, commands, propertyId = null, unitId = null) {
    try {
      const tokenRecord = await this.getActiveToken(userId, propertyId, unitId);
      if (!tokenRecord) {
        throw new Error('SmartThings integration not found');
      }

      const results = [];
      
      // Execute commands in parallel (limit concurrency to avoid rate limits)
      const batchSize = 5;
      for (let i = 0; i < commands.length; i += batchSize) {
        const batch = commands.slice(i, i + batchSize);
        
        const batchPromises = batch.map(async (cmd) => {
          try {
            const result = await this.executeDeviceCommand(
              userId,
              cmd.deviceId,
              cmd.commandType,
              cmd.parameters,
              propertyId,
              unitId
            );
            return { ...cmd, result };
          } catch (error) {
            return { ...cmd, error: error.message };
          }
        });

        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);
      }

      return results;

    } catch (error) {
      logger.error('Batch command execution failed', {
        userId,
        commandCount: commands.length,
        error: error.message
      });
      throw error;
    }
  }

  // Get device history/events
  async getDeviceHistory(userId, deviceId, propertyId = null, unitId = null, limit = 50) {
    try {
      const tokenRecord = await this.getActiveToken(userId, propertyId, unitId);
      if (!tokenRecord) {
        throw new Error('SmartThings integration not found');
      }

      const response = await fetch(`${this.baseUrl}/devices/${deviceId}/events?limit=${limit}`, {
        headers: this.getHeaders(tokenRecord.accessToken)
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Failed to get device history: ${error}`);
      }

      const historyData = await response.json();
      
      return {
        deviceId,
        events: historyData.events || [],
        nextToken: historyData.nextToken
      };

    } catch (error) {
      logger.error('Failed to get device history', {
        userId,
        deviceId,
        error: error.message
      });
      throw error;
    }
  }
}

module.exports = new SmartThingsService(); 