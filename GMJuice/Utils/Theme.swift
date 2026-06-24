//
//  Theme.swift
//  GMJuice
//
//  Dark "tactical / instrument panel" design system (matches design/app-prototype.html).
//  Custom fonts (Saira / JetBrains Mono / IBM Plex Sans) are approximated with system
//  fonts: uppercase-tracked labels, monospaced digits for data. Swap in bundled .ttf later.
//

import SwiftUI

// MARK: - Color tokens

extension Color {
    init(gmHex hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }

    static let gmBg      = Color(gmHex: 0x070A0C)   // page
    static let gmScreen  = Color(gmHex: 0x0D1115)   // screen
    static let gmPanel   = Color(gmHex: 0x141A1F)   // card
    static let gmPanel2  = Color(gmHex: 0x10161A)
    static let gmRaised  = Color(gmHex: 0x1A2127)
    static let gmLine    = Color(gmHex: 0x222C33)

    static let gmInk     = Color(gmHex: 0xE7ECEF)
    static let gmInk2    = Color(gmHex: 0x9AA6AD)
    static let gmInk3    = Color(gmHex: 0x5D6970)

    static let gmAmber   = Color(gmHex: 0xF4A23A)   // brand / peak
    static let gmGreen   = Color(gmHex: 0x43C06A)   // at class
    static let gmRed     = Color(gmHex: 0xE5544B)   // worst / penalty
    static let gmSteel   = Color(gmHex: 0x5E9BB0)   // A class
}

// MARK: - Class → color

extension ShooterClass {
    var gmColor: Color {
        switch self {
        case .GM, .M: return .gmAmber
        case .A:      return .gmSteel
        case .B, .C:  return .gmGreen
        default:      return .gmInk2
        }
    }
}

// MARK: - Reusable text styles

struct GMLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Color.gmInk3)
    }
}

extension Text {
    /// Tabular monospaced figures for times/data.
    func gmMono() -> some View { self.monospacedDigit() }
}

// MARK: - Panel container

struct GMPanel<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(Color.gmPanel)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.gmLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Class badge

struct GMClassBadge: View {
    let cls: ShooterClass
    var percent: Int? = nil
    var body: some View {
        let text = percent.map { "\(cls.rawValue) \($0)%" } ?? cls.rawValue
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.5)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(cls == .GM ? Color(gmHex: 0x1A1205) : cls.gmColor)
            .background(cls == .GM ? Color.gmAmber : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(cls == .GM ? Color.clear : cls.gmColor.opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - View helpers

extension View {
    /// Dark gunmetal background for List/Form-based screens.
    func gmScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.gmBg.ignoresSafeArea())
    }
}
