import Foundation

struct DeviceModel: Identifiable, Codable {  // 📌 Device yerine DeviceModel kullanıyoruz!
    let id: String
    let deviceName: String?
    let userPrincipalName: String?
    let operatingSystem: String?
    let manufacturer: String?
    let complianceState: String?
}

struct DeviceListResponse: Codable {
    let value: [DeviceModel]  // 📌 Çakışmayı önlemek için güncellendi!
}
