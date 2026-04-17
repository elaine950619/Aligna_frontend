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

    @State private var selectedID: String? = nil
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

    private let sandColor = Color(red: 0.94, green: 0.88, blue: 0.72)
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
        ZStack {
            AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Title
                Text("focus.select_title")
                    .font(.custom("Merriweather-Bold", size: 22))
                    .foregroundColor(themeManager.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 56)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Row 1: Presence (pinned) + Custom card ──
                        LazyVGrid(columns: columns, spacing: 12) {
                            if let p = presenceItem {
                                focusCard(p)
                            }
                            addCustomCard
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                        // ── Grouped sections ──
                        ForEach(groups, id: \.key) { group in
                            let groupItems = items(for: group.key)
                            if !groupItems.isEmpty {
                                // Section header
                                Text(String(localized: String.LocalizationValue(group.labelKey)))
                                    .font(.custom("Merriweather-Regular", size: 10))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 10)

                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(groupItems) { item in
                                        focusCard(item)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 28)
                            }
                        }

                        // Custom user focuses (no groupKey / ungrouped)
                        let customItems = focuses.filter { $0.groupKey.isEmpty && $0.id != presenceFocusID }
                        if !customItems.isEmpty {
                            Text(String(localized: "focus.add_custom"))
                                .font(.custom("Merriweather-Regular", size: 10))
                                .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(customItems) { item in
                                    focusCard(item)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                        }
                    }
                    .padding(.bottom, 24)
                }

                Spacer(minLength: 0)

                // Confirm button
                Button {
                    if let id = selectedID {
                        onConfirm(id)
                    }
                } label: {
                    Text("focus.confirm_button")
                        .font(.custom("Merriweather-Regular", size: 16))
                        .foregroundColor(selectedID != nil
                            ? Color(red: 0.12, green: 0.10, blue: 0.08)
                            : themeManager.descriptionText.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedID != nil
                                    ? sandColor
                                    : themeManager.panelFill.opacity(0.3))
                        )
                }
                .disabled(selectedID == nil)
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            // Pre-select current focus if set
            selectedID = currentFocusID
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
                        .tint(sandColor)
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
                        .tint(sandColor)
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
                            ? Color(red: 0.12, green: 0.10, blue: 0.08)
                            : themeManager.descriptionText.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(canSaveCustom
                                    ? sandColor
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
                        ? Color(red: 0.12, green: 0.10, blue: 0.08)
                        : themeManager.primaryText.opacity(0.88))
                    .lineLimit(1)
                Text(item.description)
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(isSelected
                        ? Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.65)
                        : themeManager.descriptionText.opacity(0.55))
                    .lineLimit(3)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? sandColor.opacity(themeManager.isNight ? 0.88 : 0.80)
                        : themeManager.panelFill.opacity(themeManager.isNight ? 0.28 : 0.36))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? sandColor : Color.white.opacity(0.10),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var addCustomCard: some View {
        Button {
            showCustomForm = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("focus.add_custom")
                        .font(.custom("Merriweather-Bold", size: 15))
                }
                .foregroundColor(themeManager.primaryText.opacity(0.70))
                Text(String(localized: "Create your own"))
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.panelFill.opacity(themeManager.isNight ? 0.18 : 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundColor(Color.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }
}
