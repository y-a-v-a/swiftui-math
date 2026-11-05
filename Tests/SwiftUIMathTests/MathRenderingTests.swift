import CoreGraphics
import SwiftUI
import Testing

@testable import SwiftUIMath

@MainActor
@Suite
struct MathRenderingTests {
  // Which expressions broke depended on where their width and origin fell against the pixel grid:
  // the canvas size comes out of that rounding. So these cover several sizes and offsets rather
  // than one combination that might happen to land well.
  private static let fontSizes: [CGFloat] = [16, 17.6, 20, 24, 40]
  private static let offsets: [CGFloat] = [0, 0.3, 0.6]

  private func view(_ latex: String, fontSize: CGFloat = 40, offset: CGFloat = 0) -> some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: offset, height: 1)
      Math(latex)
        .mathFont(Math.Font(name: .latinModern, size: fontSize))
        .mathTypesettingStyle(.text)
        .fixedSize()
    }
    .foregroundStyle(Color.black)
  }

  /// Rasterizes through a PDF, the output where a mask that doesn't apply shows as solid fill.
  private func pdfImage(_ latex: String, fontSize: CGFloat = 40, offset: CGFloat = 0) throws -> Ink
  {
    let data = NSMutableData()
    var box = CGRect.zero
    ImageRenderer(content: view(latex, fontSize: fontSize, offset: offset)).render { size, draw in
      box = CGRect(origin: .zero, size: size)
      guard
        let consumer = CGDataConsumer(data: data),
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)
      else { return }
      context.beginPDFPage(nil)
      draw(context)
      context.endPDFPage()
      context.closePDF()
    }
    let page = try #require(
      CGDataProvider(data: data).flatMap(CGPDFDocument.init)?.page(at: 1))
    return try Ink(size: box.size, scale: 2) { $0.drawPDFPage(page) }
  }

  private func bitmapImage(
    _ latex: String, fontSize: CGFloat, offset: CGFloat, scale: CGFloat
  ) throws -> Ink {
    let renderer = ImageRenderer(content: view(latex, fontSize: fontSize, offset: offset))
    renderer.scale = scale
    let image = try #require(renderer.cgImage)
    let size = CGSize(width: image.width, height: image.height)
    return try Ink(size: size, scale: 1) { $0.draw(image, in: CGRect(origin: .zero, size: size)) }
  }

  // A wrapped layout loses its first line above the frame, including the nucleus. What stays is the
  // script, moved to the left edge, so it takes up only part of the frame's width.
  @Test(arguments: ["r^2", "x^2", "a_i", "2^3", "E = mc^2", "A = \\pi r^2"])
  func scriptedExpressionsKeepTheirNucleus(latex: String) throws {
    for fontSize in Self.fontSizes {
      for offset in Self.offsets {
        let context = "\(latex), \(fontSize)pt, offset \(offset)"
        for scale in [1, 2, 3] as [CGFloat] {
          let ink = try bitmapImage(latex, fontSize: fontSize, offset: offset, scale: scale)
          #expect(ink.widthFraction > 0.7, "\(context) at \(scale)x")
        }

        let ink = try pdfImage(latex, fontSize: fontSize, offset: offset)
        #expect(ink.widthFraction > 0.7, "\(context) in PDF")
      }
    }
  }

  // Glyphs leave most of their bounding box empty; a block left by a mask that didn't apply
  // doesn't. `\frac{1}` is the sharpest case: its empty denominator has no ink at all.
  @Test(arguments: ["r^2", "x^2", "a_i", "E = mc^2", "\\frac{1}", "\\sin x"])
  func pdfOutputHasNoSolidBlocks(latex: String) throws {
    for offset in Self.offsets {
      let ink = try pdfImage(latex, offset: offset)
      #expect(ink.largestSolidSquare < ink.height / 3, "\(latex), offset \(offset)")
    }
  }
}

/// A rendering flattened onto white, reduced to which pixels have ink.
private struct Ink {
  let width: Int
  let height: Int
  private let dark: [Bool]

  init(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) throws {
    let width = Int((size.width * scale).rounded(.up))
    let height = Int((size.height * scale).rounded(.up))
    let context = try #require(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
      ))
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    draw(context)

    let image = try #require(context.makeImage())
    let bytes = try #require(image.dataProvider?.data as Data?)
    self.width = width
    self.height = height
    dark = (0..<height * width).map { index in
      bytes[index / width * image.bytesPerRow + index % width] < 128
    }
  }

  /// How much of the width lies between the leftmost and rightmost dark pixels.
  var widthFraction: Double {
    var first = width
    var last = -1
    for row in 0..<height {
      for column in 0..<width where dark[row * width + column] {
        first = min(first, column)
        last = max(last, column)
      }
    }
    return last < first ? 0 : Double(last - first + 1) / Double(width)
  }

  /// The side of the largest all-dark square.
  var largestSolidSquare: Int {
    var previous = [Int](repeating: 0, count: width + 1)
    var largest = 0
    for row in 0..<height {
      var current = [Int](repeating: 0, count: width + 1)
      for column in 0..<width where dark[row * width + column] {
        current[column + 1] = min(previous[column], previous[column + 1], current[column]) + 1
        largest = max(largest, current[column + 1])
      }
      previous = current
    }
    return largest
  }
}
