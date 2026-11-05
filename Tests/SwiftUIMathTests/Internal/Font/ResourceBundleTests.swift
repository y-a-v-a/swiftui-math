import Foundation
import Testing

@testable import SwiftUIMath

@Suite
struct ResourceBundleTests {
  @Test
  func findsTheFontsInThisEnvironment() throws {
    let bundle = try #require(Bundle.swiftUIMath)
    #expect(bundle.url(forResource: "mathFonts", withExtension: "bundle") != nil)
  }

  @Test
  func findsTheBundleInAnAppsResourcesDirectory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }

    let resources = root.appendingPathComponent("Example.app/Contents/Resources")
    let bundle = resources.appendingPathComponent("swiftui-math_SwiftUIMath.bundle")
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)

    let found = try #require(Bundle.swiftUIMath(in: [nil, root, resources]))
    #expect(found.bundleURL.standardizedFileURL == bundle.standardizedFileURL)
  }

  @Test
  func findsNothingWithoutTrapping() {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    #expect(Bundle.swiftUIMath(in: [nil, missing]) == nil)
  }
}
