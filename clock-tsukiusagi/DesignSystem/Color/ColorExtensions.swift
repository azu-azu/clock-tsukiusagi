import SwiftUI
import UIKit

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        self = Color(UIColor(hex: hex))
    }
}

// MARK: - UIColor Extensions
extension UIColor {
    convenience init(hex: String) {
        var v = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if v.count == 3 {
            v = v.map { "\($0)\($0)" }.joined()
        }
        let scanner = Scanner(string: v)
        var num: UInt64 = 0
        scanner.scanHexInt64(&num)
        let r = CGFloat((num & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((num & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(num & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Double Extensions
extension Double {
    var radian: CGFloat {
        CGFloat(self * .pi / 180.0)
    }
}
