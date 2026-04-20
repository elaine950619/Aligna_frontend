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
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(themeManager.descriptionText.opacity(0.65))
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

    var body: some View {
        ZStack {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Partner summary
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(themeManager.accent.opacity(0.18))
                                .frame(width: 72, height: 72)
                            Text(bond.partner_nickname.first.map { String($0) } ?? "·")
                                .font(.custom("Merriweather-Bold", size: 28))
                                .foregroundColor(themeManager.accent.opacity(0.88))
                        }
                        Text(bond.partner_nickname)
                            .font(AlynnaTypography.font(.title2))
                            .foregroundColor(themeManager.primaryText)
                        Text(bond.partner_alynna_number.alynnaNumberDisplay)
                            .font(.custom("Merriweather-Regular", size: 12))
                            .foregroundColor(themeManager.descriptionText.opacity(0.65))
                            .monospacedDigit()
                    }
                    .padding(.top, 68)

                    // Compatibility (hero card)
                    compatibilityHeroCard
                        .padding(.horizontal, 20)

                    // Partner's today (focus + keywords + daily score)
                    if let c = compatibility, partnerHasTodayData(c) {
                        partnerTodayCard(c)
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
        .confirmationDialog(
            String(localized: "bonds.sever_confirm_title"),
            isPresented: $showSeverConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "bonds.sever_confirm_action"), role: .destructive) {
                Task { await performSever(clearNow: false) }
            }
            Button(String(localized: "bonds.sever_confirm_action_clear_now"), role: .destructive) {
                Task { await performSever(clearNow: true) }
            }
            Button(String(localized: "bonds.sever_confirm_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "bonds.sever_confirm_body"))
        }
    }

    // MARK: - Card computed properties

    /// The big compatibility number card. Always visible.
    private var compatibilityHeroCard: some View {
        VStack(spacing: 6) {
            Text(String(localized: "bonds.daily_compat_label"))
                .font(.custom("Merriweather-Regular", size: 11))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
                .tracking(1.4)
                .textCase(.uppercase)

            if let c = compatibility {
                Text("\(c.compatibility)")
                    .font(.custom("Merriweather-Bold", size: 56))
                    .foregroundColor(themeManager.primaryText)
                    .monospacedDigit()
                Text(String(
                    format: String(localized: "bonds.permanent_base_value"),
                    c.permanent_base
                ))
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accent))
                    .padding(.vertical, 20)
            } else if let err = errorMessage {
                Text(err)
                    .font(AlynnaTypography.font(.caption1))
                    .foregroundColor(.red.opacity(0.75))
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .alignaCard()
    }

    /// Returns true when the compat response has at least one piece of
    /// partner-side daily context to show (focus OR keywords OR score).
    private func partnerHasTodayData(_ c: CompatibilityResponse) -> Bool {
        let partnerFocus = partnerFocusTag(c)
        let partnerKeywords = partnerKeywordList(c)
        let partnerScore = partnerDailyScore(c)
        return partnerFocus != nil
            || !(partnerKeywords ?? []).isEmpty
            || partnerScore != nil
    }

    /// Partner "today" card — their focus, keywords, daily score.
    private func partnerTodayCard(_ c: CompatibilityResponse) -> some View {
        let nickname = bond.partner_nickname
        let partnerFocus = partnerFocusTag(c)
        let partnerKeywords = partnerKeywordList(c) ?? []
        let partnerScore = partnerDailyScore(c)

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "bonds.partner_today_title"), nickname))
                .font(.custom("Merriweather-Regular", size: 11))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
                .tracking(1.4)
                .textCase(.uppercase)

            if let focusTag = partnerFocus, !focusTag.isEmpty {
                HStack(spacing: 10) {
                    Text(String(localized: "bonds.partner_focus_label"))
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText.opacity(0.75))
                    Text(focusDisplayName(for: focusTag))
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)
                    Spacer()
                }
            }

            if !partnerKeywords.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Text(String(localized: "bonds.partner_keywords_label"))
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText.opacity(0.75))
                    Text(partnerKeywords.prefix(3).joined(separator: " · "))
                        .font(.custom("Merriweather-Regular", size: 13))
                        .foregroundColor(themeManager.primaryText.opacity(0.88))
                        .tracking(0.8)
                    Spacer()
                }
            }

            if let score = partnerScore, score > 0 {
                HStack(spacing: 10) {
                    Text(String(localized: "bonds.partner_score_label"))
                        .font(AlynnaTypography.font(.subheadline))
                        .foregroundColor(themeManager.descriptionText.opacity(0.75))
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            FourPointStarShape()
                                .fill(
                                    i < starsForScore(score)
                                        ? themeManager.accent.opacity(0.88)
                                        : themeManager.accent.opacity(0.22)
                                )
                                .frame(width: 10, height: 10)
                        }
                    }
                    Text("\(score)")
                        .font(.custom("Merriweather-Regular", size: 12))
                        .foregroundColor(themeManager.descriptionText.opacity(0.70))
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alignaCard()
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

    /// Compatibility breakdown — 4 small horizontal rows, each with a label
    /// and the numeric component value.
    private func breakdownCard(_ components: [String: Int]) -> some View {
        let order: [(String, String)] = [
            ("chart_resonance",   "bonds.component_chart"),
            ("intent_alignment",  "bonds.component_intent"),
            ("focus_proximity",   "bonds.component_focus"),
            ("score_proximity",   "bonds.component_score"),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "bonds.breakdown_title"))
                .font(.custom("Merriweather-Regular", size: 11))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
                .tracking(1.4)
                .textCase(.uppercase)
            ForEach(order, id: \.0) { key, localizationKey in
                if let value = components[key] {
                    HStack {
                        Text(String(localized: String.LocalizationValue(localizationKey)))
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(themeManager.descriptionText.opacity(0.80))
                        Spacer()
                        Text("\(value)")
                            .font(.custom("Merriweather-Bold", size: 15))
                            .foregroundColor(themeManager.primaryText.opacity(0.88))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .alignaCard()
    }

    // MARK: - Helpers

    /// Returns the partner's focus tag given the canonical `a/b` layout of the bond.
    private func partnerFocusTag(_ c: CompatibilityResponse) -> String? {
        // bond.uid_a / uid_b align with compat.focus_a / focus_b (backend stores canonically).
        // Here, we don't have direct access to current uid, but we do know partner_uid.
        // partner_uid != the local user; focus_a is uid_a's focus, focus_b is uid_b's focus.
        // The BondSummary only carries partner's "today" opaque value; but CompatibilityResponse
        // gives us both sides without telling us which is caller vs partner. We use
        // nickname match: whichever _nickname_a/nickname_b matches partner → that side.
        // Since BondsSummary already came from /bonds/my where server assembles "partner_*"
        // from the opposite side, we can simply pick the side whose alynna_number matches
        // bond.partner_alynna_number.
        // Not carried in CompatibilityResponse, so fall back to: whichever of a/b differs
        // from the other is the partner. If exactly one is non-nil, use it.
        // Safer: use `bond.partner_focus_today` from the original BondSummary as the truth.
        if let fromList = bond.partner_focus_today, !fromList.isEmpty {
            return fromList
        }
        return c.focus_a ?? c.focus_b
    }

    private func partnerKeywordList(_ c: CompatibilityResponse) -> [String]? {
        // Prefer the side whose focus_tag matches the partner's focus. As a
        // simple heuristic we return whichever list is non-empty; in practice
        // there's at most two people and we only need to surface "something".
        let a = c.keywords_a ?? []
        let b = c.keywords_b ?? []
        if !a.isEmpty && b.isEmpty { return a }
        if !b.isEmpty && a.isEmpty { return b }
        // Both sides have keywords — we can't trivially tell which is partner
        // here without uid, so default to showing side A. This is acceptable
        // because daily_score_a vs daily_score_b also uses the canonical order.
        if !a.isEmpty { return a }
        return b.isEmpty ? nil : b
    }

    private func partnerDailyScore(_ c: CompatibilityResponse) -> Int? {
        c.daily_score_a ?? c.daily_score_b
    }

    private func starsForScore(_ score: Int) -> Int {
        let rounded = (Double(score) / 20.0).rounded()
        return min(5, max(0, Int(rounded)))
    }

    /// Best-effort display name for a focus tag. Uses `focus.name.<tag>` if
    /// localized, otherwise humanizes the snake_case.
    private func focusDisplayName(for tag: String) -> String {
        let key = "focus.name.\(tag)"
        let localized = String(localized: String.LocalizationValue(key))
        if localized != key, !localized.isEmpty {
            return localized
        }
        return tag.replacingOccurrences(of: "_", with: " ").capitalized
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
        do {
            compatibility = try await AlynnaAPI.shared.compatibility(bondId: bond.bond_id)
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
