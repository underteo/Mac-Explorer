import AppKit
import SwiftUI

/// Finder-style row of seven color dots (filled + white checkmark when on).
struct FinderTagDotsRow: View {
    let selectedColors: Set<FinderColorTag>
    let onToggle: (FinderColorTag) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FinderColorTag.allCases) { color in
                Button {
                    onToggle(color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 14, height: 14)
                        if selectedColors.contains(color) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(color.displayName)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(selectedColors.contains(color) ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

/// AppKit menu item view: horizontal Finder tag dots for the list-view context menu.
final class FinderTagDotsMenuView: NSView {
    private let onToggle: (FinderColorTag) -> Void
    private var selected: Set<FinderColorTag>
    private var buttons: [NSButton] = []

    init(selected: Set<FinderColorTag>, onToggle: @escaping (FinderColorTag) -> Void) {
        self.selected = selected
        self.onToggle = onToggle
        // Width fits 7 dots + padding; height matches a menu row.
        super.init(frame: NSRect(x: 0, y: 0, width: 188, height: 28))
        wantsLayer = true
        buildButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func buildButtons() {
        let size: CGFloat = 14
        let gap: CGFloat = 8
        let startX: CGFloat = 14
        let y: CGFloat = (bounds.height - size) / 2

        for (index, color) in FinderColorTag.allCases.enumerated() {
            let button = NSButton(frame: NSRect(
                x: startX + CGFloat(index) * (size + gap),
                y: y,
                width: size,
                height: size
            ))
            button.image = color.swatchImage(size: size, checked: selected.contains(color))
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.bezelStyle = .inline
            button.title = ""
            button.toolTip = color.displayName
            button.target = self
            button.tag = index
            button.action = #selector(dotClicked(_:))
            addSubview(button)
            buttons.append(button)
        }
    }

    @objc private func dotClicked(_ sender: NSButton) {
        let colors = FinderColorTag.allCases
        guard colors.indices.contains(sender.tag) else { return }
        let color = colors[sender.tag]
        onToggle(color)
        if selected.contains(color) {
            selected.remove(color)
        } else {
            selected.insert(color)
        }
        sender.image = color.swatchImage(size: 14, checked: selected.contains(color))
        // Close the menu after toggle (Finder-like).
        enclosingMenuItem?.menu?.cancelTracking()
    }
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
