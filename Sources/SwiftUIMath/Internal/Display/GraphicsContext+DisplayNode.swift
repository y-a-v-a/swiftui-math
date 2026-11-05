import SwiftUI

extension GraphicsContext {
  func draw(_ displayNode: Math.DisplayNode, size: CGSize, foregroundColor: Color) {
    var context = self

    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    context.translateBy(x: 0, y: displayNode.descent)

    let foregroundColor = foregroundColor.resolve(in: environment).cgColor

    context.withCGContext { cgContext in
      cgContext.draw(displayNode, foregroundColor: foregroundColor)
    }
  }

  func draw(_ displayNode: Math.DisplayNode, size: CGSize, with shading: GraphicsContext.Shading) {
    var context = self

    // Clip rather than fill and blend with `.destinationIn`: PDF output only applies that blend
    // where the layer has ink, so the rest of the fill would stay as a solid block.
    context.clipToLayer {
      $0.draw(displayNode, size: size, foregroundColor: .black)
    }
    context.fill(Path(CGRect(origin: .zero, size: size)), with: shading)
  }
}
