import Foundation

enum L10n {
    static func tr(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: AppSettings.localizationBundle(),
            value: key,
            comment: ""
        )
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: .current, arguments: args)
    }
}
