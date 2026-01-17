//
//  AppLanguage.swift
//  TsukiSound
//
//  App language setting with system/manual override support
//

import SwiftUI

// MARK: - AppLanguage Enum

/// App language options
public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"  // Follow device settings
    case ja = "ja"          // Japanese
    case en = "en"          // English

    public var id: String { rawValue }

    /// UserDefaults key for persistence
    public static let userDefaultsKey = "appLanguage"

    /// Display name for settings UI
    public var displayName: String {
        switch self {
        case .system:
            return "settings.language.system".localized(forceLanguage: nil)
        case .ja:
            return "日本語"
        case .en:
            return "English"
        }
    }

    /// Resolve to actual language code (ja or en)
    public var resolvedLanguageCode: String {
        switch self {
        case .system:
            // Get device's preferred language
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.hasPrefix("ja") {
                return "ja"
            } else {
                return "en"
            }
        case .ja:
            return "ja"
        case .en:
            return "en"
        }
    }
}

// MARK: - Language Provider

/// Provides app language setting across the app
public class LanguageProvider: ObservableObject {
    /// Shared singleton instance
    public static let shared = LanguageProvider()

    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.userDefaultsKey)
        }
    }

    private init() {
        // Load from UserDefaults
        if let rawValue = UserDefaults.standard.string(forKey: AppLanguage.userDefaultsKey),
           let savedLanguage = AppLanguage(rawValue: rawValue) {
            self.language = savedLanguage
        } else {
            self.language = .system
        }

        // Observe UserDefaults changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange() {
        if let rawValue = UserDefaults.standard.string(forKey: AppLanguage.userDefaultsKey),
           let newLanguage = AppLanguage(rawValue: rawValue),
           newLanguage != language {
            DispatchQueue.main.async {
                self.language = newLanguage
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
