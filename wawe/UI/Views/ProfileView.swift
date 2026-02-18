//
//  ProfileView.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI
import PhotosUI
import Combine
#if os(macOS)
import AppKit
#endif

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    private let settingsRepo: SettingsRepository
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Bindings
    private var profileNameBinding: Binding<String> { Binding(get: { viewModel.profileName }, set: { viewModel.profileName = $0 }) }
    private var profileBioBinding: Binding<String> { Binding(get: { viewModel.profileBio }, set: { viewModel.profileBio = $0 }) }
    
    init(wordsRepo: WordsRepository, verbsRepo: IrregularVerbsRepository, questionsRepo: QuestionsRepository, settingsRepo: SettingsRepository) {
        self.settingsRepo = settingsRepo
        _viewModel = StateObject(wrappedValue: ProfileViewModel(wordsRepo: wordsRepo, verbsRepo: verbsRepo, questionsRepo: questionsRepo))
    }
    
    // MARK: - UI Helpers (kept in View for display logic)
    
    private func badgeDisplayName(_ name: String) -> String {
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
    
    private func badgeStyle(_ name: String) -> BadgeStyle {
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

    var body: some View {
        NavigationStack {
            profileContent
                .navigationTitle("")
#if os(iOS)
                .toolbarTitleDisplayMode(.inline)
#endif
                .toolbar {
#if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Menu {
                                Button {
                                    withAnimation { viewModel.editing.toggle() }
                                } label: {
                                    Label(viewModel.editing ? "Готово" : "Редактировать", systemImage: viewModel.editing ? "checkmark" : "pencil")
                                }
                                
                                Button {
                                    viewModel.showingSettingsSheet = true
                                } label: {
                                    Label("Настройки", systemImage: "gearshape")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .menuIndicator(.hidden)
                        }
                    }
#else
                    ToolbarItem(placement: .automatic) {
                        HStack {
                            Menu {
                                Button {
                                    withAnimation { viewModel.editing.toggle() }
                                } label: {
                                    Label(viewModel.editing ? "Готово" : "Редактировать", systemImage: viewModel.editing ? "checkmark" : "pencil")
                                }
                                
                                Button {
                                    viewModel.showingSettingsSheet = true
                                } label: {
                                    Label("Настройки", systemImage: "gearshape")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .menuIndicator(.hidden)
                        }
                    }
#endif
                }
        }
        .sheet(isPresented: $viewModel.showingSettingsSheet) {
            SettingsView(repo: settingsRepo)
        }
    }
    
    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                
                profileInfoView
                    .padding(.top, 16)
                    .padding(.horizontal)
                    
                if viewModel.editing {
                    badgeSelector
                }

                activityGraphView
                    .padding(.top, 16)
                    .padding(.horizontal)
                
                Spacer().frame(height: 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            if viewModel.showCopiedToast {
                Toast(text: "ID скопирован")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .photosPicker(isPresented: $viewModel.showAvatarPicker, selection: $viewModel.avatarPickerItem, matching: .images)
        .photosPicker(isPresented: $viewModel.showBgPicker, selection: $viewModel.bgPickerItem, matching: .images)
        .sheet(isPresented: $viewModel.showMediaSheet) {
            EditProfileMediaSheet(
                backgroundURL: Binding(get: { viewModel.profileBackgroundURL }, set: { viewModel.profileBackgroundURL = $0 }),
                avatarURL: Binding(get: { viewModel.profileAvatarURL }, set: { viewModel.profileAvatarURL = $0 })
            )
        }
        .onChange(of: viewModel.bgPickerItem) { _, newItem in
#if os(iOS)
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.profileBackgroundData = data
                    }
                }
            }
#endif
        }
        .onChange(of: viewModel.avatarPickerItem) { _, newItem in
#if os(iOS)
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.profileAvatarData = data
                    }
                }
            }
#endif
        }
    }
    
    private var profileInfoView: some View {
        VStack(spacing: 4) {
            if viewModel.editing {
                TextField("Имя", text: profileNameBinding)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            } else {
                Text(viewModel.profileName)
                    .font(.title2.bold())
            }
            
            if viewModel.editing {
                TextField("Bio", text: profileBioBinding)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            } else if !viewModel.profileBio.isEmpty {
                Text(viewModel.profileBio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    private var activityGraphView: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                // 53 недели. Вычислим размер ячейки
                let spacing: CGFloat = 2
                let size = max((width - 52 * spacing) / 53, 4)
                
                YearProgressGrid(counts: viewModel.progressCountsMap,
                                 startDate: viewModel.calendarStartDate,
                                 weeks: 53,
                                 daySize: size,
                                 spacing: spacing,
                                 color: (colorScheme == .dark ? .white : .black),
                                 sequentialCount: viewModel.progressDaysCount)
            }
            .frame(height: 80)
            
            HStack {
                Text("График активности")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.streakCount) дней стрик")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private var profileHeader: some View {
        Group {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    ZStack {
#if os(iOS)
                        if !viewModel.profileBackgroundData.isEmpty, let ui = UIImage(data: viewModel.profileBackgroundData) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else if let url = viewModel.resolvedImageURL(from: viewModel.profileBackgroundURL), !viewModel.profileBackgroundURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Color.secondary.opacity(0.2) }
                            }
                        } else { Color.secondary.opacity(0.2) }
#else
                        if let url = viewModel.resolvedImageURL(from: viewModel.profileBackgroundURL), !viewModel.profileBackgroundURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Color.secondary.opacity(0.2) }
                            }
                        } else { Color.secondary.opacity(0.2) }
#endif
                        
                        if viewModel.editing {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.showBgPicker = true }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .frame(height: 280)
            }
            .frame(height: 280)

            // Avatar centered on the bottom border
            ZStack(alignment: .top) {
                ZStack {
#if os(iOS)
                    if !viewModel.profileAvatarData.isEmpty, let ui = UIImage(data: viewModel.profileAvatarData) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if let url = viewModel.resolvedImageURL(from: viewModel.profileAvatarURL), !viewModel.profileAvatarURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.primary) }
                        }
                    } else { Circle().fill(Color.primary) }
#else
                    if let url = viewModel.resolvedImageURL(from: viewModel.profileAvatarURL), !viewModel.profileAvatarURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.primary) }
                        }
                    } else { Circle().fill(Color.primary) }
#endif
                    
                    if viewModel.editing {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Circle())
                            .onTapGesture { viewModel.showAvatarPicker = true }
                    }
                }
                .frame(width: 150, height: 150)
                .clipShape(Circle())
                .overlay(alignment: .top) {
                    if !viewModel.profileFeaturedBadge.isEmpty {
                        StreakBadgeBanner(title: badgeDisplayName(viewModel.profileFeaturedBadge), style: badgeStyle(viewModel.profileFeaturedBadge))
                            .scaleEffect(0.9)
                            .fixedSize()
                            .offset(y: -40)
                    }
                }
#if os(iOS)
                .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 4))
                .contextMenu {
                    Button { viewModel.showAvatarPicker = true } label: { Label("Изменить фото", systemImage: "person.crop.circle") }
                    Button { viewModel.showBgPicker = true } label: { Label("Изменить фон", systemImage: "photo") }
                    Button { viewModel.copyAccountId() } label: { Label("Копировать ID", systemImage: "doc.on.doc") }
                }
#else
                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 4))
                .contextMenu {
                    Button { viewModel.showMediaSheet = true } label: { Text("Изменить фото/фон") }
                    Button { viewModel.copyAccountId() } label: { Text("Копировать ID") }
                }
#endif
            }
            .offset(y: -75)
            .padding(.bottom, -75)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var badgeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Выберите значок")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableBadges, id: \.self) { badge in
                        let selected = (viewModel.profileFeaturedBadge == badge)
                        let style = badgeStyle(badge)
                        
                        HStack(spacing: 4) {
                            if !style.iconName.isEmpty {
                                Image(systemName: style.iconName).font(.caption2)
                            }
                            Text(badgeDisplayName(badge))
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            AnimatedBadgeBackground(style: style)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(selected ? Color.primary : style.borderColor, lineWidth: selected ? 2 : 1)
                                )
                        )
                        .scaleEffect(selected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.profileFeaturedBadge = (viewModel.profileFeaturedBadge == badge) ? "" : badge
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 4)
    }
}

#if os(iOS) || os(macOS)
struct Toast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 8)
    }
}
#endif

#if os(iOS) || os(macOS)
struct EditProfileMediaSheet: View {
    @Binding var backgroundURL: String
    @Binding var avatarURL: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ссылка на фон")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://…", text: $backgroundURL)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ссылка на аватар")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://…", text: $avatarURL)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Ссылки на медиа")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
#endif
