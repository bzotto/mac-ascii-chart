import Cocoa

enum NumberBase: Int {
    case hex = 0
    case decimal = 1
    case octal = 2

    func format(_ value: Int) -> String {
        switch self {
        case .hex:
            // '$' prefix for hex (classic 6502 / Mac convention).
            return String(format: "$%02X", value)
        case .decimal:
            return String(format: "%d", value)
        case .octal:
            // Apostrophe prefix for octal in place of the C-style leading zero,
            // zero-padded to 3 digits for easy scanning.
            return String(format: "'%03o", value)
        }
    }
}

/// Standard short names for the 33 non-printable control characters
/// (0x00-0x1F plus 0x7F).
private let controlNames: [String] = [
    "NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL",
    "BS",  "HT",  "LF",  "VT",  "FF",  "CR",  "SO",  "SI",
    "DLE", "DC1", "DC2", "DC3", "DC4", "NAK", "SYN", "ETB",
    "CAN", "EM",  "SUB", "ESC", "FS",  "GS",  "RS",  "US"
]

private func glyph(for value: Int) -> String {
    if value >= 0 && value < 32 {
        return controlNames[value]
    } else if value == 32 {
        return "SP"
    } else if value == 127 {
        return "DEL"
    } else if value < 128 {
        return String(UnicodeScalar(value)!)
    }
    return "?"
}

private func isControl(_ value: Int) -> Bool {
    return value < 32 || value == 127
}

/// The classic ^A..^Z mappings live at ASCII 1..26.
private func ctrlKeyLabel(for value: Int) -> String? {
    guard value >= 1 && value <= 26 else { return nil }
    let letter = Character(UnicodeScalar(value + 64)!)  // 1 -> 'A'
    return "Ctrl-\(letter)"
}

// MARK: - Clickable cell view

/// A cell that reports clicks back to the controller via a closure.
final class CellView: NSView {
    let value: Int
    var onClick: ((CellView) -> Void)?

    init(value: Int) {
        self.value = value
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        onClick?(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - View controller

class AsciiChartViewController: NSViewController {

    private var base: NumberBase = .hex
    private var segmented: NSSegmentedControl!
    private var gridContainer: NSView!
    // (label, value) -- we keep the value to know how to re-render on base change.
    private var cellLabels: [(NSTextField, Int)] = []

    // Layout constants -- values run across rows: row r col c == r*columns + c.
    // 8 entries per row keeps the popover narrow and easy to scan.
    private let columns = 8     // values per row
    private let rows = 16       // 16 rows of 8 == 128 chars
    private let cellWidth: CGFloat = 80
    private let cellHeight: CGFloat = 32
    private let cellSpacing: CGFloat = 2
    private let outerPadding: CGFloat = 12
    private let topBarHeight: CGFloat = 36
    // Every `groupSize` rows we draw a faint horizontal separator so the
    // classic 16-byte ASCII groupings remain visible.
    private let groupSize = 2   // 2 rows == 16 values == one high-nibble group

    override func loadView() {
        let gridWidth = CGFloat(columns) * cellWidth + CGFloat(columns - 1) * cellSpacing
        let gridHeight = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * cellSpacing
        let totalWidth = gridWidth + outerPadding * 2
        let totalHeight = gridHeight + topBarHeight + outerPadding * 2

        let root = NSView(frame: NSRect(x: 0, y: 0,
                                        width: totalWidth,
                                        height: totalHeight))
        root.wantsLayer = true
        // Ensure the popover sizes itself to fit our content exactly.
        self.preferredContentSize = NSSize(width: totalWidth, height: totalHeight)

        // Top bar: segmented control acting as a tab bar.
        segmented = NSSegmentedControl(labels: ["Hex", "Decimal", "Octal"],
                                       trackingMode: .selectOne,
                                       target: self,
                                       action: #selector(baseChanged(_:)))
        segmented.segmentStyle = .texturedSquare
        segmented.selectedSegment = 0
        segmented.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(segmented)

        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: root.topAnchor, constant: outerPadding),
            segmented.centerXAnchor.constraint(equalTo: root.centerXAnchor),
        ])

        // Grid container
        gridContainer = NSView(frame: NSRect(x: outerPadding,
                                             y: outerPadding,
                                             width: gridWidth,
                                             height: gridHeight))
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(gridContainer)

        NSLayoutConstraint.activate([
            gridContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor,
                                                   constant: outerPadding),
            gridContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor,
                                                    constant: -outerPadding),
            gridContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor,
                                                  constant: -outerPadding),
            gridContainer.topAnchor.constraint(equalTo: segmented.bottomAnchor,
                                               constant: 10),
            gridContainer.heightAnchor.constraint(equalToConstant: gridHeight),
        ])

        buildGrid()
        self.view = root
    }

    private func buildGrid() {
        // Remove existing if any
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        cellLabels.removeAll()

        // Sequential values run across rows: 0..(columns-1) in row 0, then on.
        for row in 0..<rows {
            for col in 0..<columns {
                let value = row * columns + col
                let cell = makeCell(for: value)
                let x = CGFloat(col) * (cellWidth + cellSpacing)
                // Top-left origin feel: row 0 at top.
                let y = CGFloat(rows - 1 - row) * (cellHeight + cellSpacing)
                cell.frame = NSRect(x: x, y: y, width: cellWidth, height: cellHeight)
                gridContainer.addSubview(cell)
            }
        }

        // Faint horizontal separators after every `groupSize` rows so the
        // 16-byte high-nibble groupings remain visually obvious.
        let gridWidth = CGFloat(columns) * cellWidth + CGFloat(columns - 1) * cellSpacing
        for r in stride(from: groupSize, to: rows, by: groupSize) {
            // Separator sits in the spacing gap between row (r-1) and row r.
            let gapTop = CGFloat(rows - r) * (cellHeight + cellSpacing)
            let lineY = gapTop - cellSpacing / 2 - 0.5
            let line = NSView(frame: NSRect(x: 0, y: lineY, width: gridWidth, height: 1))
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
            gridContainer.addSubview(line)
        }
    }

    private func makeCell(for value: Int) -> NSView {
        let container = CellView(value: value)
        container.wantsLayer = true
        container.layer?.backgroundColor = backgroundColor(for: value).cgColor
        container.layer?.cornerRadius = 4
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.onClick = { [weak self] cell in self?.copyCharacter(for: cell) }

        // Number label (left)
        let numLabel = NSTextField(labelWithString: base.format(value))
        numLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        numLabel.textColor = .secondaryLabelColor
        numLabel.alignment = .left
        numLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numLabel)

        NSLayoutConstraint.activate([
            numLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            numLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        // Glyph area on the right. For control chars 1..26 we stack the
        // name on top of the Ctrl-X label; otherwise a single glyph line.
        let glyphText = glyph(for: value)
        let ctrlText = ctrlKeyLabel(for: value)

        if let ctrlText = ctrlText {
            // Two-line layout: name (small) stacked over "Ctrl-X" (smaller).
            let nameLabel = NSTextField(labelWithString: glyphText)
            nameLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
            nameLabel.textColor = .systemBlue
            nameLabel.alignment = .right
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(nameLabel)

            let ctrlLabel = NSTextField(labelWithString: ctrlText)
            ctrlLabel.font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .regular)
            ctrlLabel.textColor = .secondaryLabelColor
            ctrlLabel.alignment = .right
            ctrlLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(ctrlLabel)

            NSLayoutConstraint.activate([
                nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor,
                                                    constant: -6),
                nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
                nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: numLabel.trailingAnchor,
                                                   constant: 4),

                ctrlLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor,
                                                    constant: -6),
                ctrlLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 0),
                ctrlLabel.leadingAnchor.constraint(greaterThanOrEqualTo: numLabel.trailingAnchor,
                                                   constant: 4),
            ])
        } else {
            let glyphLabel = NSTextField(labelWithString: glyphText)
            if isControl(value) || value == 32 {
                glyphLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
                glyphLabel.textColor = .systemBlue
            } else {
                glyphLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
                glyphLabel.textColor = .labelColor
            }
            glyphLabel.alignment = .right
            glyphLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(glyphLabel)

            NSLayoutConstraint.activate([
                glyphLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor,
                                                     constant: -6),
                glyphLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                glyphLabel.leadingAnchor.constraint(greaterThanOrEqualTo: numLabel.trailingAnchor,
                                                    constant: 4),
            ])
        }

        // Tooltip with all three representations, plus Ctrl-X when applicable.
        var tip = String(format: "Hex: $%02X    Dec: %d    Oct: '%03o\n%@",
                         value, value, value,
                         tooltipDescription(for: value))
        if let ctrlText = ctrlText {
            tip += "  (\(ctrlText))"
        }
        tip += "\nClick to copy"
        container.toolTip = tip

        cellLabels.append((numLabel, value))
        return container
    }

    private func backgroundColor(for value: Int) -> NSColor {
        if isControl(value) {
            return NSColor.controlAccentColor.withAlphaComponent(0.10)
        } else if value == 32 {
            return NSColor.systemGray.withAlphaComponent(0.12)
        } else {
            return NSColor.controlBackgroundColor
        }
    }

    private func tooltipDescription(for value: Int) -> String {
        if value < 32 {
            let names = [
                "Null", "Start of Heading", "Start of Text", "End of Text",
                "End of Transmission", "Enquiry", "Acknowledge", "Bell",
                "Backspace", "Horizontal Tab", "Line Feed", "Vertical Tab",
                "Form Feed", "Carriage Return", "Shift Out", "Shift In",
                "Data Link Escape", "Device Control 1", "Device Control 2",
                "Device Control 3", "Device Control 4", "Negative Ack",
                "Synchronous Idle", "End of Trans. Block", "Cancel",
                "End of Medium", "Substitute", "Escape", "File Separator",
                "Group Separator", "Record Separator", "Unit Separator"
            ]
            return names[value]
        } else if value == 32 {
            return "Space"
        } else if value == 127 {
            return "Delete"
        } else {
            return "Printable: \(String(UnicodeScalar(value)!))"
        }
    }

    @objc private func baseChanged(_ sender: NSSegmentedControl) {
        guard let newBase = NumberBase(rawValue: sender.selectedSegment) else { return }
        base = newBase
        for (label, value) in cellLabels {
            label.stringValue = base.format(value)
        }
    }

    // MARK: - Copy to pasteboard

    private func copyCharacter(for cell: CellView) {
        guard let scalar = UnicodeScalar(cell.value) else { return }
        let string = String(scalar)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        flashCopyFeedback(on: cell)
    }

    /// Briefly flashes the cell's background to confirm the copy action.
    private func flashCopyFeedback(on cell: CellView) {
        let original = backgroundColor(for: cell.value).cgColor
        let flash = NSColor.controlAccentColor.withAlphaComponent(0.55).cgColor

        // Immediate set, then animate back to original.
        cell.layer?.backgroundColor = flash

        let anim = CABasicAnimation(keyPath: "backgroundColor")
        anim.fromValue = flash
        anim.toValue = original
        anim.duration = 0.45
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        cell.layer?.backgroundColor = original
        cell.layer?.add(anim, forKey: "copyFlash")
    }
}
