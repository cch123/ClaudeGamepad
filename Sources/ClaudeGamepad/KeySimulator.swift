import AppKit
import Carbon.HIToolbox
import Darwin

/// Simulates keyboard input for Claude Code and Vibe Island navigation.
final class KeySimulator {
    private typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SetFrontProcessWithOptionsFn = @convention(c) (UnsafePointer<ProcessSerialNumber>, OptionBits) -> OSStatus
    private typealias CGPostKeyboardEventFn = @convention(c) (UInt16, CGKeyCode, Bool) -> CGError

    static let shared = KeySimulator()
    private init() {}

    private let directionalTargetLock = NSLock()
    private var directionalTargetPID: pid_t?
    private var directionalTargetExpiry: TimeInterval = 0
    private let getProcessForPIDFn: GetProcessForPIDFn? = KeySimulator.loadSymbol("GetProcessForPID")
    private let setFrontProcessWithOptionsFn: SetFrontProcessWithOptionsFn? = KeySimulator.loadSymbol("SetFrontProcessWithOptions")
    private let cgPostKeyboardEventFn: CGPostKeyboardEventFn? = KeySimulator.loadSymbol("CGPostKeyboardEvent")

    // Common key codes (Carbon virtual key codes)
    static let kVK_Return: CGKeyCode       = 0x24
    static let kVK_Tab: CGKeyCode          = 0x30
    static let kVK_Escape: CGKeyCode       = 0x35
    static let kVK_UpArrow: CGKeyCode      = 0x7E
    static let kVK_DownArrow: CGKeyCode    = 0x7D
    static let kVK_LeftArrow: CGKeyCode    = 0x7B
    static let kVK_RightArrow: CGKeyCode   = 0x7C
    static let kVK_ANSI_C: CGKeyCode       = 0x08
    static let kVK_ANSI_N: CGKeyCode       = 0x2D
    static let kVK_ANSI_Y: CGKeyCode       = 0x10
    static let kVK_ANSI_V: CGKeyCode       = 0x09

    /// Press and release a single key through the HID event tap.
    func pressKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        usleep(12_000)
        keyUp.post(tap: .cghidEventTap)
    }

    func pressEnter() {
        pressKey(KeySimulator.kVK_Return)
    }

    func pressCtrlC() {
        pressKey(KeySimulator.kVK_ANSI_C, flags: .maskControl)
    }

    /// Press an arbitrary key combo via System Events so it can open overlay windows.
    func pressCombo(_ combo: KeyCombo) {
        guard !combo.isEmpty else { return }

        var modifiers: [String] = []
        if combo.command { modifiers.append("command down") }
        if combo.control { modifiers.append("control down") }
        if combo.option  { modifiers.append("option down") }
        if combo.shift   { modifiers.append("shift down") }

        let key = combo.key.lowercased()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let modClause = modifiers.isEmpty ? "" : " using {\(modifiers.joined(separator: ", "))}"
        let script = "tell application \"System Events\" to keystroke \"\(key)\"\(modClause)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// After a combo opens an overlay window, direct arrow keys to the topmost app.
    func armDirectionalTargetCapture(delay: TimeInterval = 0.18, lifetime: TimeInterval = 3.0) {
        clearDirectionalTarget()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let target = self.topmostWindowTarget() else { return }
            self.setDirectionalTarget(pid: target.pid, lifetime: lifetime)
            _ = self.activateDirectionalTarget(target.pid)
        }
    }

    func pressTab() {
        pressKey(KeySimulator.kVK_Tab)
    }

    func pressEscape() {
        pressKey(KeySimulator.kVK_Escape)
    }

    func pressArrow(_ direction: ArrowDirection) {
        let keyCode: CGKeyCode
        switch direction {
        case .up:
            keyCode = KeySimulator.kVK_UpArrow
        case .down:
            keyCode = KeySimulator.kVK_DownArrow
        case .left:
            keyCode = KeySimulator.kVK_LeftArrow
        case .right:
            keyCode = KeySimulator.kVK_RightArrow
        }

        if postKeyToDirectionalTarget(keyCode) {
            return
        }

        pressKey(keyCode)
    }

    /// Paste a string via AppleScript (clipboard + Cmd+V), without pressing Enter.
    func pasteString(_ text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")

        let script = """
        set the clipboard to "\(escaped)"
        tell application "System Events" to keystroke "v" using command down
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        usleep(100_000)
    }

    func typeString(_ text: String) {
        pasteString(text)
        usleep(50_000)
        pressEnter()
    }

    func typeAccept() {
        pressKey(KeySimulator.kVK_ANSI_Y)
        usleep(20_000)
        pressEnter()
    }

    func typeReject() {
        pressKey(KeySimulator.kVK_ANSI_N)
        usleep(20_000)
        pressEnter()
    }

    private func setDirectionalTarget(pid: pid_t, lifetime: TimeInterval) {
        directionalTargetLock.lock()
        directionalTargetPID = pid
        directionalTargetExpiry = ProcessInfo.processInfo.systemUptime + lifetime
        directionalTargetLock.unlock()
    }

    private func clearDirectionalTarget() {
        directionalTargetLock.lock()
        directionalTargetPID = nil
        directionalTargetExpiry = 0
        directionalTargetLock.unlock()
    }

    private func activeDirectionalTargetPID() -> pid_t? {
        directionalTargetLock.lock()
        defer { directionalTargetLock.unlock() }

        let now = ProcessInfo.processInfo.systemUptime
        guard let pid = directionalTargetPID, directionalTargetExpiry > now else {
            directionalTargetPID = nil
            directionalTargetExpiry = 0
            return nil
        }
        return pid
    }

    private func postKeyToDirectionalTarget(_ keyCode: CGKeyCode) -> Bool {
        guard let pid = activeDirectionalTargetPID() else { return false }
        guard activateDirectionalTarget(pid) else {
            clearDirectionalTarget()
            return false
        }

        usleep(60_000)
        guard postLegacyKeyboardEvent(keyCode) else { return false }
        setDirectionalTarget(pid: pid, lifetime: 3.0)
        return true
    }

    private func postLegacyKeyboardEvent(_ keyCode: CGKeyCode) -> Bool {
        guard let cgPostKeyboardEventFn else {
            return false
        }

        let charCode = legacyCharacterCode(for: keyCode)
        let downError = cgPostKeyboardEventFn(charCode, keyCode, true)
        usleep(12_000)
        let upError = cgPostKeyboardEventFn(charCode, keyCode, false)
        return downError == .success && upError == .success
    }

    private func legacyCharacterCode(for keyCode: CGKeyCode) -> UInt16 {
        switch keyCode {
        case KeySimulator.kVK_UpArrow:
            return 0xF700
        case KeySimulator.kVK_DownArrow:
            return 0xF701
        case KeySimulator.kVK_LeftArrow:
            return 0xF702
        case KeySimulator.kVK_RightArrow:
            return 0xF703
        default:
            return 0
        }
    }

    @discardableResult
    private func activateDirectionalTarget(_ pid: pid_t) -> Bool {
        if let psn = processSerialNumber(for: pid),
           let setFrontProcessWithOptionsFn {
            var psn = psn
            let status = withUnsafePointer(to: &psn) {
                setFrontProcessWithOptionsFn($0, OptionBits(kSetFrontProcessCausedByUser))
            }
            return status == noErr
        }

        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        app.unhide()
        return app.activate()
    }

    private func processSerialNumber(for pid: pid_t) -> ProcessSerialNumber? {
        guard let getProcessForPIDFn else { return nil }
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 0)
        let status = getProcessForPIDFn(pid, &psn)
        return status == noErr ? psn : nil
    }

    private static func loadSymbol<T>(_ name: String) -> T? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }

    private func topmostWindowTarget() -> (pid: pid_t, ownerName: String, windowName: String)? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        let myPid = ProcessInfo.processInfo.processIdentifier
        for win in list {
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            guard layer >= 0,
                  let pid = win[kCGWindowOwnerPID as String] as? pid_t,
                  pid != myPid else { continue }

            if let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
               let width = bounds["Width"],
               let height = bounds["Height"],
               width > 50,
               height > 50 {
                let ownerName = win[kCGWindowOwnerName as String] as? String ?? "Unknown"
                let windowName = win[kCGWindowName as String] as? String ?? ""
                return (pid, ownerName, windowName)
            }
        }

        return nil
    }

    enum ArrowDirection {
        case up, down, left, right
    }
}
