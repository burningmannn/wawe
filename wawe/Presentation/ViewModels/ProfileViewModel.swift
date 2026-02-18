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
    @AppStorage("profileBadges") var profileBadgesRaw: String = ""
    @AppStorage("profileAccountId") var profileAccountId: String = ""
    @AppStorage("profileFeaturedBadge") var profileFeaturedBadge: String = ""
    @AppStorage("profileBackgroundURL") var profileBackgroundURL: String = ""
    @AppStorage("profileAvatarURL") var profileAvatarURL: String = ""
    
    @Published var profileBackgroundData: Data = Data() {
        didSet {
            saveImageToDisk(data: profileBackgroundData, filename: "profile_bg_data")
        }
    }
    
    @Published var profileAvatarData: Data = Data() {
        didSet {
            saveImageToDisk(data: profileAvatarData, filename: "profile_avatar_data")
        }
    }
    
    // MARK: - Published Properties
    @Published var learnedWordsCount: Int = 0
    @Published var learnedVerbsCount: Int = 0
    @Published var learnedQuestionsCount: Int = 0
    @Published var streakCount: Int = 0
    
    @Published var editing = false
    @Published var showCopiedToast = false
    @Published var showMediaSheet = false
    @Published var showAvatarPicker = false
    @Published var showBgPicker = false
    @Published var avatarPickerItem: PhotosPickerItem?
    @Published var bgPickerItem: PhotosPickerItem?
    @Published var showingSettingsSheet = false
    
    // MARK: - Dependencies
    private let wordsRepo: WordsRepository
    private let verbsRepo: IrregularVerbsRepository
    private let questionsRepo: QuestionsRepository
    
    private var cancellables = Set<AnyCancellable>()
    
    init(wordsRepo: WordsRepository, verbsRepo: IrregularVerbsRepository, questionsRepo: QuestionsRepository) {
        self.wordsRepo = wordsRepo
        self.verbsRepo = verbsRepo
        self.questionsRepo = questionsRepo
        
        bind()
        ensureDefaults()
    }
    
    private func bind() {
        wordsRepo.wordsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLearnedCounts()
                self?.updateStreak()
                self?.ensureLearnedBadges()
                self?.ensureStreakBadges()
            }
            .store(in: &cancellables)
            
        verbsRepo.verbsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in 
                self?.updateLearnedCounts()
                self?.updateStreak()
                self?.ensureStreakBadges()
            }
            .store(in: &cancellables)
            
        questionsRepo.questionsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in 
                self?.updateLearnedCounts()
                self?.updateStreak()
                self?.ensureStreakBadges()
            }
            .store(in: &cancellables)
            
        updateLearnedCounts()
        updateStreak()
    }
    
    private func updateLearnedCounts() {
        learnedWordsCount = wordsRepo.learnedWordsCount
        learnedVerbsCount = verbsRepo.learnedVerbsCount
        learnedQuestionsCount = questionsRepo.learnedQuestionsCount
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
        let raw = UserDefaults.standard.string(forKey: "progressDays") ?? ""
        return Set(raw.split(separator: ",").map { String($0) })
    }
    
    var progressDaysCount: Int { progressDaysSet.count }
    
    var unlockedStreakBadges: [String] {
        var res: [String] = []
        if streakCount >= 7 { res.append("7DAY") }
        if streakCount >= 30 { res.append("30DAY") }
        if streakCount >= 60 { res.append("60DAY") }
        if streakCount >= 120 { res.append("120DAY") }
        if streakCount >= 210 { res.append("210DAY") }
        if streakCount >= 365 { res.append("1YR") }
        return res
    }
    
    var unlockedLearnedBadges: [String] {
        var res: [String] = []
        if learnedWordsCount >= 100 { res.append("LEARNED100") }
        if learnedWordsCount >= 500 { res.append("LEARNED500") }
        if learnedWordsCount >= 1000 { res.append("LEARNED1000") }
        return res
    }
    
    var progressCountsMap: [String:Int] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "progressDayCounts"),
           let decoded = try? JSONDecoder().decode([String:Int].self, from: data) {
            return decoded
        }
        return [:]
    }
    
    var calendarStartDate: Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        if let startOfWeek = cal.dateInterval(of: .weekOfYear, for: base)?.start {
            return startOfWeek
        }
        return base
    }
    
    var badges: [String] { profileBadgesRaw.split(separator: ",").map { String($0) } }
    
    func setBadges(_ b: [String]) { profileBadgesRaw = b.joined(separator: ",") }
    
    func toggleBadge(_ name: String) {
        var set = Set(badges)
        if set.contains(name) { set.remove(name) } else { set.insert(name) }
        setBadges(Array(set))
    }
    
    let availableBadges = ["BASE", "PRO", "VIP", "7DAY", "30DAY", "60DAY", "120DAY", "210DAY", "1YR", "LEARNED100", "LEARNED500", "LEARNED1000"]
    
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
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("profile_bg_data"),
           let data = try? Data(contentsOf: url) {
            profileBackgroundData = data
        }
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("profile_avatar_data"),
           let data = try? Data(contentsOf: url) {
            profileAvatarData = data
        }
    }
    
    private func ensureDefaults() {
        loadImagesFromDisk()
        ensureAccountId()
        ensureFeaturedBadge()
        ensureStreakBadges()
        ensureLearnedBadges()
    }
    
    private func ensureAccountId() {
        if profileAccountId.isEmpty {
            profileAccountId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
    }
    
    private func ensureFeaturedBadge() {
        if profileFeaturedBadge.isEmpty {
            profileFeaturedBadge = "BASE"
        }
    }
    
    private func ensureStreakBadges() {
        var set = Set(badges)
        for b in unlockedStreakBadges { set.insert(b) }
        setBadges(Array(set))
    }
    
    private func ensureLearnedBadges() {
        var set = Set(badges)
        for b in unlockedLearnedBadges { set.insert(b) }
        setBadges(Array(set))
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
        if let url = URL(string: raw) {
            if let ext = url.pathComponents.last?.lowercased(), ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg") || ext.hasSuffix(".png") || ext.hasSuffix(".gif") || ext.hasSuffix(".webp") {
                return url
            }
        }
        if var comps = URLComponents(string: raw), let host = comps.host, host.contains("google."), comps.path == "/url" {
            if let qi = comps.queryItems?.first(where: { $0.name == "url" || $0.name == "q" }), let v = qi.value, let direct = URL(string: v) {
                return direct
            }
        }
        return URL(string: raw)
    }
    
    func badgeDisplayName(_ name: String) -> String {
        switch name {
        case "BASE": return "BASE"
        case "PRO": return "PRO"
        case "VIP": return "VIP"
        case "7DAY": return "7 DAY"
        case "30DAY": return "30 DAY"
        case "60DAY": return "60 DAY"
        case "120DAY": return "120 DAY"
        case "210DAY": return "210 DAY"
        case "1YR": return "1 YR"
        case "LEARNED100": return "100 Words"
        case "LEARNED500": return "500 Words"
        case "LEARNED1000": return "1000 Words"
        default: return name
        }
    }
    
    func badgeStyle(_ name: String) -> BadgeStyle {
        switch name {
        case "BASE": return .base
        case "PRO": return .pro
        case "VIP": return .vip
        case "7DAY": return .streak(days: 7)
        case "30DAY": return .streak(days: 30)
        case "60DAY": return .streak(days: 60)
        case "120DAY": return .streak(days: 120)
        case "210DAY": return .streak(days: 210)
        case "1YR": return .streak(days: 365)
        case "LEARNED100": return .learned(count: 100)
        case "LEARNED500": return .learned(count: 500)
        case "LEARNED1000": return .learned(count: 1000)
        default: return .base
        }
    }
}
