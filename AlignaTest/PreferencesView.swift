import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PreferencesView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: OnboardingViewModel
    let userDocID: String?
    let userCollection: String?

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSavedAlert = false

    @State private var didInitialize = false
    @State private var scentDislikeDraft: Set<String> = []
    @State private var actPreferDraft: Set<String> = []
    @State private var colorDislikeDraft: Set<String> = []
    @State private var allergiesDraft: Set<String> = []
    @State private var musicDislikeDraft: Set<String> = []

    private let scentOptions  = ["Floral", "Strong", "Woody", "Citrus", "Spicy", "Other"]
    private let actOptions    = ["Static", "Dynamic", "No preference"]
    private let colorOptions  = ["Yellow", "Pink", "Green", "Orange", "Purple", "Other"]
    private let allergyOpts   = ["Pollen/Dust", "Food", "Pet", "Chemical", "Seasonal", "Other"]
    private let musicOptions  = ["Heavy metal", "Electronic", "Classical", "Jazz", "Ambient", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(nightMotion: .animated)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        headerCard

                        preferenceSection(
                            "Any scent that don’t feel right?",
                            content: chips(
                                options: scentOptions,
                                isSelected: { scentDislikeDraft.contains($0) },
                                toggle: { toggleSet(&scentDislikeDraft, $0) }


                            )
                        )

                        preferenceSection(
                            "Activity preference?",
                            content: chips(
                                options: actOptions,
                                isSelected: { actPreferDraft.contains($0) },
                                toggle: { toggleSet(&actPreferDraft, $0) }
                            )
                        )

                        preferenceSection(
                            "Any color that don’t feel right?",
                            content: chips(
                                options: colorOptions,
                                isSelected: { colorDislikeDraft.contains($0) },
                                toggle: { toggleSet(&colorDislikeDraft, $0) }
                            )
                        )

                        preferenceSection(
                            "Any allergies we should know about?",
                            content: chips(
                                options: allergyOpts,
                                isSelected: { allergiesDraft.contains($0) },
                                toggle: { toggleSet(&allergiesDraft, $0) }
                            )
                        )

                        preferenceSection(
                            "Any sound that don’t feel right?",
                            content: chips(
                                options: musicOptions,
                                isSelected: { musicDislikeDraft.contains($0) },
                                toggle: { toggleSet(&musicDislikeDraft, $0) }
                            )
                        )

                        Button(action: savePreferences) {
                            Text(isSaving ? "Saving…" : "Save")
                                .font(AlynnaTypography.font(.body))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(themeManager.accent.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(isSaving)
                        .foregroundColor(themeManager.accent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 0)
                    .padding(.bottom, 20)
                }

                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(themeManager.primaryText)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer()
                }

                if isSaving {
                    ProgressView()
                        .scaleEffect(1.1)
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear {
            if !didInitialize {
                scentDislikeDraft = viewModel.scent_dislike
                actPreferDraft = viewModel.act_prefer
                colorDislikeDraft = viewModel.color_dislike
                allergiesDraft = viewModel.allergies
                musicDislikeDraft = viewModel.music_dislike
                didInitialize = true
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your preferences have been saved.")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    private var headerCard: some View {
        Text("Preferences")
            .font(TimelineType.title34GloockBlack())
            .lineSpacing(TimelineType.title34LineSpacing)
            .foregroundColor(themeManager.primaryText)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 38)
            .padding(.bottom, 28)
    }

    private func preferenceSection<Content: View>(_ title: String, content: Content) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(AlynnaTypography.font(.subheadline))
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            content
        }
        .padding(10)
        .alignaCard()
    }

    private func chips(
        options: [String],
        isSelected: @escaping (String) -> Bool,
        toggle: @escaping (String) -> Void
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(options, id: \.self) { opt in
                Button {
                    toggle(opt)
                } label: {
                    let selected = isSelected(opt)
                    Text(opt)
                        .font(.custom("Merriweather-Regular", size: 12))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            selected
                                ? themeManager.accent.opacity(0.22)
                                : themeManager.panelFill
                        )
                        .foregroundColor(themeManager.primaryText)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.panelStrokeHi.opacity(selected ? 0.0 : 0.8), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleSet(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func savePreferences() {
        guard let col = userCollection, let id = userDocID else {
            errorMessage = "User document not found."
            return
        }

        isSaving = true

        let payload: [String: Any] = [
            "scent_dislike": Array(scentDislikeDraft),
            "act_prefer": Array(actPreferDraft),
            "color_dislike": Array(colorDislikeDraft),
            "allergies": Array(allergiesDraft),
            "music_dislike": Array(musicDislikeDraft),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        Firestore.firestore().collection(col).document(id).setData(payload, merge: true) { err in
            isSaving = false
            if let err = err {
                errorMessage = err.localizedDescription
            } else {
                viewModel.scent_dislike = scentDislikeDraft
                viewModel.act_prefer = actPreferDraft
                viewModel.color_dislike = colorDislikeDraft
                viewModel.allergies = allergiesDraft
                viewModel.music_dislike = musicDislikeDraft
                showSavedAlert = true
            }
        }
    }
}


#if DEBUG
#Preview("Preferences") {
    let themeManager = ThemeManager()
    themeManager.selected = .day

    let viewModel = OnboardingViewModel()
    viewModel.scent_dislike = ["Floral", "Woody"]
    viewModel.act_prefer = ["Dynamic"]
    viewModel.color_dislike = ["Yellow"]
    viewModel.allergies = ["Seasonal"]
    viewModel.music_dislike = ["Electronic"]

    return PreferencesView(
        viewModel: viewModel,
        userDocID: "preview",
        userCollection: "users"
    )
    .environmentObject(StarAnimationManager())
    .environmentObject(themeManager)
}
#endif
