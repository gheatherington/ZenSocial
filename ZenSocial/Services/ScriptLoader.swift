import Foundation
import WebKit
import os

// MARK: - Notification Name

extension Notification.Name {
    static let zenScriptLoadFailure = Notification.Name("zenScriptLoadFailure")
}

// MARK: - ScriptLoader

@MainActor
enum ScriptLoader {

    private static let logger = Logger(
        subsystem: "com.zensocial.app",
        category: "ScriptLoader"
    )

    // MARK: - Public API

    /// Loads the platform-specific nav-fixer JS from the app bundle and returns a WKUserScript
    /// configured for injection at atDocumentEnd. The nav fixer uses getComputedStyle to find
    /// fixed/sticky elements that CSS selectors cannot target and forces dark backgrounds via
    /// el.style.setProperty, which overrides class-based styles that !important CSS cannot reach.
    ///
    /// Returns nil on failure (non-fatal — theme CSS still applies).
    static func navFixerScript(for platform: Platform) -> WKUserScript? {
        let filename = "nav-fixer"
        let subdirectory = "Scripts/\(platform.displayName)"

        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: "js",
            subdirectory: subdirectory
        ), let js = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        return WKUserScript(
            source: js,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }

    /// Loads the platform-specific dark theme CSS from the app bundle, wraps it in a JS IIFE,
    /// and returns a WKUserScript configured for injection at atDocumentStart.
    ///
    /// Returns nil on failure. In DEBUG builds, failure triggers assertionFailure immediately
    /// so misconfigured bundle resources are caught during development.
    static func themeScript(for platform: Platform) -> WKUserScript? {
        let filename = "theme"
        let subdirectory = "Scripts/\(platform.displayName)"

        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: "css",
            subdirectory: subdirectory
        ) else {
            handleLoadFailure(platform: platform, filename: "\(filename).css")
            return nil
        }

        guard let css = try? String(contentsOf: url, encoding: .utf8) else {
            handleLoadFailure(platform: platform, filename: "\(filename).css")
            return nil
        }

        let js = wrapCSSInJS(css)
        return WKUserScript(
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    // MARK: - Private Helpers

    /// Wraps raw CSS in a JavaScript IIFE that creates a <style> element and appends it to
    /// document.documentElement. Uses documentElement (not document.head) because head is null
    /// at atDocumentStart injection time.
    ///
    /// D-11: This JS is purely CSS injection. It does NOT touch navigator.serviceWorker,
    /// Notification, PushManager, or any service worker paths.
    private static func wrapCSSInJS(_ css: String) -> String {
        // Escape characters that would break a JS template literal
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        return """
        (function() {
            var s = document.createElement('style');
            s.id = 'zen-theme';
            s.textContent = `\(escaped)`;
            document.documentElement.appendChild(s);
        })();
        """
    }

    /// Handles a CSS file load failure.
    ///
    /// - D-09: In DEBUG builds, triggers assertionFailure with the expected bundle path so
    ///   misconfigured resources are caught immediately during development.
    /// - D-10: In Release builds, logs the error and posts a notification so callers can observe
    ///   the failure without crashing.
    private static func handleLoadFailure(platform: Platform, filename: String) {
        let expectedPath = "Scripts/\(platform.displayName)/\(filename)"

        #if DEBUG
        assertionFailure(
            "[ScriptLoader] Failed to load '\(filename)' for \(platform.displayName). "
            + "Ensure '\(expectedPath)' is added to the Xcode target's "
            + "Copy Bundle Resources build phase."
        )
        #else
        logger.error(
            "[ScriptLoader] Failed to load '\(filename, privacy: .public)' for "
            + "\(platform.displayName, privacy: .public). "
            + "Expected path in bundle: '\(expectedPath, privacy: .public)'."
        )
        NotificationCenter.default.post(
            name: .zenScriptLoadFailure,
            object: nil,
            userInfo: [
                "platform": platform.rawValue,
                "filename": filename
            ]
        )
        #endif
    }
}
