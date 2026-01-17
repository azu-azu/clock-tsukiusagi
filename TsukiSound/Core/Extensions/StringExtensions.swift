import Foundation

// MARK: - String Extensions for Localization
extension String {
    /// Localized string using app's language setting
    var localized: String {
        let languageCode = LanguageProvider.shared.language.resolvedLanguageCode
        return localized(forLanguage: languageCode)
    }

    /// Localized string for a specific language (or system default if nil)
    func localized(forceLanguage: String?) -> String {
        if let language = forceLanguage {
            return localized(forLanguage: language)
        }
        // Use system language (bypass LanguageProvider)
        return NSLocalizedString(self, comment: "")
    }

    /// Internal: Get localized string for specific language code
    private func localized(forLanguage languageCode: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to default localization
            return NSLocalizedString(self, comment: "")
        }
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}