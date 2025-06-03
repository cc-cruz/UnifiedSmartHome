import SwiftUI
import StoreKit

struct CompliancePackView: View {
    @StateObject private var iapViewModel = IAPViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Feature Status
                    statusSection
                    
                    // Features List
                    featuresSection
                    
                    // Purchase Section
                    if !iapViewModel.hasCompliancePack {
                        purchaseSection
                    }
                    
                    // Compliance Report Section (if purchased)
                    if iapViewModel.hasCompliancePack {
                        complianceReportSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Compliance Pack")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Purchase Successful!", isPresented: $iapViewModel.showingPurchaseSuccess) {
            Button("OK") {
                iapViewModel.dismissSuccess()
            }
        } message: {
            Text("Thank you for purchasing the Compliance Pack! You now have access to advanced compliance features.")
        }
        .alert("Purchase Error", isPresented: $iapViewModel.showingPurchaseError) {
            Button("OK") {
                iapViewModel.dismissError()
            }
        } message: {
            Text(iapViewModel.errorMessage ?? "An error occurred during purchase.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Compliance Pack")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Advanced compliance reporting and analytics for your smart home devices")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        HStack {
            Image(systemName: iapViewModel.hasCompliancePack ? "checkmark.circle.fill" : "circle")
                .foregroundColor(iapViewModel.hasCompliancePack ? .green : .gray)
            
            Text(iapViewModel.complianceFeatureStatusMessage)
                .font(.headline)
                .foregroundColor(iapViewModel.hasCompliancePack ? .green : .primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Compliance Reports",
                    description: "Generate detailed compliance reports for your devices"
                )
                
                FeatureRow(
                    icon: "chart.bar.xaxis",
                    title: "Analytics Dashboard",
                    description: "Advanced analytics and insights for device usage"
                )
                
                FeatureRow(
                    icon: "bell.badge",
                    title: "Compliance Alerts",
                    description: "Get notified about compliance issues and recommendations"
                )
                
                FeatureRow(
                    icon: "doc.badge.gearshape",
                    title: "Audit Trail",
                    description: "Complete audit trail of all device operations"
                )
            }
        }
    }
    
    // MARK: - Purchase Section
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            Text("Upgrade Now")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button(action: {
                    iapViewModel.purchaseCompliancePack()
                }) {
                    HStack {
                        if iapViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cart.badge.plus")
                        }
                        
                        Text("Purchase for \(iapViewModel.compliancePackPrice)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(iapViewModel.isLoading || iapViewModel.compliancePackProduct == nil)
                
                Button("Restore Purchases") {
                    iapViewModel.restorePurchases()
                }
                .font(.footnote)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Compliance Report Section
    private var complianceReportSection: some View {
        VStack(spacing: 16) {
            Text("Compliance Features")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                NavigationLink(destination: ComplianceReportView()) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("View Compliance Report")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Generate and view detailed compliance reports")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // TODO: Implement analytics dashboard
                }) {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Analytics Dashboard")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Coming Soon - Advanced analytics and insights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .disabled(true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Compliance Report View (Placeholder)
struct ComplianceReportView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Compliance Report")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your compliance report is being generated...")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Text("Report will include:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Device security status")
                    Text("• Access control compliance")
                    Text("• Audit trail summary")
                    Text("• Recommendations")
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Compliance Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CompliancePackView()
} 