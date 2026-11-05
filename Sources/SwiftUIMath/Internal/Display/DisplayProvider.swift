import Foundation

extension Math {
  final class DisplayProvider: Sendable {
    private struct Cache {
      struct Key: Hashable {
        let latex: String
        let font: Font
        let style: TypesettingStyle
        let proposedWidth: CGFloat
      }

      let atomList = NSCache<NSString, AtomList>()
      let displayNode = NSCache<KeyBox<Key>, DisplayNode>()
    }

    static let shared = DisplayProvider()

    /// How far the canvas width can differ from the measured width: one point at 1x.
    private static let pixelRoundingTolerance: CGFloat = 1

    private let cache = ReadWriteLockIsolated<Cache>(Cache())

    func sizeThatFits(
      proposedWidth width: CGFloat,
      latex: String,
      font: Font,
      style: TypesettingStyle
    ) -> CGSize {
      display(
        for: latex,
        font: font,
        style: style,
        proposedWidth: width
      )?.bounds.size ?? .zero
    }

    func display(
      for latex: String,
      font: Font,
      style: TypesettingStyle,
      proposedWidth: CGFloat
    ) -> DisplayNode? {
      cache.withValue { cache in
        func key(_ width: CGFloat) -> KeyBox<Cache.Key> {
          KeyBox(Cache.Key(latex: latex, font: font, style: style, proposedWidth: width))
        }

        func typeset(maxWidth: CGFloat, cache: inout Cache) -> DisplayNode? {
          if let displayNode = cache.displayNode.object(forKey: key(maxWidth)) {
            return displayNode
          }

          guard
            let platformFont = PlatformFont(font: font),
            let atomList = atomList(for: latex, cache: &cache),
            let displayNode = Typesetter.createLineForMathList(
              atomList,
              font: platformFont,
              style: .init(style),
              maxWidth: maxWidth
            )
          else {
            return nil
          }

          cache.displayNode.setObject(displayNode, forKey: key(maxWidth))
          return displayNode
        }

        // The draw pass proposes the canvas width, which is the measured width after pixel
        // rounding. An expression that fits must not wrap because of that rounding: the wrapped
        // layout is taller than the frame measured for it, so part of it would be clipped.
        guard let natural = typeset(maxWidth: 0, cache: &cache) else {
          return nil
        }
        if proposedWidth <= 0 || natural.width <= proposedWidth + Self.pixelRoundingTolerance {
          return natural
        }

        guard let wrapped = typeset(maxWidth: proposedWidth.halfPointRounded(), cache: &cache)
        else {
          return nil
        }

        // Same reason for a wrapped layout: the widths around the one it measured must find it
        // again rather than wrap a second time, at a width narrower than its own lines.
        for offset in stride(
          from: -Self.pixelRoundingTolerance,
          through: Self.pixelRoundingTolerance,
          by: 0.5
        ) {
          let width = (wrapped.width + offset).halfPointRounded()
          if width > 0 {
            cache.displayNode.setObject(wrapped, forKey: key(width))
          }
        }

        return wrapped
      }
    }

    private func atomList(for latex: String, cache: inout Cache) -> AtomList? {
      if let atomList = cache.atomList.object(forKey: latex as NSString) {
        return atomList
      }

      guard let atomList = Parser.build(fromString: latex) else {
        return nil
      }

      cache.atomList.setObject(atomList, forKey: latex as NSString)
      return atomList
    }
  }
}

extension Math.Style.Level {
  fileprivate init(_ typesettingStyle: Math.TypesettingStyle) {
    switch typesettingStyle {
    case .display:
      self = .display
    case .text:
      self = .text
    }
  }
}

extension CGFloat {
  fileprivate func halfPointRounded() -> CGFloat {
    guard self > 0 else { return 0 }
    return (self * 2).rounded() / 2
  }
}
