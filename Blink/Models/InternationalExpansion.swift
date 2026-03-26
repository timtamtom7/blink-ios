import Foundation

// MARK: - International Expansion
// R18: Localization, Regional Pricing, Cultural Customization

/// Supported language
struct SupportedLanguage: Identifiable, Codable, Equatable {
    let id: UUID
    var code: String // e.g., "en", "es", "fr"
    var displayName: String
    var nativeName: String
    var isRTL: Bool
    var isSupported: Bool
    
    init(id: UUID = UUID(), code: String, displayName: String, nativeName: String, isRTL: Bool = false, isSupported: Bool = true) {
        self.id = id
        self.code = code
        self.displayName = displayName
        self.nativeName = nativeName
        self.isRTL = isRTL
        self.isSupported = isSupported
    }
    
    static let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "en", displayName: "English", nativeName: "English"),
        SupportedLanguage(code: "es", displayName: "Spanish", nativeName: "Español"),
        SupportedLanguage(code: "fr", displayName: "French", nativeName: "Français"),
        SupportedLanguage(code: "de", displayName: "German", nativeName: "Deutsch"),
        SupportedLanguage(code: "it", displayName: "Italian", nativeName: "Italiano"),
        SupportedLanguage(code: "pt", displayName: "Portuguese", nativeName: "Português"),
        SupportedLanguage(code: "ja", displayName: "Japanese", nativeName: "日本語"),
        SupportedLanguage(code: "ko", displayName: "Korean", nativeName: "한국어"),
        SupportedLanguage(code: "zh-Hans", displayName: "Chinese (Simplified)", nativeName: "简体中文"),
        SupportedLanguage(code: "ar", displayName: "Arabic", nativeName: "العربية", isRTL: true),
        SupportedLanguage(code: "he", displayName: "Hebrew", nativeName: "עברית", isRTL: true)
    ]
}

/// Regional pricing configuration
struct RegionalPricing: Identifiable, Codable, Equatable {
    let id: UUID
    var regionCode: String // e.g., "US", "IN", "BR"
    var regionName: String
    var currencyCode: String
    var currencySymbol: String
    var pppMultiplier: Double // Purchasing power parity adjustment
    var adjustedPrices: [String: Decimal] // tier name -> adjusted price
    
    init(id: UUID = UUID(), regionCode: String, regionName: String, currencyCode: String, currencySymbol: String, pppMultiplier: Double = 1.0, adjustedPrices: [String: Decimal] = [:]) {
        self.id = id
        self.regionCode = regionCode
        self.regionName = regionName
        self.currencyCode = currencyCode
        self.currencySymbol = currencySymbol
        self.pppMultiplier = pppMultiplier
        self.adjustedPrices = adjustedPrices
    }
    
    static let defaultRegions: [RegionalPricing] = [
        RegionalPricing(regionCode: "US", regionName: "United States", currencyCode: "USD", currencySymbol: "$", pppMultiplier: 1.0, adjustedPrices: ["memories": 4.99, "archive": 9.99, "family": 14.99]),
        RegionalPricing(regionCode: "IN", regionName: "India", currencyCode: "INR", currencySymbol: "₹", pppMultiplier: 0.15, adjustedPrices: ["memories": 149, "archive": 299, "family": 449]),
        RegionalPricing(regionCode: "BR", regionName: "Brazil", currencyCode: "BRL", currencySymbol: "R$", pppMultiplier: 0.35, adjustedPrices: ["memories": 14.9, "archive": 29.9, "family": 44.9]),
        RegionalPricing(regionCode: "GB", regionName: "United Kingdom", currencyCode: "GBP", currencySymbol: "£", pppMultiplier: 0.85, adjustedPrices: ["memories": 3.99, "archive": 7.99, "family": 11.99]),
        RegionalPricing(regionCode: "DE", regionName: "Germany", currencyCode: "EUR", currencySymbol: "€", pppMultiplier: 0.95, adjustedPrices: ["memories": 4.49, "archive": 8.99, "family": 13.49]),
        RegionalPricing(regionCode: "JP", regionName: "Japan", currencyCode: "JPY", currencySymbol: "¥", pppMultiplier: 0.8, adjustedPrices: ["memories": 490, "archive": 980, "family": 1480]),
    ]
}

/// Cultural holiday highlight
struct CulturalHoliday: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var regionCode: String
    var date: Date
    var highlightTemplate: String
    var isEnabled: Bool
    
    init(id: UUID = UUID(), name: String, regionCode: String, date: Date, highlightTemplate: String = "Memory Highlight", isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.regionCode = regionCode
        self.date = date
        self.highlightTemplate = highlightTemplate
        self.isEnabled = isEnabled
    }
    
    static let defaultHolidays: [CulturalHoliday] = [
        CulturalHoliday(name: "Diwali", regionCode: "IN", date: Date(), highlightTemplate: "Festival of Lights"),
        CulturalHoliday(name: "Lunar New Year", regionCode: "CN", date: Date(), highlightTemplate: "New Year Celebration"),
        CulturalHoliday(name: "Ramadan", regionCode: "SA", date: Date(), highlightTemplate: "Ramadan Mubarak"),
        CulturalHoliday(name: "Hanukkah", regionCode: "IL", date: Date(), highlightTemplate: "Festival of Lights"),
        CulturalHoliday(name: "Carnival", regionCode: "BR", date: Date(), highlightTemplate: "Carnival Celebration"),
    ]
}

/// App Store optimization per locale
struct LocaleAppStoreConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var localeCode: String
    var appStoreCountry: String
    var keywords: [String]
    var descriptionOverride: String?
    var screenshotCaptions: [String]
    var previewVideoURL: String?
    
    init(id: UUID = UUID(), localeCode: String, appStoreCountry: String, keywords: [String] = [], descriptionOverride: String? = nil, screenshotCaptions: [String] = [], previewVideoURL: String? = nil) {
        self.id = id
        self.localeCode = localeCode
        self.appStoreCountry = appStoreCountry
        self.keywords = keywords
        self.descriptionOverride = descriptionOverride
        self.screenshotCaptions = screenshotCaptions
        self.previewVideoURL = previewVideoURL
    }
}
