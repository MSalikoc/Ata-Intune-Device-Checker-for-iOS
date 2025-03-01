import Foundation

class AuthenticationManager: ObservableObject {
    @Published var deviceCode: String?
    @Published var verificationUrl: String?
    @Published var userCode: String?
    @Published var accessToken: String? {
        didSet {
            DispatchQueue.main.async {
                self.isAuthenticated = (self.accessToken != nil)
            }
        }
    }
    @Published var isAuthenticated = false
    @Published var devices: [DeviceModel] = []
    @Published var filteredDevicesList: [DeviceModel] = []
    
    // MARK: - Tenant & ClientID Bilgileri Saklamak İçin
    private let tenantIDKey = "SavedTenantID"
    private let clientIDKey = "SavedClientID"

    /// Uygulama ilk açıldığında UserDefaults'tan kayıtlı değerleri yükleme
    init() {
        let (savedTenant, savedClient) = getSavedCredentials()
        if let tenant = savedTenant, let client = savedClient {
            print("✅ Daha önce kayıtlı Tenant ID: \(tenant) | Client ID: \(client)")
        } else {
            print("❌ Kayıtlı Tenant ID veya Client ID bulunamadı.")
        }
    }
    
    /// Tenant ID ve Client ID'yi UserDefaults'a kaydeden fonksiyon
    func saveCredentials(tenantID: String, clientID: String) {
        UserDefaults.standard.set(tenantID, forKey: tenantIDKey)
        UserDefaults.standard.set(clientID, forKey: clientIDKey)
        UserDefaults.standard.synchronize() // anında yaz
        print("✅ Tenant ID ve Client ID kaydedildi: \(tenantID), \(clientID)")
    }

    /// Kayıtlı Tenant ID ve Client ID'yi geri getiren fonksiyon
    func getSavedCredentials() -> (tenantID: String?, clientID: String?) {
        let tenantID = UserDefaults.standard.string(forKey: tenantIDKey)
        let clientID = UserDefaults.standard.string(forKey: clientIDKey)
        return (tenantID, clientID)
    }

    // MARK: - Device Code Flow Başlatma
    // Bu fonksiyon çağrıldığında girilen tenantID ve clientID hafızaya kaydedilir.
    func requestDeviceCode(clientID: String, tenantID: String) {
        // İlk etapta girilen Tenant/Client bilgilerini sakla
        saveCredentials(tenantID: tenantID, clientID: clientID)

        print("✅ Requesting New Device Code...")
        let url = URL(string: "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/devicecode")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientID)&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Request Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("❌ No data received from API")
                return
            }

            do {
                let jsonResponse = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
                DispatchQueue.main.async {
                    self.deviceCode = jsonResponse.device_code
                    self.verificationUrl = jsonResponse.verification_uri
                    self.userCode = jsonResponse.user_code
                }
                print("✅ New Verification URL: \(jsonResponse.verification_uri)")
                print("✅ New User Code: \(jsonResponse.user_code)")

                // Yeni flow başlatıldığı için token sıfırlanıyor
                self.accessToken = nil

                // Device Code Flow ile token alana kadar polling
                self.pollForToken(clientID: clientID, tenantID: tenantID, deviceCode: jsonResponse.device_code)
            } catch {
                print("❌ JSON Decode Error: \(error)")
            }
        }.resume()
    }

    // MARK: - Token Polling
    private func pollForToken(clientID: String, tenantID: String, deviceCode: String) {
        let tokenURL = URL(string: "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientID)&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=\(deviceCode)"
        request.httpBody = body.data(using: .utf8)

        func attemptFetchToken() {
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Token Request Error: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    print("❌ No data received in token response")
                    return
                }

                // authorization_pending vb. hata cevapları
                if let tokenError = try? JSONDecoder().decode(TokenErrorResponse.self, from: data),
                   let errorCode = tokenError.error {
                    
                    // Eğer authorization_pending ise 5 sn sonra tekrar dene
                    if errorCode == "authorization_pending" {
                        print("⏳ Authorization still pending... will retry in 5s.")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                            attemptFetchToken()
                        }
                    } else {
                        print("❌ Token request ended with error: \(errorCode)")
                    }
                    return
                }

                // access_token parse
                do {
                    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                    if let accessToken = tokenResponse.access_token {
                        DispatchQueue.main.async {
                            self.accessToken = accessToken
                            print("✅ Access Token Successfully Stored!")
                            // Token alındıktan sonra cihazları çek
                            self.fetchDevices()
                        }
                    } else {
                        print("❌ ERROR: Token response does not contain access_token!")
                    }
                } catch {
                    print("❌ JSON Decode Error in pollForToken: \(error)")
                }
            }.resume()
        }

        // İlk deneme
        attemptFetchToken()
    }

    // MARK: - Cihazları Çekme
    func fetchDevices() {
        guard let token = accessToken, !token.isEmpty else {
            print("❌ ERROR: No valid access token available!")
            return
        }

        let url = URL(string: "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ API Request Error: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("❌ No data received from API")
                return
            }

            do {
                let jsonResponse = try JSONDecoder().decode(DeviceListResponse.self, from: data)
                DispatchQueue.main.async {
                    self.devices = jsonResponse.value
                    self.filteredDevicesList = jsonResponse.value
                }
                print("✅ Devices Fetched Successfully!")
            } catch {
                DispatchQueue.main.async {
                    print("❌ JSON Decode Error: \(error)")
                }
            }
        }.resume()
    }

    // MARK: - Sync Device
    func syncDevice(deviceID: String, completion: @escaping (Bool) -> Void) {
        guard let token = accessToken else {
            print("❌ No valid access token for sync!")
            completion(false)
            return
        }
        let urlString = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/\(deviceID)/syncDevice"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Sync Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Sync \(deviceID) successful!")
                completion(true)
            } else {
                print("❌ Sync \(deviceID) failed!")
                completion(false)
            }
        }.resume()
    }

    // MARK: - Wipe Device
    func wipeDevice(deviceID: String, completion: @escaping (Bool) -> Void) {
        guard let token = accessToken else {
            print("❌ No valid access token for wipe!")
            completion(false)
            return
        }
        let urlString = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/\(deviceID)/wipe"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Örnek Body (isteğe bağlı ek parametreler)
        // let body = ["keepEnrollmentData": false, "keepUserData": false]
        // request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Wipe Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Wipe \(deviceID) successful!")
                completion(true)
            } else {
                print("❌ Wipe \(deviceID) failed!")
                completion(false)
            }
        }.resume()
    }

    // MARK: - Retire Device
    func retireDevice(deviceID: String, completion: @escaping (Bool) -> Void) {
        guard let token = accessToken else {
            print("❌ No valid access token for retire!")
            completion(false)
            return
        }
        let urlString = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/\(deviceID)/retire"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Retire Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Retire \(deviceID) successful!")
                completion(true)
            } else {
                print("❌ Retire \(deviceID) failed!")
                completion(false)
            }
        }.resume()
    }

    // MARK: - Delete Device
    func deleteDevice(deviceID: String, completion: @escaping (Bool) -> Void) {
        guard let token = accessToken else {
            print("❌ No valid access token for delete!")
            completion(false)
            return
        }
        let urlString = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/\(deviceID)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Delete Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Delete \(deviceID) successful!")
                completion(true)
            } else {
                print("❌ Delete \(deviceID) failed!")
                completion(false)
            }
        }.resume()
    }
}

// MARK: - Model Tanımları

struct DeviceCodeResponse: Codable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
}

struct TokenResponse: Codable {
    let access_token: String?
}

// Token isteğinde dönebilen hata durumlarını yakalamak için
struct TokenErrorResponse: Codable {
    let error: String?
    let error_description: String?
}
