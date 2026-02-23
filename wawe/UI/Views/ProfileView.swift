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
                            Button {
                                viewModel.showingSettingsSheet = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            Button {
                                withAnimation { viewModel.editing.toggle() }
                            } label: {
                                Image(systemName: viewModel.editing ? "checkmark" : "pencil")
                            }
                        }
                    }
#else
                    ToolbarItemGroup(placement: .automatic) {
                        Button {
                            viewModel.showingSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        Button {
                            withAnimation { viewModel.editing.toggle() }
                        } label: {
                            Image(systemName: viewModel.editing ? "checkmark" : "pencil")
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
                    .padding(.top, 24)

                profileInfoView
                    .padding(.top, 16)
                    .padding(.horizontal)

                streakSection
                    .padding(.top, 32)

                Spacer().frame(height: 48)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showCopiedToast {
                Toast(text: "ID скопирован")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .photosPicker(isPresented: $viewModel.showAvatarPicker, selection: $viewModel.avatarPickerItem, matching: .images)
        .sheet(isPresented: $viewModel.showMediaSheet) {
            EditProfileMediaSheet(
                avatarURL: Binding(get: { viewModel.profileAvatarURL }, set: { viewModel.profileAvatarURL = $0 })
            )
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

    private var streakSection: some View {
        let count = viewModel.streakCount
        let progress = count == 0 ? 0.0 : min(Double(count), 7.0) / 7.0
        let isActive = count > 0

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isActive ? Color.primary : Color.clear,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    Text("дней")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            Text("стрик")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var profileHeader: some View {
        ZStack {
#if os(iOS)
            if !viewModel.profileAvatarData.isEmpty, let ui = UIImage(data: viewModel.profileAvatarData) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let url = viewModel.resolvedImageURL(from: viewModel.profileAvatarURL), !viewModel.profileAvatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.gray) }
                }
            } else { Circle().fill(Color.gray) }
#else
            if let url = viewModel.resolvedImageURL(from: viewModel.profileAvatarURL), !viewModel.profileAvatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Circle().fill(Color.gray) }
                }
            } else { Circle().fill(Color.gray) }
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
#if os(iOS)
        .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 4))
        .contextMenu {
            Button { viewModel.showAvatarPicker = true } label: { Label("Изменить фото", systemImage: "person.crop.circle") }
            Button { viewModel.copyAccountId() } label: { Label("Копировать ID", systemImage: "doc.on.doc") }
        }
#else
        .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 4))
        .contextMenu {
            Button { viewModel.showMediaSheet = true } label: { Text("Изменить фото") }
            Button { viewModel.copyAccountId() } label: { Text("Копировать ID") }
        }
#endif
        .frame(maxWidth: .infinity)
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
    @Binding var avatarURL: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
            .navigationTitle("Ссылка на аватар")
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
