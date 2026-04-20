import SwiftUI

// MARK: - BondsView
//
// Inner circle list page: shows active / cooling bonds + any pending bond
// requests (received + sent). Entry point is Profile → "我的亲近圈".
// Tapping "+ 添加亲近之人" pushes the AddBondView add flow.
//
// Navigation: NavigationStack-based. Returning from AddBondView triggers
// a refresh to reflect the newly-sent request.

struct BondsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing: Bool = false
    @State private var rowError: [String: String] = [:]  // bondId/requestId → message
    @State private var appearCount: Int = 0  // incremented on every appear to retrigger .task

    var body: some View {
        ZStack {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection

                        if isContentEmpty {
                            emptyStateView
                                .padding(.top, 40)
                        } else {
                            if !activeBonds.isEmpty {
                                sectionHeader(String(localized: "bonds.active_section"))
                                VStack(spacing: 10) {
                                    ForEach(activeBonds) { bond in
                                        activeBondRow(bond)
                                    }
                                }
                            }

                            if !coolingBonds.isEmpty {
                                sectionHeader(String(localized: "bonds.cooling_section"))
                                VStack(spacing: 10) {
                                    ForEach(coolingBonds) { bond in
                                        coolingBondRow(bond)
                                    }
                                }
                            }

                            if !viewModel.pendingReceivedRequests.isEmpty {
                                sectionHeader(String(localized: "bonds.received_section"))
                                VStack(spacing: 10) {
                                    ForEach(viewModel.pendingReceivedRequests) { req in
                                        receivedRequestRow(req)
                                    }
                                }
                            }

                            if !viewModel.pendingSentRequests.isEmpty {
                                sectionHeader(String(localized: "bonds.sent_section"))
                                VStack(spacing: 10) {
                                    ForEach(viewModel.pendingSentRequests) { req in
                                        sentRequestRow(req)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 68)
                }
                .refreshable {
                    await viewModel.refreshBonds()
                }

                // Bottom CTA — Add someone close
                NavigationLink {
                    AddBondView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .environmentObject(starManager)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text(String(localized: "bonds.add_button"))
                            .font(AlynnaTypography.font(.headline))
                    }
                    .foregroundColor(themeManager.buttonForegroundOnPrimary.opacity(0.90))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeManager.accent.opacity(0.86))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .disabled(viewModel.alynnaNumber.isEmpty || totalBondCount >= 10)
                .opacity((viewModel.alynnaNumber.isEmpty || totalBondCount >= 10) ? 0.5 : 1.0)
            }

            // Custom navigation bar overlay
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                    NavigationLink {
                        BlockedNumbersView()
                            .environmentObject(viewModel)
                            .environmentObject(themeManager)
                            .environmentObject(starManager)
                    } label: {
                        Image(systemName: "hand.raised")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(themeManager.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(String(localized: "profile.blocked_numbers_title")))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { appearCount += 1 }
        .task(id: appearCount) {
            await viewModel.refreshBonds()
        }
    }

    // MARK: - Derived data

    private var activeBonds: [BondSummary] {
        viewModel.bonds.filter { $0.status == "active" }
    }

    private var coolingBonds: [BondSummary] {
        viewModel.bonds.filter { $0.status == "cooling" }
    }

    private var isContentEmpty: Bool {
        viewModel.bonds.isEmpty
            && viewModel.pendingReceivedRequests.isEmpty
            && viewModel.pendingSentRequests.isEmpty
    }

    private var totalBondCount: Int {
        viewModel.bonds.count + viewModel.pendingSentRequests.count
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "bonds.section_title"))
                .font(AlynnaTypography.font(.largeTitle))
                .foregroundColor(themeManager.primaryText)
            Text(String(
                format: String(localized: "bonds.max_hint"),
                10  // max inner circle members
            ))
            .font(AlynnaTypography.font(.subheadline))
            .foregroundColor(themeManager.descriptionText.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(themeManager.accent.opacity(0.45))
            Text(String(localized: "bonds.empty_state"))
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(themeManager.primaryText.opacity(0.78))
            Text(String(localized: "bonds.empty_hint"))
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.descriptionText.opacity(0.70))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("Merriweather-Regular", size: 11))
            .foregroundColor(themeManager.descriptionText.opacity(0.55))
            .tracking(1.4)
            .textCase(.uppercase)
            .padding(.top, 6)
    }

    // MARK: - Row: active bond

    @ViewBuilder
    private func activeBondRow(_ bond: BondSummary) -> some View {
        NavigationLink {
            BondDetailView(bond: bond)
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .environmentObject(starManager)
        } label: {
            HStack(spacing: 14) {
                avatarCircle(for: bond.partner_nickname)

                VStack(alignment: .leading, spacing: 3) {
                    Text(bond.partner_nickname)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                    HStack(spacing: 6) {
                        Text(bond.partner_alynna_number.alynnaNumberDisplay)
                            .font(.custom("Merriweather-Regular", size: 11))
                            .foregroundColor(themeManager.descriptionText.opacity(0.65))
                            .monospacedDigit()
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
            }
            .padding(14)
            .alignaCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Row: cooling bond

    @ViewBuilder
    private func coolingBondRow(_ bond: BondSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                avatarCircle(for: bond.partner_nickname)
                VStack(alignment: .leading, spacing: 3) {
                    Text(bond.partner_nickname)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                    Text(coolingRemainingText(bond))
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText.opacity(0.75))
                }
                Spacer()
            }
            Button {
                Task {
                    do {
                        try await AlynnaAPI.shared.cancelCoolingBond(bond.bond_id)
                        await viewModel.refreshBonds()
                    } catch {
                        rowError[bond.bond_id] = error.localizedDescription
                    }
                }
            } label: {
                Text(String(localized: "bonds.cancel_cooling"))
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(themeManager.descriptionText.opacity(0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.panelStrokeHi.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if let err = rowError[bond.bond_id] {
                Text(err)
                    .font(AlynnaTypography.font(.caption1))
                    .foregroundColor(.red.opacity(0.75))
            }
        }
        .padding(14)
        .alignaCard()
    }

    private func coolingRemainingText(_ bond: BondSummary) -> String {
        guard
            let iso = bond.cooling_until,
            let date = ISO8601DateFormatter.shared.date(from: iso)
        else {
            return String(localized: "bonds.cooling_ending_soon")
        }
        let remaining = date.timeIntervalSince(Date())
        if remaining <= 0 {
            return String(localized: "bonds.cooling_ending_soon")
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "bonds.cooling_remaining_hm"), hours, minutes)
        }
        return String(format: String(localized: "bonds.cooling_remaining_m"), max(minutes, 1))
    }

    // MARK: - Row: received request (accept / decline inline)

    @ViewBuilder
    private func receivedRequestRow(_ req: PendingRequestSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                avatarCircle(for: req.other_nickname)
                VStack(alignment: .leading, spacing: 3) {
                    Text(req.other_nickname)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                    Text(req.other_alynna_number.alynnaNumberDisplay)
                        .font(.custom("Merriweather-Regular", size: 11))
                        .foregroundColor(themeManager.descriptionText.opacity(0.65))
                        .monospacedDigit()
                }
                Spacer()
            }

            Text(String(localized: "bonds.privacy_warning"))
                .font(AlynnaTypography.font(.caption1))
                .foregroundColor(themeManager.descriptionText.opacity(0.65))
                .lineSpacing(2)

            HStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            _ = try await AlynnaAPI.shared.acceptBondRequest(req.request_id)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            await viewModel.refreshBonds()
                        } catch {
                            rowError[req.request_id] = error.localizedDescription
                        }
                    }
                } label: {
                    Text(String(localized: "bonds.accept"))
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.buttonForegroundOnPrimary.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeManager.accent.opacity(0.82))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        do {
                            try await AlynnaAPI.shared.declineBondRequest(req.request_id)
                            await viewModel.refreshBonds()
                        } catch {
                            rowError[req.request_id] = error.localizedDescription
                        }
                    }
                } label: {
                    Text(String(localized: "bonds.decline"))
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.descriptionText.opacity(0.78))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(themeManager.panelStrokeHi.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Low-emphasis "decline & block" option — a single tap does both
            // actions in sequence. Positioned below so casual decline remains
            // the 1-tap primary path.
            Button {
                Task {
                    do {
                        // Decline first, then block. Order matters: declining
                        // an already-blocked user's request still works, but
                        // blocking before declining risks the request surviving.
                        try? await AlynnaAPI.shared.declineBondRequest(req.request_id)
                        try await viewModel.blockNumber(req.other_alynna_number)
                        await viewModel.refreshBonds()
                    } catch {
                        rowError[req.request_id] = error.localizedDescription
                    }
                }
            } label: {
                Text(String(localized: "bonds.block_sender"))
                    .font(AlynnaTypography.font(.caption1))
                    .foregroundColor(themeManager.descriptionText.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            if let err = rowError[req.request_id] {
                Text(err)
                    .font(AlynnaTypography.font(.caption1))
                    .foregroundColor(.red.opacity(0.75))
            }
        }
        .padding(14)
        .alignaCard()
    }

    // MARK: - Row: sent request (waiting)

    @ViewBuilder
    private func sentRequestRow(_ req: PendingRequestSummary) -> some View {
        HStack(spacing: 14) {
            avatarCircle(for: req.other_nickname)
            VStack(alignment: .leading, spacing: 3) {
                Text(req.other_nickname)
                    .font(AlynnaTypography.font(.headline))
                    .foregroundColor(themeManager.primaryText.opacity(0.82))
                Text(String(localized: "bonds.waiting_for_response"))
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(themeManager.descriptionText.opacity(0.60))
            }
            Spacer()
            Image(systemName: "hourglass")
                .foregroundColor(themeManager.descriptionText.opacity(0.45))
                .font(.system(size: 14))
        }
        .padding(14)
        .alignaCard()
    }

    // MARK: - Small UI bits

    private func avatarCircle(for nickname: String) -> some View {
        let initial = nickname.first.map { String($0) } ?? "·"
        return ZStack {
            Circle()
                .fill(themeManager.accent.opacity(0.18))
                .frame(width: 40, height: 40)
            Text(initial)
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(themeManager.accent.opacity(0.85))
        }
    }
}

// MARK: - ISO8601 helper (reused across Bonding views)

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - BondDetailView (minimal v1 stub)
// Full detail UI (compatibility breakdown, sever flow) comes next.
struct BondDetailView: View {
    let bond: BondSummary
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager
    @Environment(\.dismiss) private var dismiss

    @State private var compatibility: CompatibilityResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSeverConfirm = false
    @State private var clearHistoryImmediately = false
    @State private var isSeverInFlight = false
    @State private var showBreakdownInfo = false

    // Read active focus name directly from UserDefaults (same keys MainView uses).
    @AppStorage("mantraActiveFocusStorage") private var mantraActiveFocusStorage: String = ""
    @AppStorage("mantraTagLibraryStorage")  private var mantraTagLibraryStorage: String = ""

    /// Today's focus raw tag for the current user, read from UserDefaults.
    /// Returns the raw `name` (e.g. "presence", "dating") so it can be passed
    /// to `focusDisplayName(for:)` — the same translation path as partner focus.
    /// Falls back to empty string if no focus is set or library hasn't loaded.
    private var myTodayFocusTag: String {
        let todayKey = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        guard
            let data = mantraActiveFocusStorage.data(using: .utf8),
            let activeMap = try? JSONDecoder().decode([String: String].self, from: data),
            let focusID = activeMap[todayKey]
        else { return "" }

        struct FocusStub: Decodable { let id: UUID; let name: String }
        guard
            let libData = mantraTagLibraryStorage.data(using: .utf8),
            let library = try? JSONDecoder().decode([FocusStub].self, from: libData),
            let focus = library.first(where: { $0.id.uuidString == focusID })
        else { return "" }

        return focus.name
    }

    /// Always reflects the latest partner data from the live bonds list.
    /// Falls back to the original snapshot if the bond is no longer in the list
    /// (e.g. just severed, mid-animation).
    private var currentBond: BondSummary {
        viewModel.bonds.first(where: { $0.bond_id == bond.bond_id }) ?? bond
    }

    var body: some View {
        ZStack {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Hero: two avatar bubbles + star connector + score
                    heroSection
                        .padding(.top, 68)
                        .padding(.horizontal, 20)

                    // Today comparison: me vs partner
                    if let c = compatibility {
                        todayComparisonCard(c)
                            .padding(.horizontal, 20)
                    }

                    // Shared intents (if any)
                    if let c = compatibility, !c.shared_intents.isEmpty {
                        sharedIntentsCard(c)
                            .padding(.horizontal, 20)
                    }

                    // Compatibility breakdown (4 components)
                    if let c = compatibility, let components = c.components, !components.isEmpty {
                        breakdownCard(components)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)

                    // Sever button
                    Button(role: .destructive) {
                        showSeverConfirm = true
                    } label: {
                        Text(String(localized: "bonds.sever_button"))
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(themeManager.descriptionText.opacity(0.60))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .disabled(isSeverInFlight)
                }
            }

            // Custom back button overlay
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
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
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadCompatibility()
        }
        .onAppear {
            Task { await viewModel.refreshBonds() }
        }
        .overlay {
            if showSeverConfirm {
                AlynnaActionDialog(
                    title: String(localized: "bonds.sever_confirm_title"),
                    message: String(localized: "bonds.sever_confirm_body"),
                    symbol: "person.2.slash",
                    tone: .destructive,
                    primaryButtonTitle: String(localized: "bonds.sever_confirm_action"),
                    primaryAction: {
                        Task { await performSever(clearNow: false) }
                    },
                    secondaryButtonTitle: String(localized: "bonds.sever_confirm_action_clear_now"),
                    secondaryAction: {
                        Task { await performSever(clearNow: true) }
                    },
                    dismissButtonTitle: String(localized: "bonds.sever_confirm_cancel"),
                    onDismiss: { showSeverConfirm = false }
                )
                .environmentObject(themeManager)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(20)
                .animation(.easeInOut(duration: 0.18), value: showSeverConfirm)
            }
        }
    }

    // MARK: - Card computed properties

    /// Avatar bubble view: circle bg + initial letter + name below.
    private func avatarBubble(nickname: String, size: CGFloat) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(themeManager.accent.opacity(0.18))
                    .frame(width: size, height: size)
                Text(nickname.first.map { String($0) } ?? "·")
                    .font(.custom("Merriweather-Bold", size: size * 0.4))
                    .foregroundColor(themeManager.accent.opacity(0.88))
            }
            Text(nickname)
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.primaryText)
                .lineLimit(1)
        }
    }

    /// Hero section: two avatar bubbles flanking a star connector + compatibility score.
    private var heroSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Self bubble (smaller)
            avatarBubble(nickname: viewModel.nickname, size: 56)
                .frame(maxWidth: .infinity)

            // Center: star + score
            VStack(spacing: 4) {
                FourPointStarShape()
                    .fill(themeManager.accent.opacity(0.70))
                    .frame(width: 18, height: 18)

                if let c = compatibility {
                    Text("\(c.compatibility)")
                        .font(.custom("Merriweather-Bold", size: 44))
                        .foregroundColor(themeManager.primaryText)
                        .monospacedDigit()
                    Text(String(
                        format: String(localized: "bonds.permanent_base_value"),
                        c.permanent_base
                    ))
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(themeManager.descriptionText.opacity(0.60))
                    .multilineTextAlignment(.center)
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accent))
                        .padding(.vertical, 8)
                } else if let err = errorMessage {
                    Text(err)
                        .font(AlynnaTypography.font(.caption1))
                        .foregroundColor(.red.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                Text(String(localized: "bonds.daily_compat_label"))
                    .font(.custom("Merriweather-Regular", size: 9))
                    .foregroundColor(themeManager.descriptionText.opacity(0.50))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // Partner bubble (larger)
            avatarBubble(nickname: currentBond.partner_nickname, size: 72)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
    }

    /// Star row: filled stars for a 0–100 score + numeric value.
    private func starRow(score: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                FourPointStarShape()
                    .fill(
                        i < starsForScore(score)
                            ? themeManager.accent.opacity(0.88)
                            : themeManager.accent.opacity(0.20)
                    )
                    .frame(width: 9, height: 9)
            }
            Text("\(score)")
                .font(.custom("Merriweather-Regular", size: 11))
                .foregroundColor(themeManager.descriptionText.opacity(0.65))
                .monospacedDigit()
        }
    }

    /// Small capsule keyword tags.
    private func keywordCapsules(_ keywords: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(keywords.prefix(3).enumerated()), id: \.offset) { _, kw in
                Text(kw)
                    .font(.custom("Merriweather-Regular", size: 10))
                    .foregroundColor(themeManager.primaryText.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(themeManager.accent.opacity(0.13)))
                    .overlay(Capsule().strokeBorder(themeManager.accent.opacity(0.22), lineWidth: 0.5))
            }
        }
    }

    /// Today comparison card — me (left) vs partner (right), split by a thin divider.
    @ViewBuilder
    private func todayComparisonCard(_ c: CompatibilityResponse) -> some View {
        let myKeywords  = viewModel.dailyKeywords
        let myScore     = viewModel.dailyScore
        let partnerKws  = partnerKeywordList(c) ?? []
        let partnerScore = partnerDailyScore(c)
        let partnerFocus = partnerFocusTag(c)

        let myFocusTag     = myTodayFocusTag
        let myFocusName    = myFocusTag.isEmpty ? "" : focusDisplayName(for: myFocusTag)
        let hasMyData      = !myKeywords.isEmpty || myScore > 0 || !myFocusName.isEmpty
        let hasPartnerData = !partnerKws.isEmpty || (partnerScore ?? 0) > 0 || partnerFocus != nil

        if hasMyData || hasPartnerData {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "bonds.today_comparison_title"))
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(themeManager.descriptionText.opacity(0.60))
                    .tracking(1.4)
                    .textCase(.uppercase)

                HStack(alignment: .top, spacing: 0) {
                    // ── Left: Me ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.nickname)
                            .font(.custom("Merriweather-Bold", size: 12))
                            .foregroundColor(themeManager.primaryText.opacity(0.70))
                            .lineLimit(1)

                        if !myFocusName.isEmpty {
                            Text(myFocusName)
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.accent.opacity(0.80))
                                .lineLimit(1)
                        }
                        if !myKeywords.isEmpty {
                            keywordCapsules(myKeywords)
                        }
                        if myScore > 0 {
                            starRow(score: myScore)
                        }
                        if !hasMyData {
                            Text(String(localized: "bonds.today_no_data"))
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.descriptionText.opacity(0.40))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ── Centre divider ────────────────────────────
                    Rectangle()
                        .fill(themeManager.accent.opacity(0.18))
                        .frame(width: 1)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 12)

                    // ── Right: Partner ────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentBond.partner_nickname)
                            .font(.custom("Merriweather-Bold", size: 12))
                            .foregroundColor(themeManager.primaryText.opacity(0.70))
                            .lineLimit(1)

                        if let tag = partnerFocus, !tag.isEmpty {
                            Text(focusDisplayName(for: tag))
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.accent.opacity(0.80))
                                .lineLimit(1)
                        }
                        if !partnerKws.isEmpty {
                            keywordCapsules(partnerKws)
                        }
                        if let score = partnerScore, score > 0 {
                            starRow(score: score)
                        }
                        if !hasPartnerData {
                            Text(String(localized: "bonds.today_no_data"))
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.descriptionText.opacity(0.40))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .alignaCard()
        }
    }

    /// Shared-intents card: surfaces when both people share today's primary intent.
    private func sharedIntentsCard(_ c: CompatibilityResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "bonds.shared_intents_title"))
                .font(.custom("Merriweather-Regular", size: 11))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
                .tracking(1.4)
                .textCase(.uppercase)
            Text(c.shared_intents.map { intentLocalizedName(for: $0) }.joined(separator: " · "))
                .font(AlynnaTypography.font(.headline))
                .foregroundColor(themeManager.primaryText.opacity(0.88))
            Text(String(localized: "bonds.shared_intents_hint"))
                .font(AlynnaTypography.font(.caption1))
                .foregroundColor(themeManager.descriptionText.opacity(0.65))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alignaCard()
    }

    /// Compatibility breakdown — 4 rows with animated fill bars + values.
    private func breakdownCard(_ components: [String: Int]) -> some View {
        let order: [(String, String)] = [
            ("chart_resonance",   "bonds.component_chart"),
            ("intent_alignment",  "bonds.component_intent"),
            ("focus_proximity",   "bonds.component_focus"),
            ("score_proximity",   "bonds.component_score"),
        ]
        return VStack(alignment: .leading, spacing: 14) {
            // Title row + info button
            HStack {
                Text(String(localized: "bonds.breakdown_title"))
                    .font(.custom("Merriweather-Regular", size: 11))
                    .foregroundColor(themeManager.descriptionText.opacity(0.60))
                    .tracking(1.4)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    showBreakdownInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(themeManager.descriptionText.opacity(0.45))
                }
                .accessibilityLabel(Text(String(localized: "bonds.breakdown_info_label")))
            }
            ForEach(order, id: \.0) { key, localizationKey in
                if let value = components[key] {
                    let fraction = min(CGFloat(value) / 100.0, 1.0)
                    HStack(spacing: 10) {
                        Text(String(localized: String.LocalizationValue(localizationKey)))
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(themeManager.descriptionText.opacity(0.80))
                            .frame(width: 72, alignment: .leading)
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(themeManager.accent.opacity(0.10))
                                    .frame(height: 7)
                                // Fill — gradient so mid-values feel distinct from full
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.accent.opacity(0.50),
                                                themeManager.accent.opacity(0.85)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(7, geo.size.width * fraction), height: 7)
                            }
                        }
                        .frame(height: 7)
                        Text("\(value)")
                            .font(.custom("Merriweather-Bold", size: 13))
                            .foregroundColor(themeManager.primaryText.opacity(0.88))
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alignaCard()
        .sheet(isPresented: $showBreakdownInfo) {
            breakdownInfoSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    /// Half-sheet explaining each compatibility dimension.
    private var breakdownInfoSheet: some View {
        let items: [(String, String, String)] = [
            ("bonds.component_chart",  "chart.pie",         "bonds.component_chart_desc"),
            ("bonds.component_intent", "target",            "bonds.component_intent_desc"),
            ("bonds.component_focus",  "sparkles",          "bonds.component_focus_desc"),
            ("bonds.component_score",  "waveform.path.ecg", "bonds.component_score_desc"),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            // Handle + header
            HStack {
                Text(String(localized: "bonds.breakdown_info_title"))
                    .font(.custom("Merriweather-Bold", size: 16))
                    .foregroundColor(themeManager.primaryText)
                Spacer()
                Button { showBreakdownInfo = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(themeManager.descriptionText.opacity(0.40))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .background(themeManager.accent.opacity(0.15))
                .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        let (nameKey, icon, descKey) = item
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(themeManager.accent.opacity(0.80))
                                    .frame(width: 20)
                                Text(String(localized: String.LocalizationValue(nameKey)))
                                    .font(.custom("Merriweather-Bold", size: 13))
                                    .foregroundColor(themeManager.primaryText)
                            }
                            Text(String(localized: String.LocalizationValue(descKey)))
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(themeManager.descriptionText.opacity(0.75))
                                .lineSpacing(3)
                                .padding(.leading, 30)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)

                        if idx < items.count - 1 {
                            Divider()
                                .background(themeManager.accent.opacity(0.10))
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
        }
        .background(themeManager.panelFill.ignoresSafeArea())
    }

    // MARK: - Helpers

    /// Partner's focus tag. Uses the backend-resolved `partner_focus` field
    /// which is always the OTHER party from the caller's perspective. Falls
    /// back to the BondSummary snapshot for legacy compatibility.
    private func partnerFocusTag(_ c: CompatibilityResponse) -> String? {
        if let partner = c.partner_focus, !partner.isEmpty {
            return partner
        }
        if let fromList = currentBond.partner_focus_today, !fromList.isEmpty {
            return fromList
        }
        return nil
    }

    /// Partner's today keywords — uses backend-resolved `partner_keywords`.
    private func partnerKeywordList(_ c: CompatibilityResponse) -> [String]? {
        let resolved = c.partner_keywords ?? []
        return resolved.isEmpty ? nil : resolved
    }

    /// Partner's today daily_score — uses backend-resolved `partner_daily_score`.
    private func partnerDailyScore(_ c: CompatibilityResponse) -> Int? {
        c.partner_daily_score
    }

    private func starsForScore(_ score: Int) -> Int {
        let rounded = (Double(score) / 20.0).rounded()
        return min(5, max(0, Int(rounded)))
    }

    /// Display name for a focus tag, always in the current user's app language.
    /// Delegates to focusLocalizedName(for:) which uses the app's active locale,
    /// so the display is independent of the partner's language setting.
    private func focusDisplayName(for tag: String) -> String {
        let name = focusLocalizedName(for: tag)
        // focusLocalizedName returns the raw key unchanged for unknown tags — humanize as fallback.
        if name == tag {
            return tag.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return name
    }

    /// Translates intent family (e.g. "restore") into a short noun for UI.
    private func intentLocalizedName(for intent: String) -> String {
        let key = "bonds.intent.\(intent)"
        let localized = String(localized: String.LocalizationValue(key))
        if localized != key, !localized.isEmpty {
            return localized
        }
        return intent.capitalized
    }

    private func loadCompatibility() async {
        isLoading = true
        defer { isLoading = false }
        // Pass the client's LOCAL date so the backend looks up each user's
        // daily_recommendation doc under the same key the writer used
        // (daily docs are written by appDayKey = local tz). Without this, a
        // Cloud Run server in UTC may resolve "today" to a date for which no
        // user has yet generated a mantra, yielding empty partner fields.
        let localToday = DateFormatter.appDayKey.string(from: Date())
        do {
            compatibility = try await AlynnaAPI.shared.compatibility(
                bondId: bond.bond_id,
                date: localToday
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performSever(clearNow: Bool) async {
        isSeverInFlight = true
        defer { isSeverInFlight = false }
        do {
            try await AlynnaAPI.shared.severBond(bond.bond_id, clearHistoryImmediately: clearNow)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            await viewModel.refreshBonds()
            // Small pause so the user registers the action, then pop back.
            try? await Task.sleep(nanoseconds: 250_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
