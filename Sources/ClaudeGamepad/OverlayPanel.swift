import AppKit

/// A floating HUD panel that shows feedback (button presses, voice status, transcription).
/// Non-activating so it doesn't steal focus from the terminal.
final class OverlayPanel: NSPanel {
    private enum PresentationKind {
        case standard
        case listening
        case transcribing
        case transcription
    }

    private let effectView: NSVisualEffectView
    private let accentBubble = NSView()
    private let iconView = NSImageView()
    private let waveformView = WaveformView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var hideTimer: Timer?

    static let shared = OverlayPanel()

    private init() {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 20
        effectView.layer?.masksToBounds = true
        self.effectView = effectView

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 94),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false

        setupUI()
    }

    private func setupUI() {
        guard let contentView else { return }
        effectView.frame = contentView.bounds
        effectView.autoresizingMask = [.width, .height]
        contentView.addSubview(effectView)

        accentBubble.wantsLayer = true
        accentBubble.layer?.cornerRadius = 14
        effectView.addSubview(accentBubble)

        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .white
        effectView.addSubview(iconView)

        waveformView.isHidden = true
        effectView.addSubview(waveformView)

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.86)
        effectView.addSubview(titleLabel)

        bodyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        bodyLabel.textColor = .white
        bodyLabel.maximumNumberOfLines = 3
        bodyLabel.lineBreakMode = .byTruncatingTail
        effectView.addSubview(bodyLabel)

        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.66)
        effectView.addSubview(hintLabel)
    }

    /// Show a brief message (auto-hides after duration).
    func showMessage(_ text: String, duration: TimeInterval = 2.0) {
        let parsed = parseMessage(text)
        present(
            kind: parsed.kind,
            title: parsed.title,
            body: parsed.body,
            hint: parsed.hint,
            symbolName: parsed.symbolName,
            accentColor: parsed.accentColor,
            duration: duration
        )
    }

    /// Show voice listening state with waveform.
    func showListening() {
        present(
            kind: .listening,
            title: "Voice Input",
            body: "Listening for your prompt",
            hint: "Speak naturally. The recording stops after silence is detected.",
            symbolName: "waveform",
            accentColor: NSColor.systemRed,
            duration: 30
        )
    }

    /// Update the waveform audio level (0.0 - 1.0).
    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.waveformView.audioLevel = level
        }
    }

    /// Show transcribing state.
    func showTranscribing() {
        present(
            kind: .transcribing,
            title: "Voice Input",
            body: "Transcribing speech...",
            hint: "This can take a moment for longer recordings or larger Whisper models.",
            symbolName: "text.badge.magnifyingglass",
            accentColor: NSColor.systemOrange,
            duration: 30
        )
    }

    /// Show transcription result.
    func showTranscription(_ text: String) {
        present(
            kind: .transcription,
            title: "Transcription Ready",
            body: text,
            hint: "Press A to paste, or B to cancel.",
            symbolName: "quote.bubble",
            accentColor: NSColor.controlAccentColor,
            duration: 6.0
        )
    }

    func fadeOut() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.24
                self.animator().alphaValue = 0
            }) {
                self.orderOut(nil)
                self.alphaValue = 1.0
            }
        }
    }

    private func present(
        kind: PresentationKind,
        title: String,
        body: String,
        hint: String?,
        symbolName: String,
        accentColor: NSColor,
        duration: TimeInterval
    ) {
        DispatchQueue.main.async { [self] in
            hideTimer?.invalidate()

            titleLabel.stringValue = title
            bodyLabel.stringValue = body
            hintLabel.stringValue = hint ?? ""
            hintLabel.isHidden = hint == nil

            accentBubble.layer?.backgroundColor = accentColor.withAlphaComponent(0.28).cgColor
            accentBubble.layer?.borderWidth = 1
            accentBubble.layer?.borderColor = accentColor.withAlphaComponent(0.25).cgColor

            waveformView.isHidden = kind != .listening
            if kind == .listening {
                iconView.isHidden = true
            } else {
                iconView.isHidden = false
                let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
                iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            }

            layoutPanel(for: kind, body: body, hint: hint)
            positionOnScreen()
            orderFrontRegardless()
            alphaValue = 1

            hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.fadeOut()
            }
        }
    }

    private func layoutPanel(for kind: PresentationKind, body: String, hint: String?) {
        let maxWidth: CGFloat = kind == .transcription ? 540 : 440
        let minWidth: CGFloat = 250
        let bubbleSize: CGFloat = 44
        let sideInset: CGFloat = 16
        let textLeading: CGFloat = sideInset + bubbleSize + 14
        let textWidthGuess = maxWidth - textLeading - sideInset

        let bodySize = measuredSize(for: body, font: bodyLabel.font!, width: textWidthGuess, maxLines: kind == .transcription ? 3 : 2)
        let hintSize = measuredSize(for: hint ?? "", font: hintLabel.font!, width: textWidthGuess, maxLines: 2)
        let titleHeight: CGFloat = 16
        let bottomPadding: CGFloat = hint == nil ? 16 : 14
        let contentHeight = 14 + titleHeight + 6 + bodySize.height + (hint == nil ? 0 : 8 + hintSize.height) + bottomPadding
        let preferredWidth = min(max(minWidth, bodySize.width + textLeading + sideInset), maxWidth)

        setContentSize(NSSize(width: preferredWidth, height: contentHeight))
        effectView.frame = NSRect(origin: .zero, size: NSSize(width: preferredWidth, height: contentHeight))

        accentBubble.frame = NSRect(x: sideInset, y: 16, width: bubbleSize, height: bubbleSize)
        iconView.frame = NSRect(x: sideInset + 11, y: 27, width: 22, height: 22)
        waveformView.frame = NSRect(x: sideInset + 7, y: 23, width: 30, height: 30)

        titleLabel.frame = NSRect(x: textLeading, y: 16, width: preferredWidth - textLeading - sideInset, height: titleHeight)
        bodyLabel.frame = NSRect(x: textLeading, y: titleLabel.frame.maxY + 6, width: preferredWidth - textLeading - sideInset, height: bodySize.height)
        hintLabel.frame = NSRect(x: textLeading, y: bodyLabel.frame.maxY + 8, width: preferredWidth - textLeading - sideInset, height: hintSize.height)
    }

    private func measuredSize(for text: String, font: NSFont, width: CGFloat, maxLines: Int) -> NSSize {
        guard !text.isEmpty else { return NSSize(width: 0, height: 0) }
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let lineHeight = font.boundingRectForFont.height
        let cappedHeight = min(ceil(rect.height), ceil(lineHeight) * CGFloat(maxLines))
        let cappedWidth = min(width, ceil(rect.width))
        return NSSize(width: cappedWidth, height: max(lineHeight, cappedHeight))
    }

    private func parseMessage(_ text: String) -> (kind: PresentationKind, title: String, body: String, hint: String?, symbolName: String, accentColor: NSColor) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var hint: String?
        var kind: PresentationKind = .standard

        if let hintStart = trimmed.range(of: "["),
           trimmed.hasSuffix("]") {
            hint = String(trimmed[hintStart.lowerBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            trimmed = String(trimmed[..<hintStart.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            kind = .transcription
        }

        let mappings: [(prefix: String, title: String, symbol: String, color: NSColor)] = [
            ("🎮", "Controller", "gamecontroller", .systemBlue),
            ("⚠️", "Attention", "exclamationmark.triangle.fill", .systemOrange),
            ("⏎", "Action Sent", "return", .controlAccentColor),
            ("⌃C", "Interrupt", "hand.raised.fill", .systemRed),
            ("✅", "Action Sent", "checkmark.circle.fill", .systemGreen),
            ("❌", "Action Cancelled", "xmark.circle.fill", .systemRed),
            ("⇥", "Action Sent", "arrow.right.to.line.compact", .controlAccentColor),
            ("⎋", "Action Sent", "escape", .controlAccentColor),
            ("🧹", "Terminal Command", "sparkles", .systemTeal),
            ("👋", "Application", "power", .systemPink),
            ("📤", "Prompt Sent", "paperplane.fill", .systemBlue),
            ("⚡", "Quick Prompt", "bolt.fill", .systemYellow),
            ("🎤", kind == .transcription ? "Transcription Ready" : "Voice Input", "mic.fill", .systemRed),
            ("📋", "Preset Browser", "list.bullet.rectangle", .controlAccentColor),
        ]

        for mapping in mappings where trimmed.hasPrefix(mapping.prefix) {
            let body = trimmed.dropFirst(mapping.prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                kind,
                mapping.title,
                body.isEmpty ? trimmed : body,
                normalizedHint(hint),
                mapping.symbol,
                mapping.color
            )
        }

        return (
            kind,
            kind == .transcription ? "Transcription Ready" : "Claude Gamepad",
            trimmed,
            normalizedHint(hint),
            kind == .transcription ? "quote.bubble.fill" : "gamecontroller.fill",
            kind == .transcription ? .controlAccentColor : .systemBlue
        )
    }

    private func normalizedHint(_ hint: String?) -> String? {
        guard let hint, !hint.isEmpty else { return nil }
        return hint
            .replacingOccurrences(of: "A=确认", with: "A 确认")
            .replacingOccurrences(of: "B=取消", with: "B 取消")
    }

    private func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.minY + 84
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - WaveformView

/// Simple animated waveform bars driven by audio level.
final class WaveformView: NSView {
    var audioLevel: Float = 0 {
        didSet { needsDisplay = true }
    }

    private let barCount = 5
    private let barWeights: [CGFloat] = [0.45, 0.75, 1.0, 0.72, 0.5]

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let barWidth: CGFloat = 4
        let gap: CGFloat = 3
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * gap
        let startX = (bounds.width - totalWidth) / 2
        context.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)

        for index in 0..<barCount {
            let weight = barWeights[index]
            let level = CGFloat(audioLevel) * weight + CGFloat.random(in: 0...0.06)
            let height = max(4, bounds.height * min(level, 1.0))
            let x = startX + CGFloat(index) * (barWidth + gap)
            let y = (bounds.height - height) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.fill()
        }
    }
}
