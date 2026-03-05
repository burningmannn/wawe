import SwiftUI
import Combine
import PhotosUI
#if os(macOS)
import AppKit
#endif

final class ProfileViewModel: ObservableObject {
    // MARK: - AppStorage Properties
    @AppStorage("profileName") var profileName: String = "Пользователь"
    @AppStorage("profileBio") var profileBio: String = ""
    @AppStorage("profileAccountId") var profileAccountId: String = ""
    @AppStorage("profileAvatarURL") var profileAvatarURL: String = ""

    @Published var profileAvatarData: Data = Data() {
        didSet {
            saveImageToDisk(data: profileAvatarData, filename: "profile_avatar_data")
        }
    }

    // MARK: - Published Properties
    @Published var learnedWordsCount: Int = 0
    @Published var learnedVerbsCount: Int = 0
    @Published var totalWordsCount: Int = 0
    @Published var totalVerbsCount: Int = 0
    @Published var streakCount: Int = 0

    @Published var editing = false
    @Published var showCopiedToast = false
    @Published var showMediaSheet = false
    @Published var showAvatarPicker = false
    @Published var avatarPickerItem: PhotosPickerItem?
    @Published var showingSettingsSheet = false
    @Published var bookReadToday: Bool = false

    // MARK: - Dependencies
    private let wordsRepo: WordsRepository
    private let verbsRepo: IrregularVerbsRepository
    private var cancellables = Set<AnyCancellable>()

    init(wordsRepo: WordsRepository, verbsRepo: IrregularVerbsRepository) {
        self.wordsRepo = wordsRepo
        self.verbsRepo = verbsRepo
        bind()
        ensureDefaults()
    }

    private func bind() {
        wordsRepo.wordsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] words in
                self?.totalWordsCount = words.count
                self?.updateLearnedCounts()
                self?.updateStreak()
            }
            .store(in: &cancellables)

        verbsRepo.verbsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] verbs in
                self?.totalVerbsCount = verbs.count
                self?.updateLearnedCounts()
                self?.updateStreak()
            }
            .store(in: &cancellables)

        updateLearnedCounts()
        updateStreak()
    }

    private func updateLearnedCounts() {
        learnedWordsCount = wordsRepo.learnedWordsCount
        learnedVerbsCount = verbsRepo.learnedVerbsCount
    }

    private func updateStreak() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var count = 0
        var day = Date()
        while progressDaysSet.contains(formatter.string(from: day)) {
            count += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        self.streakCount = count
    }

    // MARK: - Logic

    var learnedWordsTotal: Int { learnedWordsCount }

    var progressDaysSet: Set<String> {
        daysSet(forKey: "progressDays")
    }

    var progressDaysCount: Int { progressDaysSet.count }

    /// Returns [dateString: categoryCount] where value is 1-4
    /// (words + verbs + questions + book = 25% each → 100% at 4)
    var progressCategoryCountsMap: [String: Int] {
        let wordDays = daysSet(forKey: "progressDays_word")
        let verbDays = daysSet(forKey: "progressDays_verb")
        let bookDays = daysSet(forKey: "bookReadDays")
        let allDays = wordDays.union(verbDays).union(bookDays)
        var map: [String: Int] = [:]
        for day in allDays {
            var count = 0
            if wordDays.contains(day) { count += 1 }
            if verbDays.contains(day) { count += 1 }
            if bookDays.contains(day) { count += 1 }
            map[day] = count
        }
        return map
    }

    private func daysSet(forKey key: String) -> Set<String> {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        return Set(raw.split(separator: ",").map { String($0) })
    }

    var calendarStartDate: Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        if let startOfWeek = cal.dateInterval(of: .weekOfYear, for: base)?.start {
            return startOfWeek
        }
        return base
    }

    // MARK: - Helpers

    private func saveImageToDisk(data: Data, filename: String) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename) else { return }
        do {
            if data.isEmpty {
                try? FileManager.default.removeItem(at: url)
            } else {
                try data.write(to: url)
            }
        } catch {
            print("Failed to save image \(filename): \(error)")
        }
    }

    private func loadImagesFromDisk() {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("profile_avatar_data"),
           let data = try? Data(contentsOf: url) {
            profileAvatarData = data
        }
    }

    private func ensureDefaults() {
        loadImagesFromDisk()
        ensureAccountId()
        bookReadToday = daysSet(forKey: "bookReadDays").contains(todayKey())
    }

    func toggleBookRead() {
        let key = todayKey()
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: "bookReadDays") ?? ""
        var set = Set(raw.split(separator: ",").map { String($0) })
        if set.contains(key) {
            set.remove(key)
            bookReadToday = false
        } else {
            set.insert(key)
            bookReadToday = true
            // Book counts as activity — add to combined streak key
            let combinedRaw = defaults.string(forKey: "progressDays") ?? ""
            var combinedSet = Set(combinedRaw.split(separator: ",").map { String($0) })
            combinedSet.insert(key)
            defaults.set(Array(combinedSet).sorted().joined(separator: ","), forKey: "progressDays")
        }
        defaults.set(Array(set).sorted().joined(separator: ","), forKey: "bookReadDays")
        updateStreak()
    }

    private func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale   = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func ensureAccountId() {
        if profileAccountId.isEmpty {
            profileAccountId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
    }

    func copyAccountId() {
        #if os(iOS)
        UIPasteboard.general.string = profileAccountId
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(profileAccountId, forType: .string)
        #endif
        showCopiedToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showCopiedToast = false
        }
    }

    func resolvedImageURL(from raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }

        // Unwrap Google redirect URLs
        if let comps = URLComponents(string: raw),
           let host = comps.host, host.contains("google."),
           comps.path == "/url",
           let qi = comps.queryItems?.first(where: { $0.name == "url" || $0.name == "q" }),
           let v = qi.value {
            return v.normalizedURL
        }

        // Use the shared normalizedURL logic (adds https://, validates host, etc.)
        return raw.normalizedURL
    }
}
