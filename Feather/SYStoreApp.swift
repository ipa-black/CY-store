//
//  SYStoreApp.swift
//  SY STORE
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog
import CoreData
import FirebaseCore
import FirebaseDatabase

@main
struct SYStoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let heartbeat = HeartbeatManager.shared
    @StateObject var downloadManager = DownloadManager.shared
    let storage = Storage.shared
    @StateObject var authManager = AttackAuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isChecking {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 15) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#00FF9D"))).scaleEffect(1.5)
                        Text("جاري التحقق من التراخيص...").foregroundColor(Color(hex: "#00FF9D")).font(.system(size: 14, weight: .medium))
                    }
                } else if authManager.isAuthorized {
                    VStack {
                        DownloadHeaderView(downloadManager: downloadManager).transition(.move(edge: .top).combined(with: .opacity))
                        VariedTabbarView().environment(\.managedObjectContext, storage.context).onOpenURL(perform: _handleURL).transition(.move(edge: .top).combined(with: .opacity))
                    }
                    .animation(.smooth, value: downloadManager.manualDownloads.description)
                    .onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
                        DispatchQueue.main.async { UIAlertController.showAlertWithOk(title: "خطأ", message: "ملف الربط غير متوافق.") }
                    }
                    .onAppear {
                        if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "Feather.userInterfaceStyle")) { UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style }
                        let storedHex = UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#00FF9D"
                        UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: storedHex))
                    }
                } else {
                    AttackAuthView()
                }
            }
        }
    }
    
    private func _handleURL(_ url: URL) {
        if url.scheme == "systore" {
            if url.host == "import-certificate" {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = components.queryItems else { return }
                func queryValue(_ name: String) -> String? { queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding }
                guard let p12Base64 = queryValue("p12"), let provisionBase64 = queryValue("mobileprovision"), let passwordBase64 = queryValue("password"), let passwordData = Data(base64Encoded: passwordBase64), let password = String(data: passwordData, encoding: .utf8) else { return }
                let generator = UINotificationFeedbackGenerator(); generator.prepare()
                guard let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"), let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"), FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL) else { generator.notificationOccurred(.error); return }
                FR.handleCertificateFiles(p12URL: p12URL, provisionURL: provisionURL, p12Password: password) { error in
                    if let error = error { UIAlertController.showAlertWithOk(title: "خطأ", message: error.localizedDescription) } else { generator.notificationOccurred(.success) }
                }
                return
            }
            if let fullPath = url.validatedScheme(after: "/source/") { FR.handleSource(fullPath) { } }
            if let fullPath = url.validatedScheme(after: "/install/"), let downloadURL = URL(string: fullPath) { _ = DownloadManager.shared.startDownload(from: downloadURL) }
        } else {
            if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
                if FileManager.default.isFileFromFileProvider(at: url) { guard url.startAccessingSecurityScopedResource() else { return }; FR.handlePackageFile(url) { _ in } } else { FR.handlePackageFile(url) { _ in } }
                return
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let options = FirebaseOptions(googleAppID: "1:682698299473:ios:1b1b7a4620342c7b948070", gcmSenderID: "682698299473")
        options.apiKey = "AIzaSyAKSpEbaNV4OefOyfxDJKtYzKMtyT30_2I"
        options.projectID = "attack-store"
        options.databaseURL = "https://attack-store-default-rtdb.firebaseio.com"
        FirebaseApp.configure(options: options)
        _createPipeline(); _createDocumentsDirectories(); ResetView.clearWorkCache(); _addDefaultCertificates(); return true
    }
    
    static func performDirectAutoSign(downloadId: String) {
        let context = Storage.shared.context
        let appRequest = Imported.fetchRequest()
        appRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
        appRequest.fetchLimit = 1
        guard let latestApp = try? context.fetch(appRequest).first else { DispatchQueue.main.async { DownloadManager.shared.removeDownload(id: downloadId) }; return }
        let certRequest = CertificatePair.fetchRequest()
        certRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
        guard let certs = try? context.fetch(certRequest), !certs.isEmpty else { DispatchQueue.main.async { DownloadManager.shared.removeDownload(id: downloadId); UIAlertController.showAlertWithOk(title: "تنبيه", message: "لا توجد شهادة لتوقيعه تلقائياً.") }; return }
        let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        let cert = certs.indices.contains(selectedIndex) ? certs[selectedIndex] : certs.first!
        let options = OptionsManager.shared.options
        FR.signPackageFile(latestApp, using: options, icon: nil, certificate: cert) { error in
            DispatchQueue.main.async {
                DownloadManager.shared.removeDownload(id: downloadId)
                if let error = error { UIAlertController.showAlertWithOk(title: "فشل التوقيع", message: error.localizedDescription) } else {
                    if options.post_deleteAppAfterSigned { Storage.shared.deleteApp(for: latestApp) }
                    NotificationCenter.default.post(name: Notification.Name("SYStore.installApp"), object: nil)
                }
            }
        }
    }
    
    private func _createPipeline() {
        DataLoader.sharedUrlCache.diskCapacity = 0
        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = { let config = URLSessionConfiguration.default; config.urlCache = nil; return DataLoader(configuration: config) }()
            let dataCache = try? DataCache(name: "com.systore.datacache"); let imageCache = Nuke.ImageCache()
            dataCache?.sizeLimit = 500 * 1024 * 1024; imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache; $0.imageCache = imageCache; $0.dataLoader = dataLoader; $0.dataCachePolicy = .automatic; $0.isStoringPreviewsInMemoryCache = false
        }
        ImagePipeline.shared = pipeline
    }
    private func _createDocumentsDirectories() {
        let fileManager = FileManager.default
        let directories: [URL] = [fileManager.archives, fileManager.certificates, fileManager.signed, fileManager.unsigned]
        for url in directories { try? fileManager.createDirectoryIfNeeded(at: url) }
    }
    private func _addDefaultCertificates() {
        guard UserDefaults.standard.bool(forKey: "systore.didImportDefaultCertificates") == false, let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil) else { return }
        do {
            let folderContents = try FileManager.default.contentsOfDirectory(at: signingAssetsURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for folderURL in folderContents {
                guard folderURL.hasDirectoryPath else { continue }
                let certName = folderURL.lastPathComponent
                let p12Url = folderURL.appendingPathComponent("cert.p12"); let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision"); let passwordUrl = folderURL.appendingPathComponent("cert.txt")
                guard FileManager.default.fileExists(atPath: p12Url.path), FileManager.default.fileExists(atPath: provisionUrl.path), FileManager.default.fileExists(atPath: passwordUrl.path) else { continue }
                let password = try String(contentsOf: passwordUrl, encoding: .utf8)
                FR.handleCertificateFiles(p12URL: p12Url, provisionURL: provisionUrl, p12Password: password, certificateName: certName, isDefault: true) { _ in }
            }
            UserDefaults.standard.set(true, forKey: "systore.didImportDefaultCertificates")
        } catch { Logger.misc.error("Failed to list signing-assets: \(error)") }
    }
}

class AttackAuthManager: ObservableObject {
    static let shared = AttackAuthManager()
    @Published var isAuthorized: Bool = false
    @Published var isChecking: Bool = true
    @Published var errorMessage: String? = nil
    private var dbRef = Database.database().reference()
    private var codeListenerHandle: DatabaseHandle?
    
    var deviceID: String {
        if let savedID = UserDefaults.standard.string(forKey: "attack_device_id") { return savedID } else {
            let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "attack_device_id"); return newID
        }
    }
    
    init() { checkSavedCode() }
    
    func checkSavedCode() {
        guard let savedCode = UserDefaults.standard.string(forKey: "attack_vip_code") else { DispatchQueue.main.async { self.isChecking = false; self.isAuthorized = false }; return }
        verifyAndListen(code: savedCode)
    }
    
    func verifyAndListen(code: String) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let handle = codeListenerHandle { dbRef.child("codes").child(cleanCode).removeObserver(withHandle: handle) }
        
        self.isChecking = true
        codeListenerHandle = dbRef.child("codes").child(cleanCode).observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else { self.kickUserOut(message: "تم إلغاء اشتراكك أو الكود غير صالح ⛔"); return }
            
            let status = value["status"] as? String ?? "unknown"
            let boundDevice = value["deviceId"] as? String
            
            DispatchQueue.main.async {
                if status == "frozen" { self.kickUserOut(message: "تم تجميد اشتراكك من الإدارة ❄️") } else if status == "active" {
                    if boundDevice == nil || boundDevice == "none" { self.bindDevice(code: cleanCode) } else if boundDevice == self.deviceID {
                        UserDefaults.standard.set(cleanCode, forKey: "attack_vip_code"); self.isAuthorized = true; self.errorMessage = nil
                    } else { self.kickUserOut(message: "هذا الكود مستخدم في جهاز آخر 📱") }
                }
                self.isChecking = false
            }
        }) { _ in DispatchQueue.main.async { self.errorMessage = "تعذر الاتصال بالخادم المركزي."; self.isChecking = false } }
    }
    
    private func bindDevice(code: String) {
        dbRef.child("codes").child(code).updateChildValues(["status": "active", "deviceId": self.deviceID]) { error, _ in
            DispatchQueue.main.async {
                if error == nil { UserDefaults.standard.set(code, forKey: "attack_vip_code"); self.isAuthorized = true; self.errorMessage = nil } else { self.errorMessage = "فشل التفعيل المباشر، أعد المحاولة." }
                self.isChecking = false
            }
        }
    }
    
    private func kickUserOut(message: String) {
        UserDefaults.standard.removeObject(forKey: "attack_vip_code"); self.isAuthorized = false; self.errorMessage = message
    }
}

struct AttackAuthView: View {
    @State private var codeInput: String = ""
    @State private var isLoading: Bool = false
    @ObservedObject var authManager = AttackAuthManager.shared
    
    var body: some View {
        ZStack {
            RadialGradient(gradient: Gradient(colors: [Color(hex: "#052e16"), Color.black]), center: .bottom, startRadius: 0, endRadius: 600).ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                VStack(spacing: 15) {
                    Image(systemName: "shield.checkered").font(.system(size: 80, weight: .light)).foregroundColor(Color(hex: "#00FF9D")).shadow(color: Color(hex: "#00FF9D").opacity(0.5), radius: 10)
                    Text("الرئيسية").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.white).tracking(2)
                    Text("بوابة الوصول الآمن لتطبيقات الـ VIP").font(.subheadline).foregroundColor(.gray)
                }
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "key.fill").foregroundColor(Color(hex: "#00FF9D"))
                        TextField("أدخل كود التفعيل هنا...", text: $codeInput).foregroundColor(.white).autocapitalization(.allCharacters).disableAutocorrection(true)
                    }.padding().background(Color.black.opacity(0.4)).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: "#00FF9D").opacity(0.3), lineWidth: 1)).padding(.horizontal, 30)
                    if let error = authManager.errorMessage { Text(error).font(.caption).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal) }
                }
                Button(action: {
                    guard !codeInput.isEmpty else { return }
                    isLoading = true; authManager.verifyAndListen(code: codeInput)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isLoading = false }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(Color(hex: "#00FF9D")).shadow(color: Color(hex: "#00FF9D").opacity(0.4), radius: 10, y: 5)
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)) } else { Text("تفعيل وتأمين المتجر").font(.headline).bold().foregroundColor(.black) }
                    }.frame(height: 55).padding(.horizontal, 30)
                }.disabled(codeInput.isEmpty || isLoading)
                Spacer()
                Button(action: { if let url = URL(string: "https://t.me/ipa_black") { UIApplication.shared.open(url) } }) { Text("لا تملك رخصة تفعيل؟ تواصل معنا").font(.footnote).foregroundColor(.gray).underline() }.padding(.bottom, 20)
            }
        }.environment(\.colorScheme, .dark)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted); var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}
