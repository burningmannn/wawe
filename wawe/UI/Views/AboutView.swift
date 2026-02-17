import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Приложение"
    }
    var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Приложение") {
                    HStack {
                        Text("Название")
                        Spacer()
                        Text(appName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Пользовательское соглашение") {
                    Text("Используя приложение, вы соглашаетесь с правилами использования и обработкой данных. Полная версия соглашения и политика конфиденциальности доступны по запросу.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Section("Контакты") {
                    Button {
                        openMail(to: "support@example.com")
                    } label: {
                        Label("Написать в поддержку", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
    
    private func openMail(to address: String) {
        guard let url = URL(string: "mailto:\(address)") else { return }
#if os(iOS)
        UIApplication.shared.open(url)
#else
        NSWorkspace.shared.open(url)
#endif
    }
}
