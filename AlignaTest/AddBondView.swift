import SwiftUI

// MARK: - AddBondView
//
// Two-step add flow:
//   1. User enters the other person's 8-digit Alynna number
//   2. On "查询", we call /users/lookup_by_number and show a minimal preview
//   3. On "发送请求", we call /bonds/request and bounce back to BondsView

struct AddBondView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @Environment(\.dismiss) private var dismiss
    @FocusState private var numberFieldFocused: Bool

    @State private var rawInput: String = ""
    @State private var preview: LookupNumberResponse?
    @State private var isLookingUp: Bool = false
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var normalizedDigits: String {
        rawInput.filter(\.isNumber)
    }

    private var isNumberComplete: Bool {
        normalizedDigits.count == 8
    }

    private var formattedInputDisplay: String {
        let digits = normalizedDigits
        if digits.count <= 4 { return digits }
        let mid = digits.index(digits.startIndex, offsetBy: 4)
        return "\(digits[..<mid]) \(digits[mid...])"
    }

    var body: some View {
        ZStack {
            AppBackgroundView(nightMotion: .animated)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    inputSection
                    if let preview {
                        previewCard(preview)
                        sendButton
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(.red.opacity(0.80))
                            .padding(.horizontal, 4)
                    }
                    if let ok = successMessage {
                        Text(ok)
                            .font(AlynnaTypography.font(.subheadline))
                            .foregroundColor(themeManager.accent)
                            .padding(.horizontal, 4)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 68)
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
        .onAppear {
            numberFieldFocused = true
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "bonds.add_title"))
                .font(AlynnaTypography.font(.title2))
                .foregroundColor(themeManager.primaryText)
            Text(String(localized: "bonds.enter_number_prompt"))
                .font(AlynnaTypography.font(.subheadline))
                .foregroundColor(themeManager.descriptionText.opacity(0.75))
        }
        .padding(.top, 8)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(
                    "00000000",
                    text: Binding(
                        get: { formattedInputDisplay },
                        set: { newValue in
                            // Accept only digits; cap at 8
                            let digits = newValue.filter(\.isNumber)
                            rawInput = String(digits.prefix(8))
                            // Any edit invalidates previous preview
                            if preview != nil { preview = nil }
                            errorMessage = nil
                            successMessage = nil
                        }
                    )
                )
                .font(.custom("Merriweather-Bold", size: 17))
                .foregroundColor(themeManager.primaryText)
                .keyboardType(.numberPad)
                .focused($numberFieldFocused)
                .monospacedDigit()
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.panelFill.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.panelStrokeHi.opacity(0.50), lineWidth: 1)
                )
            }

            Button {
                Task { await lookup() }
            } label: {
                HStack {
                    if isLookingUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.buttonForegroundOnPrimary))
                            .scaleEffect(0.8)
                    }
                    Text(String(localized: "bonds.lookup_button"))
                        .font(AlynnaTypography.font(.headline))
                }
                .foregroundColor(themeManager.buttonForegroundOnPrimary.opacity(isNumberComplete ? 0.90 : 0.40))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isNumberComplete
                            ? themeManager.accent.opacity(0.82)
                            : themeManager.accent.opacity(0.25))
                )
            }
            .buttonStyle(.plain)
            .disabled(!isNumberComplete || isLookingUp)
        }
    }

    private func previewCard(_ p: LookupNumberResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(themeManager.accent.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Text(p.nickname.first.map { String($0) } ?? "·")
                        .font(.custom("Merriweather-Bold", size: 22))
                        .foregroundColor(themeManager.accent.opacity(0.88))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(p.nickname)
                        .font(AlynnaTypography.font(.headline))
                        .foregroundColor(themeManager.primaryText)

                    HStack(spacing: 8) {
                        Text(String(
                            format: String(localized: "bonds.join_days"),
                            p.join_days
                        ))
                        .font(AlynnaTypography.font(.caption1))
                        .foregroundColor(themeManager.descriptionText.opacity(0.65))

                        if let sign = p.sun_sign {
                            Text("· \(sign.capitalized)")
                                .font(AlynnaTypography.font(.caption1))
                                .foregroundColor(themeManager.descriptionText.opacity(0.65))
                        }
                    }
                }
                Spacer()
            }

            Divider()
                .background(themeManager.panelStrokeHi.opacity(0.30))

            Text(String(localized: "bonds.privacy_warning"))
                .font(AlynnaTypography.font(.caption1))
                .foregroundColor(themeManager.descriptionText.opacity(0.70))
                .lineSpacing(2)
        }
        .padding(16)
        .alignaCard()
    }

    private var sendButton: some View {
        Button {
            Task { await sendRequest() }
        } label: {
            HStack {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.buttonForegroundOnPrimary))
                        .scaleEffect(0.8)
                }
                Text(String(localized: "bonds.send_request_button"))
                    .font(AlynnaTypography.font(.headline))
            }
            .foregroundColor(themeManager.buttonForegroundOnPrimary.opacity(0.90))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.accent.opacity(0.86))
            )
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    // MARK: - Actions

    private func lookup() async {
        numberFieldFocused = false
        errorMessage = nil
        successMessage = nil
        preview = nil

        // Guard: can't look up own number
        if normalizedDigits == viewModel.alynnaNumber {
            errorMessage = String(localized: "bonds.cannot_add_self")
            return
        }

        isLookingUp = true
        defer { isLookingUp = false }

        do {
            preview = try await AlynnaAPI.shared.lookupByNumber(normalizedDigits)
        } catch let api as AlynnaAPIError {
            switch api.httpStatusCode {
            case 404:
                errorMessage = String(localized: "bonds.number_not_found")
            case 400:
                errorMessage = api.errorDescription ?? String(localized: "bonds.lookup_failed")
            default:
                errorMessage = api.errorDescription ?? String(localized: "bonds.lookup_failed")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendRequest() async {
        errorMessage = nil
        successMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            _ = try await AlynnaAPI.shared.sendBondRequest(toNumber: normalizedDigits)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            successMessage = String(localized: "bonds.request_sent")
            await viewModel.refreshBonds()
            // Auto-dismiss after a short delay so user sees the success.
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch let api as AlynnaAPIError {
            switch api.httpStatusCode {
            case 404:
                errorMessage = String(localized: "bonds.number_not_found")
            case 409:
                errorMessage = api.errorDescription ?? String(localized: "bonds.cannot_send_now")
            case 400:
                errorMessage = api.errorDescription ?? String(localized: "bonds.cannot_send_now")
            default:
                errorMessage = api.errorDescription ?? String(localized: "bonds.send_failed")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
