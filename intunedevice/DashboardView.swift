import SwiftUI

struct DashboardView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var searchText: String = ""
    @State private var showActionButtons = false
    
    @State private var selectedDeviceIDs = Set<String>()
    
    // Alert mekanizması için eklenen state değişkenleri
    @State private var showConfirmationAlert = false
    @State private var alertMessage: String = ""
    // Kullanıcının "Evet" dediğinde çalışacak eylem
    @State private var alertAction: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                // Arka plan gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.black.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 15) {
                    // Başlık
                    Text("📱 Intune Device Dashboard")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    // Arama çubuğu
                    HStack {
                        TextField("🔍 Search devices...", text: $searchText)
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(10)
                            .foregroundColor(.black)
                        
                        Button(action: {
                            // Basit arama filtresi
                            authManager.filteredDevicesList = authManager.devices.filter {
                                $0.deviceName?.lowercased().contains(searchText.lowercased()) ?? false
                            }
                        }) {
                            Text("Search")
                                .bold()
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Get All Devices + Refresh yan yana
                    HStack(spacing: 20) {
                        Button(action: {
                            Task {
                                await authManager.fetchDevices()
                            }
                        }) {
                            Text("✅ Get All Devices")
                                .bold()
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            Task {
                                // Basitçe tekrar fetchDevices çağırarak listeyi yenile
                                await authManager.fetchDevices()
                            }
                        }) {
                            Text("🔄 Refresh")
                                .bold()
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action butonu - alt butonları aç/kapat
                    Button(action: {
                        withAnimation {
                            showActionButtons.toggle()
                        }
                    }) {
                        Text("Action")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Sync, Wipe, Retire, Delete butonları
                    if showActionButtons {
                        HStack(spacing: 10) {
                            // SYNC
                            Button(action: {
                                alertMessage = "Are you sure you want to perform the sync operation?"
                                alertAction = {
                                    for deviceID in selectedDeviceIDs {
                                        authManager.syncDevice(deviceID: deviceID) { success in
                                            print("Sync for \(deviceID) -> \(success)")
                                        }
                                    }
                                }
                                showConfirmationAlert = true
                            }) {
                                ActionButton(title: "🔄 Sync", color: .blue)
                            }
                            
                            // WIPE
                            Button(action: {
                                alertMessage = "Are you sure you want to perform the Wipe operation?"
                                alertAction = {
                                    for deviceID in selectedDeviceIDs {
                                        authManager.wipeDevice(deviceID: deviceID) { success in
                                            print("Wipe for \(deviceID) -> \(success)")
                                        }
                                    }
                                }
                                showConfirmationAlert = true
                            }) {
                                ActionButton(title: "🧹 Wipe", color: .red)
                            }
                            
                            // RETIRE
                            Button(action: {
                                alertMessage = "Are you sure you want to perform the Retire operation?"
                                alertAction = {
                                    for deviceID in selectedDeviceIDs {
                                        authManager.retireDevice(deviceID: deviceID) { success in
                                            print("Retire for \(deviceID) -> \(success)")
                                        }
                                    }
                                }
                                showConfirmationAlert = true
                            }) {
                                ActionButton(title: "📴 Retire", color: .orange)
                            }
                            
                            // DELETE
                            Button(action: {
                                alertMessage = "Are you sure you want to perform the Delete operation?"
                                alertAction = {
                                    for deviceID in selectedDeviceIDs {
                                        authManager.deleteDevice(deviceID: deviceID) { success in
                                            print("Delete for \(deviceID) -> \(success)")
                                        }
                                    }
                                }
                                showConfirmationAlert = true
                            }) {
                                ActionButton(title: "🗑 Delete", color: .gray)
                            }
                        }
                        .transition(.slide)
                    }
                    
                    // Cihaz Listesi
                    ScrollView {
                        VStack(spacing: 10) {
                            if authManager.filteredDevicesList.isEmpty {
                                Text("No devices found 😔")
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding()
                            } else {
                                ForEach(authManager.filteredDevicesList) { device in
                                    NavigationLink(destination: DeviceDetailView(device: device)) {
                                        SelectableDeviceRow(
                                            device: device,
                                            isSelected: selectedDeviceIDs.contains(device.id),
                                            toggleSelection: {
                                                toggleSelection(deviceID: device.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            // NavigationView ayarları
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            
            // Alert tanımlaması
            .alert(alertMessage, isPresented: $showConfirmationAlert) {
                Button("Evet", role: .destructive) {
                    alertAction?()
                }
                Button("Hayır", role: .cancel) { }
            }
        }
    }
    
    // Çoklu seçim için toggling
    private func toggleSelection(deviceID: String) {
        if selectedDeviceIDs.contains(deviceID) {
            selectedDeviceIDs.remove(deviceID)
        } else {
            selectedDeviceIDs.insert(deviceID)
        }
    }
}

// MARK: - Action Button Görseli
struct ActionButton: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .bold()
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}

// MARK: - Satırda Checkbox + Cihaz Bilgisi
struct SelectableDeviceRow: View {
    let device: DeviceModel
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.deviceName ?? "Unknown Device")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                
                Text(device.manufacturer ?? "Unknown Manufacturer")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.subheadline)
                
                Text("Last Sync: \(device.complianceState ?? "N/A")")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
            }
            Spacer()
            
            // Compliance
            Text(device.complianceState?.lowercased() == "compliant" ? "✅ Compliant" : "❌ Non-Compliant")
                .padding(6)
                .background(
                    device.complianceState?.lowercased() == "compliant" ? Color.green : Color.red
                )
                .foregroundColor(.white)
                .cornerRadius(8)
            
            // Seçim butonu (checkbox)
            Button(action: {
                toggleSelection()
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(.white)
                    .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Cihaz Detay Ekranı
struct DeviceDetailView: View {
    let device: DeviceModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(device.deviceName ?? "Unknown Device")
                .font(.largeTitle)
                .bold()
            
            Text("Manufacturer: \(device.manufacturer ?? "N/A")")
            Text("Compliance: \(device.complianceState ?? "N/A")")
            Text("Operating System: \(device.operatingSystem ?? "N/A")")
            Text("User Principal Name: \(device.userPrincipalName ?? "N/A")")
            
            Spacer()
        }
        .padding()
        .navigationTitle("Device Details")
    }
}
