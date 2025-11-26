import Foundation

// MARK: - String Extensions for Localization
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}