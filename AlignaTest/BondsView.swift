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

    @State private var isRefreshing: Bool = false
    @State private var rowError: [String: String] = [:]  // bondId/requestId → message

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
                    .padding(.top, 16)
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
                .disabled(viewModel.alynnaNumber.isEmpty)
                .opacity(viewModel.alynnaNumber.isEmpty ? 0.5 : 1.0)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    BlockedNumbersView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .environmentObject(starManager)
                } label: {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(themeManager.descriptionText.opacity(0.65))
                }
                .accessibilityLabel(Text(String(localized: "profile.blocked_numbers_title")))
            }
        }
        .task {
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "bonds.section_title"))
                .font(AlynnaTypography.font(.largeTitle))
                .foregroundColor(themeManager.primaryText)
            Text(String(
                format: String(localized: "bonds.max_hint"),
                2  // matches backend _MAX_BONDS_PER_USER
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
                VStack(spacing: 20) {
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
                    .padding(.top, 28)

                    // Compatibility
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
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .alignaCard()
                    .padding(.horizontal, 20)

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
                    .disabled(isSeverInFlight)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
