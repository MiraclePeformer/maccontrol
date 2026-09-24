import AppKit

/// Lists installed web browsers and reads/sets the system default handler for
/// http/https. Setting the default triggers a macOS confirmation dialog — the
/// system does not allow changing it silently.
final class BrowserController {
    struct Browser: Identifiable, Equatable {
        let url: URL
        let name: String
        var id: String { url.path }
    }

    private let probeURL = URL(string: "https://www.apple.com")!

    func browsers() -> [Browser] {
        guard #available(macOS 12.0, *) else { return [] }
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
            .compactMap { url -> Browser? in
                guard seen.insert(url.path).inserted else { return nil }
                return Browser(url: url, name: displayName(for: url))
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func currentDefaultPath() -> String? {
        NSWorkspace.shared.urlForApplication(toOpen: probeURL)?.path
    }

    /// Sets the default handler for both https and http. macOS will ask the
    /// user to confirm. `completion` runs on the main queue.
    func setDefault(_ browser: Browser, completion: @escaping (Error?) -> Void) {
        guard #available(macOS 12.0, *) else { completion(nil); return }
        let workspace = NSWorkspace.shared
        workspace.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: "https") { httpsError in
            workspace.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: "http") { httpError in
                DispatchQueue.main.async { completion(httpsError ?? httpError) }
            }
        }
    }

    private func displayName(for url: URL) -> String {
        if let bundle = Bundle(url: url),
           let name = (bundle.infoDictionary?["CFBundleName"] as? String)
                   ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String) {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
