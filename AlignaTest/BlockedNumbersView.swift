import SwiftUI

// MARK: - BlockedNumbersView
//
// Shows the list of Alynna numbers the user has blocked, with a per-row
// "Unblock" action. Reads the blocked list directly from Firestore (via
// OnboardingViewModel.loadBlockedNumbers) on appear. Unblocks go through
// the backend API so server-side rules run.
//
// Accessed from Profile → "已屏蔽的号".

struct BlockedNumbersView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var rowError: [String: String] = [:]
    @State private var pendingUnblock: String?    // number awaiting confirmation

    var body: some View {
        ZStack {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    if isLoading && viewModel.blockedNumbers.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accent))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if viewModel.blockedNumbers.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(viewModel.blockedNumbers, id: \.self) { number in
                                blockedRow(number)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 68)
            }
            .refreshable {
                await viewModel.loadBlockedNumbers()
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
            isLoading = true
            await viewModel.loadBlockedNumbers()
            isLoading = false
        }
        .confirmationDialog(
            String(localized: "blocked.confirm_unblock_title"),
            isPresented: Binding(
                get: { pendingUnblock != nil },
                set: { if !$0 { pendingUnblock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "blocked.unblock_confirm"), role: .destructive) {
                if let n = pendingUnblock {
                    Task { await performUnblock(n) }
                }
            }
            Button(String(localized: "blocked.unblock_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "blocked.confirm_unblock_body"))
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "profile.blocked_numbers_title"))
                .font(AlynnaTypography.font(.title2))
                .foregroundColor(themeManager.primaryText)
            Text(String(localized: "profile.blocked_numbers_subtitle"))
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.descriptionText.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised")
                .font(.system(size: 32))
                .foregroundColor(themeManager.descriptionText.opacity(0.40))
            Text(String(localized: "blocked.empty_state"))
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.descriptionText.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func blockedRow(_ number: String) -> some View {
        HStack(spacing: 12) {
            Text(number.alynnaNumberDisplay)
                .font(.custom("Merriweather-Bold", size: 22))
                .foregroundColor(themeManager.primaryText.opacity(0.88))
                .monospacedDigit()
                .tracking(3)

            Spacer()

            Button {
                pendingUnblock = number
            } label: {
                Text(String(localized: "blocked.unblock_button"))
                    .font(AlynnaTypography.font(.subheadline))
                    .foregroundColor(themeManager.accent.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.accent.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .alignaCard()
        .overlay(alignment: .bottom) {
            if let err = rowError[number] {
                Text(err)
                    .font(AlynnaTypography.font(.caption2))
                    .foregroundColor(.red.opacity(0.75))
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Actions

    private func performUnblock(_ number: String) async {
        rowError[number] = nil
        do {
            try await viewModel.unblockNumber(number)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch {
            rowError[number] = error.localizedDescription
        }
    }
}
