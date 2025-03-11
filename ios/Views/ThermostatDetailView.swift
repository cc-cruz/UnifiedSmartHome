import SwiftUI

struct ThermostatDetailView: View {
    @ObservedObject var viewModel: ThermostatViewModel
    let thermostat: ThermostatDevice
    
    @State private var targetTemperature: Double
    @State private var selectedMode: ThermostatDevice.ThermostatMode
    
    init(viewModel: ThermostatViewModel, thermostat: ThermostatDevice) {
        self.viewModel = viewModel
        self.thermostat = thermostat
        _targetTemperature = State(initialValue: thermostat.targetTemperature)
        _selectedMode = State(initialValue: thermostat.mode)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Temperature display
                temperatureDisplay
                
                // Temperature control
                temperatureControl
                
                // Mode selector
                modeSelector
                
                // Apply button
                applyButton
            }
            .padding()
        }
        .navigationTitle(thermostat.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.error ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            viewModel.isLoading ? 
                ProgressView("Updating...")
                .padding()
                .background(Color.secondary.colorInvert())
                .cornerRadius(10)
                .shadow(radius: 5)
                : nil
        )
    }
    
    // Temperature display with current temperature and mode
    private var temperatureDisplay: some View {
        VStack(spacing: 10) {
            // Current temperature
            HStack(alignment: .top, spacing: 0) {
                Text("\(Int(thermostat.currentTemperature))")
                    .font(.system(size: 80, weight: .semibold, design: .rounded))
                
                Text("°\(thermostat.units == .celsius ? "C" : "F")")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .padding(.top, 10)
            }
            
            Text("Current Temperature")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Mode indicator
            Label(
                title: { Text(modeText(for: thermostat.mode)) },
                icon: { Image(systemName: iconName(for: thermostat.mode)) }
            )
            .foregroundColor(iconColor(for: thermostat.mode))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(iconColor(for: thermostat.mode).opacity(0.2))
            .cornerRadius(15)
            .padding(.top, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
    }
    
    // Temperature control slider
    private var temperatureControl: some View {
        VStack(spacing: 15) {
            Text("Set Temperature")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 0) {
                Text("\(Int(targetTemperature))")
                    .font(.system(size: 60, weight: .semibold, design: .rounded))
                
                Text("°\(thermostat.units == .celsius ? "C" : "F")")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .padding(.top, 10)
            }
            
            // Temperature slider
            Slider(value: $targetTemperature, in: 10...30, step: 0.5)
                .accentColor(iconColor(for: selectedMode))
            
            // Quick preset buttons
            HStack(spacing: 20) {
                Button {
                    targetTemperature = 18
                } label: {
                    Text("18°")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button {
                    targetTemperature = 20
                } label: {
                    Text("20°")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button {
                    targetTemperature = 22
                } label: {
                    Text("22°")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button {
                    targetTemperature = 24
                } label: {
                    Text("24°")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
    }
    
    // Mode selector
    private var modeSelector: some View {
        VStack(spacing: 15) {
            Text("Mode")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach([ThermostatDevice.ThermostatMode.heat, 
                         .cool, 
                         .auto, 
                         .eco, 
                         .off], id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: iconName(for: mode))
                                .font(.system(size: 20))
                            
                            Text(modeText(for: mode))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedMode == mode ?
                                iconColor(for: mode).opacity(0.2) :
                                Color(UIColor.tertiarySystemBackground)
                        )
                        .foregroundColor(
                            selectedMode == mode ?
                                iconColor(for: mode) :
                                Color.primary
                        )
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
    }
    
    // Apply button to save changes
    private var applyButton: some View {
        Button {
            // Check if temperature or mode has changed
            if targetTemperature != thermostat.targetTemperature {
                viewModel.setTemperature(for: thermostat, to: targetTemperature)
            }
            
            if selectedMode != thermostat.mode {
                viewModel.setMode(for: thermostat, to: selectedMode)
            }
        } label: {
            Text("Apply Changes")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    (targetTemperature != thermostat.targetTemperature || selectedMode != thermostat.mode) ?
                        Color.blue :
                        Color.gray
                )
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(targetTemperature == thermostat.targetTemperature && selectedMode == thermostat.mode)
    }
    
    // MARK: - Helper Functions
    
    // Icon name based on thermostat mode
    private func iconName(for mode: ThermostatDevice.ThermostatMode) -> String {
        switch mode {
        case .heat:
            return "flame.fill"
        case .cool:
            return "snowflake"
        case .auto:
            return "thermometer"
        case .eco:
            return "leaf.fill"
        case .off:
            return "power"
        }
    }
    
    // Color based on thermostat mode
    private func iconColor(for mode: ThermostatDevice.ThermostatMode) -> Color {
        switch mode {
        case .heat:
            return .orange
        case .cool:
            return .blue
        case .auto:
            return .purple
        case .eco:
            return .green
        case .off:
            return .gray
        }
    }
    
    // Text representation of mode
    private func modeText(for mode: ThermostatDevice.ThermostatMode) -> String {
        switch mode {
        case .heat:
            return "Heat"
        case .cool:
            return "Cool"
        case .auto:
            return "Auto"
        case .eco:
            return "Eco"
        case .off:
            return "Off"
        }
    }
}

struct ThermostatDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock thermostat for preview
        let capabilities = [
            Device.DeviceCapability(type: "temperature", attributes: [
                "current": AnyCodable(21.5),
                "target": AnyCodable(22.0)
            ]),
            Device.DeviceCapability(type: "mode", attributes: [
                "value": AnyCodable("HEAT")
            ])
        ]
        
        let thermostat = ThermostatDevice(
            id: "preview_thermostat",
            name: "Living Room",
            manufacturer: .googleNest,
            roomId: nil,
            propertyId: "default",
            status: .online,
            capabilities: capabilities,
            currentTemperature: 21.5,
            targetTemperature: 22.0,
            mode: .heat,
            units: .celsius
        )
        
        return NavigationView {
            ThermostatDetailView(viewModel: ThermostatViewModel(), thermostat: thermostat)
        }
    }
} 