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

    // Raw English values — used as Firestore data keys
    private let scentOptions  = ["Floral", "Strong", "Woody", "Citrus", "Spicy", "Other"]
    private let actOptions    = ["Static", "Dynamic", "No preference"]
    private let colorOptions  = ["Yellow", "Pink", "Green", "Orange", "Purple", "Other"]
    private let allergyOpts   = ["Pollen/Dust", "Food", "Pet", "Chemical", "Seasonal", "Other"]
    private let musicOptions  = ["Heavy metal", "Electronic", "Classical", "Jazz", "Ambient", "Other"]

    /// Maps English data values to localized display names for chip labels.
    private func localizedChipLabel(_ value: String) -> String {
        switch value {
        case "Floral":        return String(localized: "preferences.scent.floral")
        case "Strong":        return String(localized: "preferences.scent.strong")
        case "Woody":         return String(localized: "preferences.scent.woody")
        case "Citrus":        return String(localized: "preferences.scent.citrus")
        case "Spicy":         return String(localized: "preferences.scent.spicy")
        case "Static":        return String(localized: "preferences.act.static")
        case "Dynamic":       return String(localized: "preferences.act.dynamic")
        case "No preference": return String(localized: "preferences.act.no_preference")
        case "Yellow":        return String(localized: "preferences.color.yellow")
        case "Pink":          return String(localized: "preferences.color.pink")
        case "Green":         return String(localized: "preferences.color.green")
        case "Orange":        return String(localized: "preferences.color.orange")
        case "Purple":        return String(localized: "preferences.color.purple")
        case "Pollen/Dust":   return String(localized: "preferences.allergy.pollen")
        case "Food":          return String(localized: "preferences.allergy.food")
        case "Pet":           return String(localized: "preferences.allergy.pet")
        case "Chemical":      return String(localized: "preferences.allergy.chemical")
        case "Seasonal":      return String(localized: "preferences.allergy.seasonal")
        case "Heavy metal":   return String(localized: "preferences.music.heavy_metal")
        case "Electronic":    return String(localized: "preferences.music.electronic")
        case "Classical":     return String(localized: "preferences.music.classical")
        case "Jazz":          return String(localized: "preferences.music.jazz")
        case "Ambient":       return String(localized: "preferences.music.ambient")
        case "Other":         return String(localized: "preferences.other")
        default:              return value
        }
    }

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
                            String(localized: "preferences.scent_question"),
                            content: chips(
                                options: scentOptions,
                                isSelected: { scentDislikeDraft.contains($0) },
                                toggle: { toggleSet(&scentDislikeDraft, $0) }


                            )
                        )

                        preferenceSection(
                            String(localized: "preferences.activity_question"),
                            content: chips(
                                options: actOptions,
                                isSelected: { actPreferDraft.contains($0) },
                                toggle: { toggleSet(&actPreferDraft, $0) }
                            )
                        )

                        preferenceSection(
                            String(localized: "preferences.color_question"),
                            content: chips(
                                options: colorOptions,
                                isSelected: { colorDislikeDraft.contains($0) },
                                toggle: { toggleSet(&colorDislikeDraft, $0) }
                            )
                        )

                        preferenceSection(
                            String(localized: "preferences.allergies_question"),
                            content: chips(
                                options: allergyOpts,
                                isSelected: { allergiesDraft.contains($0) },
                                toggle: { toggleSet(&allergiesDraft, $0) }
                            )
                        )

                        preferenceSection(
                            String(localized: "preferences.music_question"),
                            content: chips(
                                options: musicOptions,
                                isSelected: { musicDislikeDraft.contains($0) },
                                toggle: { toggleSet(&musicDislikeDraft, $0) }
                            )
                        )

                        Button(action: savePreferences) {
                            Text(isSaving ? String(localized: "preferences.saving") : String(localized: "preferences.save"))
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

                if let errorMessage {
                    AlynnaActionDialog(
                        title: String(localized: "preferences.error_title"),
                        message: errorMessage,
                        symbol: "exclamationmark.circle",
                        tone: .error,
                        dismissButtonTitle: String(localized: "preferences.ok"),
                        onDismiss: { self.errorMessage = nil }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
                } else if showSavedAlert {
                    AlynnaActionDialog(
                        title: String(localized: "preferences.saved_title"),
                        message: String(localized: "preferences.saved_message"),
                        symbol: "checkmark.circle",
                        tone: .success,
                        dismissButtonTitle: String(localized: "preferences.ok"),
                        onDismiss: { showSavedAlert = false }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    private var headerCard: some View {
        Text(String(localized: "preferences.title"))
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
                    Text(localizedChipLabel(opt))
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
            errorMessage = String(localized: "preferences.doc_not_found")
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
