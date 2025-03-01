import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var clientID: String = ""
    @State private var tenantID: String = ""
    @State private var isAuthenticated = false  // Tam ekran geçişi için state
    @State private var copied = false // Kopyalama bildirimi için state

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .renderingMode(.original) // Boyamaya kapalı, orijinal renkler
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .shadow(radius: 10)
                
                Text("ATA Intune Device Checker for iOS")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Manage your devices efficiently")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Client ID")
                        .foregroundColor(.white)
                        .font(.headline)

                    TextField("Enter your Client ID", text: $clientID)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Text("Tenant ID")
                        .foregroundColor(.white)
                        .font(.headline)

                    TextField("Enter your Tenant ID", text: $tenantID)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                
                Button(action: {
                    authManager.requestDeviceCode(clientID: clientID, tenantID: tenantID)
                }) {
                    Text("Authenticate")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .padding(.horizontal)
                .disabled(clientID.isEmpty || tenantID.isEmpty)

                if let userCode = authManager.userCode {
                    VStack(spacing: 10) {
                        Text("Enter this code in your browser:")
                            .foregroundColor(.white)
                            .font(.headline)

                        HStack {
                            Text(userCode)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .shadow(radius: 5)

                            // 📋 **iOS ve macOS için Kopyalama Butonu**
                            Button(action: {
                                copyToClipboard(userCode)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copied = false
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }

                if let url = authManager.verificationUrl, let validURL = URL(string: url) {
                    VStack(spacing: 10) {
                        Text("Go to:")
                            .foregroundColor(.white)
                            .font(.headline)

                        Link("Click here to authenticate", destination: validURL)
                            .foregroundColor(.blue)
                    }
                    .padding()
                }

                Spacer()
                
                VStack(spacing: 10) {
                    Text("Why Use ATA Intune Device Checker?")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    InfoRow(icon: "checkmark.circle.fill", color: .green, text: "Quickly sync and manage devices")
                    InfoRow(icon: "lock.fill", color: .blue, text: "Secure authentication & access")
                    InfoRow(icon: "server.rack", color: .purple, text: "Monitor all Intune-managed devices")
                    InfoRow(icon: "doc.text.fill", color: .yellow, text: "Generate compliance reports easily")
                }
                .padding(.horizontal, 20)

                Text("© 2025 Ali Koc. All rights reserved.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
            }
            .padding()
        }
        // ✅ iOS ve macOS için geçiş uyumu sağlandı
        #if os(iOS)
        .fullScreenCover(isPresented: $isAuthenticated) {
            DashboardView(authManager: authManager) // <-- Aynı authManager
        }
        #else
        .sheet(isPresented: $isAuthenticated) {
            DashboardView()
        }
        #endif
        .onReceive(authManager.$isAuthenticated) { authenticated in
            if authenticated {
                withAnimation {
                    isAuthenticated = true
                }
            }
        }
    }
}

// ✅ **iOS ve macOS için Kopyalama Fonksiyonu**
func copyToClipboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    #endif
}

// ✅ **Eksik Bileşen: InfoRow**
struct InfoRow: View {
    var icon: String
    var color: Color
    var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(.white)
                .font(.body)
        }
    }
}
