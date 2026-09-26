import CoreText
import Foundation

/// Registers the fonts bundled in Core.framework. The app and each extension
/// are separate processes, so each calls this once at launch.
public enum FontRegistry {
    public static func registerAll() {
        _ = registration
    }

    private static let registration: Void = {
        let bundle = Bundle(for: BundleToken.self)
        for url in bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}

private final class BundleToken {}
