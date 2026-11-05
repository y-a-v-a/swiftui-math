import Foundation

private final class BundleToken {}

extension Bundle {
  // NB: Alternative to `Bundle.module`, which only looks at the top level of the main bundle and
  // at the absolute path the package was built to, and traps when it finds nothing. An app keeps
  // this bundle in its resources directory, so it would crash anywhere but on its build machine.
  static let swiftUIMath: Bundle? = {
    var locations: [URL?] = []

    #if DEBUG
      // Set by Xcode for SwiftUI previews
      if let path = ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_PATH"] {
        locations.append(URL(fileURLWithPath: path))
      }
    #endif

    let token = Bundle(for: BundleToken.self)

    locations += [
      // Linked into an app or an app extension
      Bundle.main.resourceURL,
      // Linked into a framework
      token.resourceURL,
      // A command-line tool
      Bundle.main.bundleURL,
      // Linked into a test bundle by `swift test`, which builds resources next to it
      token.bundleURL.deletingLastPathComponent(),
    ]

    return swiftUIMath(in: locations)
  }()

  static func swiftUIMath(in locations: [URL?]) -> Bundle? {
    for location in locations {
      if let url = location?.appendingPathComponent("swiftui-math_SwiftUIMath.bundle"),
        let bundle = Bundle(url: url)
      {
        return bundle
      }
    }
    return nil
  }
}
