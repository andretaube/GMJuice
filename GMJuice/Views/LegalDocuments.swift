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

    Last Updated: November 2025

    Your privacy is important to us. This Privacy Policy explains how GMJuice handles your information.

    1. INFORMATION COLLECTION

    Local Data Storage:
    GMJuice stores your training data locally on your device using Apple's SwiftData framework. This includes:

    • Shot times and string runs
    • Stage and division information
    • Your shooter profile (classifications)
    • Performance statistics
    • App settings and preferences

    Your USPSA member number is stored locally on your device only and is NEVER transmitted to any external servers or analytics services.

    2. ANALYTICS FOR APP IMPROVEMENT

    To help us improve GMJuice, we use Firebase Analytics and Crashlytics (provided by Google). These services collect:

    • Anonymous usage data (which features are used, screen views)
    • App performance metrics (crash reports, errors)
    • Device information (device type, iOS version)
    • General location (country/region only, not precise location)
    • Aggregate statistics (number of log entries, divisions used) to help diagnose issues

    We DO NOT collect through analytics:
    • Your USPSA number or any personal identification numbers
    • Your actual shot times or training performance data
    • Your name, email, or contact information
    • Precise location data

    This analytics data helps us understand how the app is used so we can fix bugs and improve features. You cannot opt out of crash reporting as it is essential for app stability.

    3. THIRD-PARTY ACCESS

    We do not:
    • Share your personal training data with third parties
    • Sell your information to anyone
    • Display advertisements

    Firebase Analytics data is processed by Google according to their privacy policy. This data is used solely for app improvement and is not shared with other parties.

    4. BLUETOOTH USAGE

    GMJuice uses Bluetooth to connect to compatible shot timers (such as AMG devices). Bluetooth communication:

    • Occurs only between your device and your timer
    • Is not monitored or recorded by us
    • Remains local to your device
    • Does not transmit data over the internet

    5. LOCAL NOTIFICATIONS

    If you enable notifications, GMJuice may send local notifications to your device for:

    • Training reminders
    • Weekly performance summaries

    These notifications are generated locally on your device and do not involve external servers.

    6. DATA BACKUP

    Your training data may be included in your device's iCloud backup if you have iCloud backup enabled in your device settings. This is controlled by Apple's iCloud service and subject to Apple's privacy policy.

    You can manage iCloud backup settings in your device's Settings app.

    7. DATA DELETION

    You have complete control over your local data:

    • You can delete individual training sessions within the app
    • You can delete your entire history in the app settings
    • Uninstalling the app removes all locally stored data

    Note: Analytics data that has already been sent to Firebase cannot be deleted by uninstalling the app, but this data is anonymous and not linked to you personally.

    8. CHILDREN'S PRIVACY

    GMJuice is intended for use by adults. We do not knowingly collect information from children under 18. Given the nature of firearms training, this application should only be used by individuals legally permitted to handle firearms under applicable laws.

    9. YOUR RIGHTS

    For your local data, you have complete control over:

    • Accessing your data (view it anytime in the app)
    • Modifying your data (edit or delete records)
    • Exporting your data (CSV export available)
    • Deleting your data (delete individual sessions or uninstall the app)

    10. SECURITY

    Your data security depends on:

    • Your device's security (passcode, Face ID, Touch ID)
    • Your device's physical security
    • Your iCloud account security (if using iCloud backup)

    We recommend:
    • Keeping your device locked with a strong passcode
    • Enabling biometric authentication if available
    • Using a secure iCloud password

    11. CHANGES TO THIS POLICY

    We may update this Privacy Policy periodically. Changes will be reflected in the "Last Updated" date. Continued use of GMJuice after changes constitutes acceptance of the updated policy.

    12. CONTACT

    If you have questions about this Privacy Policy or how your data is handled, you can reach us through the app's support channels.

    13. COMPLIANCE

    This Privacy Policy is designed to comply with:

    • Apple App Store Review Guidelines
    • General Data Protection Regulation (GDPR) principles
    • California Consumer Privacy Act (CCPA) principles
    • Other applicable privacy regulations

    SUMMARY

    In plain language: Your training data (shot times, scores, etc.) stays on your device - we never see it. We do use anonymous analytics (Firebase) to understand how the app is used so we can make it better. We never collect your USPSA number or any information that identifies you personally.
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
