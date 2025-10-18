//
//  Format.swift
//  GMJuice
//
//  Created by Andre Taube on 10/17/25.
//
import Foundation

class Format {
    static let twoDecimalPlaces: Decimal.FormatStyle = {
        var style = Decimal.FormatStyle.number
        style = style.precision(.fractionLength(2))
        return style
    }()
    
    static func formatTime(_ value: Decimal) -> String {
        return value.formatted(twoDecimalPlaces)
    }
}
