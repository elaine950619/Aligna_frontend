import SwiftUI

struct FocusSelectionView: View {
    let focuses: [FocusItem]
    let presenceFocusID: String          // ID of the presence focus (pinned top-left)
    let currentFocusID: String?
    let onConfirm: (String) -> Void
    let onAddCustom: () -> Void
    /// Called when the user creates a new custom focus inline.
    /// Caller is responsible for persisting and adding it to the focuses list.
    var onCreateCustom: ((String, String) -> Void)? = nil

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @State private var selectedID: String?

    init(focuses: [FocusItem], presenceFocusID: String, currentFocusID: String?,
         onConfirm: @escaping (String) -> Void, onAddCustom: @escaping () -> Void,
         onCreateCustom: ((String, String) -> Void)? = nil) {
        self.focuses = focuses
        self.presenceFocusID = presenceFocusID
        self.currentFocusID = currentFocusID
        self.onConfirm = onConfirm
        self.onAddCustom = onAddCustom
        self.onCreateCustom = onCreateCustom
        // Set initial selection immediately so first render shows the correct highlight
        _selectedID = State(initialValue: currentFocusID ?? presenceFocusID)
    }

    @State private var showCustomForm = false
    @State private var customName = ""
    @State private var customDescription = ""

    // FocusItem is a plain transferable struct so we don't depend on private MantraFocus
    struct FocusItem: Identifiable {
        let id: String          // UUID string
        let name: String        // localized display name
        let description: String
        var groupKey: String = ""   // e.g. "everyday", "relationships", etc. Empty = ungrouped
    }

    struct FocusGroup {
        let key: String         // matches FocusItem.groupKey
        let labelKey: String    // localization key for group header
    }

    /// Ordered group definitions — determines display order of sections
    private let groups: [FocusGroup] = [
        FocusGroup(key: "everyday",      labelKey: "focus.group.everyday"),
        FocusGroup(key: "relationships", labelKey: "focus.group.relationships"),
        FocusGroup(key: "body",          labelKey: "focus.group.body"),
        FocusGroup(key: "transitions",   labelKey: "focus.group.transitions"),
        FocusGroup(key: "inner",         labelKey: "focus.group.inner"),
        FocusGroup(key: "practical",     labelKey: "focus.group.practical"),
    ]

    // sandColor 由 themeManager.accent 替代，在各处直接使用
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var canSaveCustom: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The presence focus item (pinned top-left)
    private var presenceItem: FocusItem? {
        focuses.first { $0.id == presenceFocusID }
    }

    /// Focuses that belong to a given group key
    private func items(for groupKey: String) -> [FocusItem] {
        focuses.filter { $0.groupKey == groupKey }
    }

    var body: some View {
        // ── Layout: title (fixed top) → scrollable grid (flex) → confirm button (fixed bottom) ──
        VStack(spacing: 0) {

            // ── Title ──
            Text("focus.select_title")
                .font(.custom("Merriweather-Bold", size: 22))
                .foregroundColor(themeManager.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 56)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)

            // ── Scrollable focus grid — strictly between title and button ──
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Presence focus ──
                    if let p = presenceItem {
                        LazyVGrid(columns: columns, spacing: 12) {
                            focusCard(p)
                        }
                        .padding(.bottom, 12)
                    }

                    // ── Grouped sections ──
                    ForEach(groups, id: \.key) { group in
                        let groupItems = items(for: group.key)
                        if !groupItems.isEmpty {
                            HStack(spacing: 10) {
                                Text(String(localized: String.LocalizationValue(group.labelKey)))
                                    .font(.custom("Merriweather-Regular", size: 10))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .fixedSize()
                                Rectangle()
                                    .fill(themeManager.descriptionText.opacity(0.15))
                                    .frame(height: 1)
                            }
                            .padding(.bottom, 10)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(groupItems) { item in
                                    focusCard(item)
                                }
                            }
                            .padding(.bottom, 28)
                        }
                    }

                    // ── Custom user focuses ──
                    let customItems = focuses.filter { $0.groupKey.isEmpty && $0.id != presenceFocusID }
                    if !customItems.isEmpty {
                        HStack(spacing: 10) {
                            Text(String(localized: "focus.add_custom"))
                                .font(.custom("Merriweather-Regular", size: 10))
                                .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .fixedSize()
                            Rectangle()
                                .fill(themeManager.descriptionText.opacity(0.15))
                                .frame(height: 1)
                        }
                        .padding(.bottom, 10)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(customItems) { item in
                                focusCard(item)
                            }
                        }
                        .padding(.bottom, 28)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // ── Confirm button — always visible at bottom ──
            Button {
                if let id = selectedID {
                    onConfirm(id)
                }
            } label: {
                Text("focus.confirm_button")
                    .font(.custom("Merriweather-Regular", size: 16))
                    .foregroundColor(selectedID != nil
                        ? themeManager.buttonForegroundOnPrimary.opacity(0.85)
                        : themeManager.descriptionText.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedID != nil
                                ? themeManager.accent.opacity(0.82)
                                : themeManager.panelFill.opacity(0.3))
                    )
            }
            .disabled(selectedID == nil)
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background {
            AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()
        }
        // ── 自定义 focus 创建表单 ──
        .sheet(isPresented: $showCustomForm) {
            customFocusFormSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }

    // MARK: - Custom focus form sheet

    private var customFocusFormSheet: some View {
        ZStack {
            themeManager.panelFill
                .opacity(themeManager.isNight ? 0.95 : 0.98)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("focus.add_custom")
                        .font(.custom("Merriweather-Bold", size: 18))
                        .foregroundColor(themeManager.primaryText)
                    Spacer()
                    Button {
                        showCustomForm = false
                        customName = ""
                        customDescription = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.descriptionText.opacity(0.55))
                            .padding(8)
                            .background(Circle().fill(themeManager.panelFill.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)

                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Focus name"))
                        .font(.custom("Merriweather-Regular", size: 11))
                        .foregroundColor(themeManager.descriptionText.opacity(0.55))
                        .tracking(0.8)
                        .textCase(.uppercase)
                    TextField(String(localized: "e.g. Creative work"), text: $customName)
                        .font(.custom("Merriweather-Regular", size: 15))
                        .foregroundColor(themeManager.primaryText)
                        .tint(themeManager.accent)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.panelFill.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Description field
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "What should this focus hold space for?"))
                        .font(.custom("Merriweather-Regular", size: 11))
                        .foregroundColor(themeManager.descriptionText.opacity(0.55))
                        .tracking(0.8)
                        .textCase(.uppercase)
                    TextField(String(localized: "A short description…"), text: $customDescription, axis: .vertical)
                        .font(.custom("Merriweather-Regular", size: 15))
                        .foregroundColor(themeManager.primaryText)
                        .tint(themeManager.accent)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.panelFill.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Save button
                Button {
                    let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let desc = customDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    if let onCreate = onCreateCustom {
                        onCreate(name, desc)
                    } else {
                        onAddCustom()
                    }
                    showCustomForm = false
                    customName = ""
                    customDescription = ""
                } label: {
                    Text(String(localized: "focus.confirm_button"))
                        .font(.custom("Merriweather-Regular", size: 16))
                        .foregroundColor(canSaveCustom
                            ? themeManager.buttonForegroundOnPrimary.opacity(0.85)
                            : themeManager.descriptionText.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(canSaveCustom
                                    ? themeManager.accent.opacity(0.82)
                                    : themeManager.panelFill.opacity(0.35))
                        )
                }
                .disabled(!canSaveCustom)
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    // MARK: - Focus cards

    @ViewBuilder
    private func focusCard(_ item: FocusItem) -> some View {
        let isSelected = selectedID == item.id
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedID = item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.custom("Merriweather-Bold", size: 15))
                    .foregroundColor(isSelected
                        ? themeManager.primaryText.opacity(0.90)
                        : themeManager.primaryText.opacity(0.88))
                    .lineLimit(1)
                Text(item.description)
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(isSelected
                        ? themeManager.primaryText.opacity(0.55)
                        : themeManager.descriptionText.opacity(0.55))
                    .lineLimit(3)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? themeManager.accent.opacity(themeManager.isNight ? 0.22 : 0.16)
                        : themeManager.panelFill.opacity(themeManager.isNight ? 0.28 : 0.36))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? themeManager.accent.opacity(0.70) : themeManager.panelStrokeHi.opacity(0.5),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

}


