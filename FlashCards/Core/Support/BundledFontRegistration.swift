//
//  BundledFontRegistration.swift
//  FlashCards
//

import CoreText
import Foundation

enum BundledFontRegistration {
    private static var didRegister = false

    /// Registers bundled `.ttf` / `.otf` once per process. Xcode often copies fonts to the bundle **root** as well as under `Resources/Fonts`, so we check every common location.
    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        let extensions = ["ttf", "otf"]
        let subdirectories: [String?] = ["Resources/Fonts", "Fonts", nil]
        var seenPaths = Set<String>()
        var urls: [URL] = []

        for ext in extensions {
            for subdir in subdirectories {
                let batch = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdir) ?? []
                urls.append(contentsOf: batch)
            }
        }

        for url in urls {
            let path = url.path
            guard seenPaths.insert(path).inserted else { continue }
            let ext = url.pathExtension.lowercased()
            guard ext == "ttf" || ext == "otf" else { continue }

            var error: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
