import SwiftUI
import Combine
import Foundation
import ImageIO
 
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif
 
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    @Published var isLoading = false
    @Published var error: Error?
     
    private var cancellable: AnyCancellable?
    private let fileManager = FileManager.default
    
    private func cacheDir() -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ImageCache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func safeName(for url: URL) -> String {
        var s = url.absoluteString
        let invalid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted
        s = s.components(separatedBy: invalid).joined()
        if s.isEmpty {
            s = UUID().uuidString
        }
        return s + ".img"
    }
    
    private func cachedFileURL(for url: URL) -> URL {
        cacheDir().appendingPathComponent(safeName(for: url))
    }
     
    func load(url: URL) {
        isLoading = true
        error = nil
        
        // Try disk cache first
        let cached = cachedFileURL(for: url)
        if fileManager.fileExists(atPath: cached.path) {
            if let data = try? Data(contentsOf: cached),
               let img = decodeImageData(data) {
                publish(image: img)
                return
            } else {
                // remove broken cache
                try? fileManager.removeItem(at: cached)
            }
        }
         
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "image/*,*/*;q=0.8"
        ]
        let session = URLSession(configuration: config)
         
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
         
        cancellable = session.dataTaskPublisher(for: request)
            .tryMap { (data, response) -> Data in data }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] data in
                guard let self else { return }
                if let img = self.decodeImageData(data) {
                    // Save to disk cache
                    let cached = self.cachedFileURL(for: url)
                    try? data.write(to: cached, options: .atomic)
                    self.publish(image: img)
                } else {
                    self.error = URLError(.cannotDecodeContentData)
                }
            })
    }
    
    private func publish(image: PlatformImage) {
        #if os(macOS)
        self.image = Image(nsImage: image)
        #else
        self.image = Image(uiImage: image)
        #endif
        self.isLoading = false
    }
    
    private func decodeImageData(_ data: Data) -> PlatformImage? {
        if let direct = PlatformImage(data: data) {
            return direct
        }
        let cfData = data as CFData
        guard let src = CGImageSourceCreateWithData(cfData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return nil
        }
        #if os(macOS)
        return PlatformImage(cgImage: cgImage, size: .zero)
        #else
        return PlatformImage(cgImage: cgImage)
        #endif
    }
     
    func cancel() {
        cancellable?.cancel()
    }
}
 
struct RemoteImage: View {
    let url: URL
    @StateObject private var loader = ImageLoader()
     
    var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .scaledToFill()
            } else if loader.isLoading {
                SkeletonView()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
            } else {
                ZStack {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        if let error = loader.error {
                            Text(error.localizedDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0/9.0, contentMode: .fit)
            }
        }
        .onAppear {
            if loader.image == nil {
                loader.load(url: url)
            }
        }
        .onDisappear {
            loader.cancel()
        }
        .onChange(of: url) { _, newUrl in
            loader.load(url: newUrl)
        }
    }
}
