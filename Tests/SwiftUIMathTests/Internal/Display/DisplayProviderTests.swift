import CoreGraphics
import Testing

@testable import SwiftUIMath

@Suite
struct DisplayProviderTests {
  private let font = Math.Font(name: .latinModern, size: 16)

  // The widths of these land on both sides of a half point, so half-point rounding alone moves
  // some of them below their measured width.
  @Test(arguments: [
    "r^2", "x^2", "a_i", "2^3", "x_1^2", "E = mc^2", "A = \\pi r^2", "e^{i\\pi} + 1 = 0",
    "\\sin x", "5 and ", "\\frac{1}{2}", "\\sqrt{x^2}", "\\int_0^1 x^2 dx", "a^2+b^2=c^2",
  ])
  func canvasWidthsAroundTheMeasuredWidthKeepTheMeasuredLayout(latex: String) throws {
    let provider = Math.DisplayProvider()
    let measured = try #require(
      provider.display(for: latex, font: font, style: .text, proposedWidth: 0))

    for offset in stride(from: CGFloat(-1), through: 1, by: 0.125) {
      // A fresh provider has no entry for this width, which is what a cache miss looks like.
      let display = try #require(
        Math.DisplayProvider().display(
          for: latex, font: font, style: .text, proposedWidth: measured.width + offset))

      #expect(display.width == measured.width, "\(latex) at offset \(offset)")
      #expect(display.ascent == measured.ascent, "\(latex) at offset \(offset)")
      #expect(display.descent == measured.descent, "\(latex) at offset \(offset)")
    }
  }

  @Test
  func expressionThatDoesNotFitStillWraps() throws {
    let latex = "a^{2}+b^{2}+c^{2}+d^{2}+e^{2}+f^{2}"
    let provider = Math.DisplayProvider()
    let measured = try #require(
      provider.display(for: latex, font: font, style: .text, proposedWidth: 0))
    let wrapped = try #require(
      provider.display(for: latex, font: font, style: .text, proposedWidth: measured.width / 2))

    #expect(wrapped.width < measured.width)
    #expect(wrapped.ascent + wrapped.descent > measured.ascent + measured.descent)
  }

  @Test
  func canvasWidthsAroundAWrappedWidthKeepTheWrappedLayout() throws {
    let latex = "a^{2}+b^{2}+c^{2}+d^{2}+e^{2}+f^{2}"
    let provider = Math.DisplayProvider()
    let measured = try #require(
      provider.display(for: latex, font: font, style: .text, proposedWidth: 0))
    let wrapped = try #require(
      provider.display(for: latex, font: font, style: .text, proposedWidth: measured.width / 2))

    for offset in stride(from: CGFloat(-1), through: 1, by: 0.125) {
      let display = provider.display(
        for: latex, font: font, style: .text, proposedWidth: wrapped.width + offset)
      #expect(display === wrapped, "offset \(offset)")
    }
  }
}
