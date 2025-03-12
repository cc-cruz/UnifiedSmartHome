import SwiftUI

struct ThermostatDetailView: View {
    @ObservedObject var viewModel: ThermostatViewModel
    let thermostat: ThermostatDevice
    
    @State private var targetTemperature: Double
    @State private var selectedMode: ThermostatDevice.ThermostatMode
    @State private var isEditing = false
    
    // Temperature unit for display
    @State private var temperatureUnit: TemperatureUnit = .celsius
    
    init(viewModel: ThermostatViewModel, thermostat: ThermostatDevice) {
        self.viewModel = viewModel
        self.thermostat = thermostat
        
        // Initialize state from thermostat
        _targetTemperature = State(initialValue: thermostat.targetTemperature)
        _selectedMode = State(initialValue: thermostat.mode)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top info card
                VStack(spacing: 8) {
                    Text(thermostat.name)
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Current: \(thermostat.formattedTemperature(thermostat.currentTemperature, unit: temperatureUnit))")
                        .font(.subheadline)
                    
                    // Temperature control
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 20)
                            .opacity(0.3)
                            .foregroundColor(modeColor)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(targetTemperature / 40, 1.0)))
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                            .foregroundColor(modeColor)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: targetTemperature)
                        
                        VStack {
                            Text("Target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(thermostat.formattedTemperature(targetTemperature, unit: temperatureUnit))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(modeColor)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .padding(.vertical)
                    
                    // Temperature slider
                    VStack {
                        Slider(
                            value: $targetTemperature,
                            in: 10...32,
                            step: 0.5,
                            onEditingChanged: { editing in
                                isEditing = editing
                                if !editing {
                                    viewModel.setTemperature(for: thermostat, to: targetTemperature)
                                }
                            }
                        )
                        .accentColor(modeColor)
                        .padding(.horizontal)
                        
                        HStack {
                            Text("10°")
                            Spacer()
                            Text("32°")
                        }
                        .font(.caption)
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Mode selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mode")
                        .font(.headline)
                    
                    HStack(spacing: 10) {
                        ForEach(thermostat.availableModes) { mode in
                            ModeButton(
                                mode: mode,
                                isSelected: selectedMode == mode,
                                action: {
                                    selectedMode = mode
                                    viewModel.setMode(for: thermostat, to: mode)
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Unit toggle
                HStack {
                    Text("Temperature Unit:")
                    Picker("", selection: $temperatureUnit) {
                        Text("Celsius").tag(TemperatureUnit.celsius)
                        Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Error display
                if let error = viewModel.error {
                    ErrorView(errorMessage: error)
                }
                
                // Loading indicator
                if viewModel.isLoading {
                    LoadingView()
                }
            }
            .padding()
        }
        .navigationTitle("Thermostat Details")
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        // Update local state when the thermostat data refreshes
        .onChange(of: thermostat.targetTemperature) { newValue in
            if !isEditing {
                targetTemperature = newValue
            }
        }
        .onChange(of: thermostat.mode) { newValue in
            selectedMode = newValue
        }
    }
    
    private var modeColor: Color {
        switch selectedMode {
        case .heat:
            return .orange
        case .cool:
            return .blue
        case .auto:
            return .purple
        case .off:
            return .gray
        }
    }
}

struct ModeButton: View {
    let mode: ThermostatDevice.ThermostatMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: mode.iconName)
                    .font(.system(size: 24))
                Text(mode.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(isSelected ? colorForMode.opacity(0.2) : Color(.systemBackground))
            .foregroundColor(isSelected ? colorForMode : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? colorForMode : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var colorForMode: Color {
        switch mode {
        case .heat: return .orange
        case .cool: return .blue
        case .auto: return .purple
        case .off: return .gray
        }
    }
}

// Loading view
struct LoadingView: View {
    var body: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Processing...")
                .foregroundColor(.secondary)
                .padding(.leading, 10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// Error view
struct ErrorView: View {
    let errorMessage: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(errorMessage)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
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