import Foundation

/// The newest release on GitHub. Only asked when someone chooses Check for
/// Updates, so RemoveMacAI otherwise makes no network requests.
///
/// Ventura variant: the fork's releases list is scanned newest-first for a
/// Ventura tag. The workflow marks Ventura builds pre-release (their tags
/// carry a dash), and GitHub's "latest" endpoint skips pre-releases, so
/// asking it would never find one.
enum Updates {
  static let latestURL = URL(string: "https://api.github.com/repos/Salcedoandrew/RemoveMacAI/releases?per_page=30")!
  static let releasesPage = URL(string: "https://github.com/Salcedoandrew/RemoveMacAI/releases")!

  struct Release {
    let version: String
    let page: URL
  }

  /// The newest Ventura release, or why it couldn't be read.
  static func latest() async -> Result<Release, Error> {
    var request = URLRequest(url: latestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      // A rate limit or outage still sends a body, so the status comes first.
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw UpdateError.status(http.statusCode)
      }
      guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        throw URLError(.cannotParseResponse)
      }
      guard let release = releases.first(where: { ($0["tag_name"] as? String)?.contains("ventura") == true }),
        let tag = release["tag_name"] as? String
      else { throw UpdateError.noVenturaRelease }
      let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
      guard isVersion(version) else { throw UpdateError.notAVersion(tag) }
      let page = (release["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage
      return .success(Release(version: version, page: page))
    } catch {
      return .failure(error)
    }
  }

  enum UpdateError: LocalizedError {
    case status(Int)
    case notAVersion(String)
    case noVenturaRelease

    var errorDescription: String? {
      switch self {
      case .status(403), .status(429): return "GitHub is limiting requests right now. Try again in a while."
      case .status(let code): return "GitHub answered with HTTP \(code)."
      case .notAVersion(let tag): return "The latest release is tagged \"\(tag)\", which isn't a version number."
      case .noVenturaRelease: return "No Ventura release found on GitHub yet."
      }
    }
  }

  /// Numbers separated by dots, optionally followed by a dash and a label, such as 1.2.0-beta.1.
  static func isVersion(_ v: String) -> Bool {
    v.range(of: #"^\d+(\.\d+)*(-[0-9A-Za-z.]+)?$"#, options: .regularExpression) != nil
  }

  /// Whether latest is newer than current. A beta comes before its release,
  /// so 1.2.0 is newer than 1.2.0-beta.1 and 1.1.4 is not.
  static func isNewer(_ latest: String, than current: String) -> Bool {
    func parts(_ v: String) -> (numbers: [Int], beta: String?) {
      let split = v.split(separator: "-", maxSplits: 1).map(String.init)
      return ((split.first ?? "").split(separator: ".").map { Int($0) ?? 0 }, split.count > 1 ? split[1] : nil)
    }
    let a = parts(latest), b = parts(current)
    for i in 0..<max(a.numbers.count, b.numbers.count) {
      let x = i < a.numbers.count ? a.numbers[i] : 0, y = i < b.numbers.count ? b.numbers[i] : 0
      if x != y { return x > y }
    }
    switch (a.beta, b.beta) {
    case (nil, nil): return false
    case (nil, _): return true
    case (_, nil): return false
    case (let x?, let y?): return x.compare(y, options: .numeric) == .orderedDescending
    }
  }
}
