//
//  ShareSheet.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet для экспорта
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: View {
    let items: [Any]
    
    var body: some View {
        Text("Экспорт завершен")
            .onAppear {
                // На macOS можно использовать NSSharingService или просто показать уведомление
                if let url = items.first as? URL {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }
    }
}
#endif
