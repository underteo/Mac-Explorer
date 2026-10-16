import AppKit
import SwiftUI

/// Read-only Finder tag dots shown next to a file name (list / columns / grid).
struct FinderTagDotsIndicator: View {
    let colors: [FinderColorTag]
    var diameter: CGFloat = 8
    var spacing: CGFloat = 3

    var body: some View {
        if !colors.isEmpty {
            HStack(spacing: spacing) {
                ForEach(colors) { color in
                    Image(nsImage: color.swatchImage(size: diameter, checked: false))
                        .resizable()
                        .frame(width: diameter, height: diameter)
                        .accessibilityLabel(color.displayName)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(colors.map(\.displayName).joined(separator: ", "))
        }
    }
}

/// AppKit stack of tag dots for `NSTableCellView`.
@MainActor
final class FinderTagDotsStackView: NSView {
    private var diameter: CGFloat = 8
    private var spacing: CGFloat = 3
    private var widthConstraint: NSLayoutConstraint?

    override var intrinsicContentSize: NSSize {
        let count = CGFloat(subviews.count)
        guard count > 0 else { return .zero }
        return NSSize(
            width: count * diameter + max(0, count - 1) * spacing,
            height: diameter
        )
    }

    func setColors(_ colors: [FinderColorTag], diameter: CGFloat = 8, spacing: CGFloat = 3) {
        self.diameter = diameter
        self.spacing = spacing
        subviews.forEach { $0.removeFromSuperview() }
        for color in colors {
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
            imageView.image = color.swatchImage(size: diameter, checked: false)
            imageView.imageScaling = .scaleProportionallyDown
            imageView.toolTip = color.displayName
            addSubview(imageView)
        }
        let width = intrinsicContentSize.width
        if let widthConstraint {
            widthConstraint.constant = width
        } else {
            let constraint = widthAnchor.constraint(equalToConstant: width)
            constraint.isActive = true
            widthConstraint = constraint
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        var x: CGFloat = 0
        let y = (bounds.height - diameter) / 2
        for sub in subviews {
            sub.frame = NSRect(x: x, y: y, width: diameter, height: diameter)
            x += diameter + spacing
        }
    }
}

/// Finder-style row of seven color dots for SwiftUI menus / popovers.
struct FinderTagDotsRow: View {
    let selectedColors: Set<FinderColorTag>
    let onToggle: (FinderColorTag) -> Void

    var body: some View {
        // SwiftUI `Button` + `Circle` inside `contextMenu` collapses into an empty
        // highlighted menu row (solid accent bar). Host the AppKit dots view instead.
        FinderTagDotsMenuRepresentable(selected: selectedColors, onToggle: onToggle)
            .frame(width: FinderTagDotsMenuView.preferredSize.width,
                   height: FinderTagDotsMenuView.preferredSize.height)
    }
}

private struct FinderTagDotsMenuRepresentable: NSViewRepresentable {
    let selected: Set<FinderColorTag>
    let onToggle: (FinderColorTag) -> Void

    func makeNSView(context: Context) -> FinderTagDotsMenuView {
        FinderTagDotsMenuView(selected: selected, onToggle: onToggle)
    }

    func updateNSView(_ nsView: FinderTagDotsMenuView, context: Context) {
        nsView.updateSelection(selected)
    }
}

/// AppKit menu item view: horizontal Finder tag dots (also embedded in SwiftUI menus).
final class FinderTagDotsMenuView: NSView {
    static let preferredSize = NSSize(width: 196, height: 28)

    private let onToggle: (FinderColorTag) -> Void
    private var selected: Set<FinderColorTag>
    private var dotViews: [DotView] = []

    init(selected: Set<FinderColorTag>, onToggle: @escaping (FinderColorTag) -> Void) {
        self.selected = selected
        self.onToggle = onToggle
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize))
        wantsLayer = true
        layer?.backgroundColor = .clear
        buildDots()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { Self.preferredSize }

    func updateSelection(_ newValue: Set<FinderColorTag>) {
        selected = newValue
        for (index, color) in FinderColorTag.allCases.enumerated() where dotViews.indices.contains(index) {
            dotViews[index].setChecked(selected.contains(color))
        }
    }

    private func buildDots() {
        let size: CGFloat = 14
        let gap: CGFloat = 10
        let startX: CGFloat = 14
        let y: CGFloat = (bounds.height - size) / 2

        for (index, color) in FinderColorTag.allCases.enumerated() {
            let dot = DotView(
                color: color,
                checked: selected.contains(color),
                frame: NSRect(
                    x: startX + CGFloat(index) * (size + gap),
                    y: y,
                    width: size,
                    height: size
                )
            )
            dot.toolTip = color.displayName
            dot.onClick = { [weak self] in
                self?.dotClicked(color)
            }
            addSubview(dot)
            dotViews.append(dot)
        }
    }

    private func dotClicked(_ color: FinderColorTag) {
        onToggle(color)
        if selected.contains(color) {
            selected.remove(color)
        } else {
            selected.insert(color)
        }
        if let index = FinderColorTag.allCases.firstIndex(of: color),
           dotViews.indices.contains(index) {
            dotViews[index].setChecked(selected.contains(color))
        }
        // Close the menu after toggle (Finder-like).
        enclosingMenuItem?.menu?.cancelTracking()
    }
}

/// Plain colored circle — avoids `NSButton` chrome that paints a solid accent bar in menus.
private final class DotView: NSImageView {
    private let color: FinderColorTag
    private var checked: Bool
    var onClick: (() -> Void)?

    init(color: FinderColorTag, checked: Bool, frame: NSRect) {
        self.color = color
        self.checked = checked
        super.init(frame: frame)
        imageScaling = .scaleProportionallyDown
        image = color.swatchImage(size: min(frame.width, frame.height), checked: checked)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setChecked(_ value: Bool) {
        checked = value
        image = color.swatchImage(size: min(bounds.width, bounds.height), checked: checked)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension FinderColorTag {
    /// Filled color circle; optional white checkmark like Finder’s tag menu.
    func swatchImage(size: CGFloat = 12, checked: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            self.nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            if checked {
                let inset = rect.insetBy(dx: size * 0.28, dy: size * 0.24)
                let check = NSBezierPath()
                check.move(to: NSPoint(x: inset.minX, y: inset.midY))
                check.line(to: NSPoint(x: inset.midX - size * 0.04, y: inset.minY + size * 0.04))
                check.line(to: NSPoint(x: inset.maxX, y: inset.maxY))
                check.lineWidth = max(1.25, size * 0.13)
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                NSColor.white.setStroke()
                check.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
