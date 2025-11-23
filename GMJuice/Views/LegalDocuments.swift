import SwiftUI

// MARK: - Legal Document Content

struct LegalDocuments {
    static let termsOfUse = """
    TERMS OF USE

    Last Updated: January 2025

    IMPORTANT - READ CAREFULLY

    By using GMJuice, you acknowledge and agree to the following terms and conditions:

    1. TRAINING PURPOSES ONLY

    GMJuice is designed solely as a training tool for competitive Steel Challenge shooting practice. This application is NOT a substitute for proper firearms training, safety instruction, or professional coaching.

    2. INDEPENDENCE AND NON-AFFILIATION

    GMJuice is an INDEPENDENT training application and is NOT affiliated with, endorsed by, or connected to:

    • The United States Practical Shooting Association (USPSA)
    • Steel Challenge Shooting Association (SCSA)  
    • Any official shooting organizations or sanctioning bodies

    This application uses publicly available information about Steel Challenge stages and classifications for training purposes only. All stage names, classifications, and benchmark data are used in accordance with fair use principles for educational and training purposes.

    The use of terms like "Steel Challenge," "USPSA," and related terminology is for descriptive purposes only to help users understand the context of their training. No endorsement, sponsorship, or official relationship is implied.

    For official rules, classifications, and sanctioned competitions, please refer to the official USPSA and SCSA websites and organizations.

    3. USER RESPONSIBILITY

    YOU are solely responsible for:

    • Following ALL local, state, and federal laws regarding firearms possession, use, and transportation
    • Complying with all range rules and regulations
    • Maintaining safe firearm handling practices at all times
    • Ensuring you have proper permits and licenses as required by law
    • Your own safety and the safety of others around you

    4. FIREARMS SAFETY REQUIREMENTS

    Before using this application with live firearms, you MUST:

    • Complete formal firearms safety training from a certified instructor
    • Understand and follow the four fundamental firearm safety rules:
      1. Treat every firearm as if it is loaded
      2. Never point a firearm at anything you are not willing to destroy
      3. Keep your finger off the trigger until ready to shoot
      4. Know your target and what is beyond it
    • Use appropriate eye and ear protection
    • Use this application only in approved shooting ranges or safe training environments
    • Never handle firearms while impaired or distracted

    5. NO LIABILITY

    The developers and distributors of GMJuice assume NO LIABILITY for:

    • Any injuries, damages, or losses resulting from firearm use
    • Misuse of firearms or unsafe handling practices
    • Violation of laws or regulations
    • Equipment malfunctions or timer inaccuracies
    • Any consequences of using this application

    6. EQUIPMENT DISCLAIMER

    While GMJuice attempts to provide accurate timing and shot detection, we make NO GUARANTEES regarding:

    • Timing accuracy
    • Shot detection reliability
    • Bluetooth connectivity stability
    • Compatibility with all devices

    Always verify equipment is functioning properly before use.

    7. GET PROFESSIONAL TRAINING

    We STRONGLY RECOMMEND that all users:

    • Seek formal instruction from certified firearms instructors
    • Join established shooting clubs and organizations
    • Participate in supervised competitive shooting events
    • Continuously practice safe handling and proper technique

    8. ACCEPTANCE

    By using GMJuice, you acknowledge that you have read, understood, and agree to comply with these terms. You accept full responsibility for safe firearms handling and legal compliance.

    9. MODIFICATIONS

    We reserve the right to modify these terms at any time. Continued use of the application constitutes acceptance of modified terms.

    IF YOU DO NOT AGREE TO THESE TERMS, DO NOT USE THIS APPLICATION.

    Stay safe and shoot straight.
    """

    static let privacyPolicy = """
    PRIVACY POLICY

    Last Updated: January 2025

    Your privacy is important to us. This Privacy Policy explains how GMJuice handles your information.

    1. INFORMATION COLLECTION

    Data Storage:
    GMJuice stores all your training data locally on your device using Apple's SwiftData framework. This includes:

    • Shot times and string runs
    • Stage and division information
    • Your shooter profile (USPSA number, classifications)
    • Performance statistics and analytics
    • App settings and preferences

    No Remote Collection:
    We DO NOT collect, transmit, or store any of your data on external servers. All data remains on your device.

    2. THIRD-PARTY ACCESS

    We do not:
    • Share your data with third parties
    • Sell your information to anyone
    • Use analytics or tracking services
    • Display advertisements

    3. BLUETOOTH USAGE

    GMJuice uses Bluetooth to connect to compatible shot timers (such as AMG devices). Bluetooth communication:

    • Occurs only between your device and your timer
    • Is not monitored or recorded by us
    • Remains local to your device
    • Does not transmit data over the internet

    4. LOCAL NOTIFICATIONS

    If you enable notifications, GMJuice may send local notifications to your device for:

    • Training reminders
    • Weekly performance summaries

    These notifications are generated locally on your device and do not involve external servers.

    5. DATA BACKUP

    Your training data may be included in your device's iCloud backup if you have iCloud backup enabled in your device settings. This is controlled by Apple's iCloud service and subject to Apple's privacy policy.

    You can manage iCloud backup settings in your device's Settings app.

    6. DATA DELETION

    You have complete control over your data:

    • You can delete individual training sessions within the app
    • You can delete your entire history in the app settings
    • Uninstalling the app removes all locally stored data

    7. CHILDREN'S PRIVACY

    GMJuice is intended for use by adults. We do not knowingly collect information from children under 18. Given the nature of firearms training, this application should only be used by individuals legally permitted to handle firearms under applicable laws.

    8. YOUR RIGHTS

    Since all data is stored locally on your device, you have complete control over:

    • Accessing your data (view it anytime in the app)
    • Modifying your data (edit or delete records)
    • Exporting your data (not currently implemented, but data remains accessible on your device)
    • Deleting your data (delete individual sessions or uninstall the app)

    9. SECURITY

    Your data security depends on:

    • Your device's security (passcode, Face ID, Touch ID)
    • Your device's physical security
    • Your iCloud account security (if using iCloud backup)

    We recommend:
    • Keeping your device locked with a strong passcode
    • Enabling biometric authentication if available
    • Using a secure iCloud password

    10. CHANGES TO THIS POLICY

    We may update this Privacy Policy periodically. Changes will be reflected in the "Last Updated" date. Continued use of GMJuice after changes constitutes acceptance of the updated policy.

    11. FUTURE DATA COLLECTION

    Should we decide to collect any data in the future (such as optional cloud sync, leaderboards, or analytics), we will:

    • Update this Privacy Policy with clear explanations
    • Request your explicit consent
    • Provide opt-in/opt-out controls
    • Notify you of changes through the app

    12. CONTACT

    If you have questions about this Privacy Policy or how your data is handled, you can reach us through the app's support channels.

    13. COMPLIANCE

    This Privacy Policy is designed to comply with:

    • Apple App Store Review Guidelines
    • General Data Protection Regulation (GDPR) principles
    • California Consumer Privacy Act (CCPA) principles
    • Other applicable privacy regulations

    Since we do not collect your data, many regulatory requirements do not apply. However, we are committed to transparency and giving you control over your information.

    SUMMARY

    In plain language: GMJuice stores your training data on your device only. We don't collect it, we don't see it, we don't share it. It's all yours, stored locally, and under your control.
    """
}

// MARK: - Document Display View

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.system(size: 14))
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - First Launch Acceptance View

struct TermsAcceptanceView: View {
    @Binding var isPresented: Bool
    @State private var hasScrolledToBottom = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text("Welcome to GMJuice")
                        .font(.title.bold())

                    Text("Please read and accept the Terms of Use")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                Divider()

                // Terms Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(LegalDocuments.termsOfUse)
                            .font(.system(size: 14))

                        // Bottom marker
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .named("scroll")).minY) { _, newValue in
                                    // When bottom marker is visible (within scroll view bounds)
                                    if newValue < UIScreen.main.bounds.height {
                                        hasScrolledToBottom = true
                                    }
                                }
                        }
                        .frame(height: 1)
                    }
                    .padding()
                }
                .coordinateSpace(name: "scroll")

                Divider()

                // Accept Button
                VStack(spacing: 12) {
                    if !hasScrolledToBottom {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Please scroll to the bottom to continue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        acceptTerms()
                    } label: {
                        Text("I Accept the Terms of Use")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasScrolledToBottom ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!hasScrolledToBottom)

                    NavigationLink {
                        LegalDocumentView(
                            title: "Privacy Policy",
                            content: LegalDocuments.privacyPolicy
                        )
                    } label: {
                        Text("View Privacy Policy")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
            }
            .interactiveDismissDisabled()
        }
    }

    private func acceptTerms() {
        UserDefaults.standard.set(true, forKey: "hasAcceptedTerms")
        UserDefaults.standard.set(Date(), forKey: "termsAcceptedDate")
        isPresented = false
    }
}

#Preview("Terms Acceptance") {
    TermsAcceptanceView(isPresented: .constant(true))
}

#Preview("Terms Document") {
    LegalDocumentView(
        title: "Terms of Use",
        content: LegalDocuments.termsOfUse
    )
}

#Preview("Privacy Document") {
    LegalDocumentView(
        title: "Privacy Policy",
        content: LegalDocuments.privacyPolicy
    )
}
