import Foundation

/// A keyboard shortcut: modifier keys + a letter/number key.
struct KeyCombo: Codable, Equatable {
    var key: String          // e.g. "G", "1", "F5"
    var command: Bool = false
    var control: Bool = false
    var option: Bool = false
    var shift: Bool = false

    var isEmpty: Bool { key.isEmpty }

    var displayString: String {
        guard !isEmpty else { return "Not Set" }
        var s = ""
        if control { s += "⌃" }
        if option  { s += "⌥" }
        if shift   { s += "⇧" }
        if command { s += "⌘" }
        s += key.uppercased()
        return s
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if command { flags.insert(.maskCommand) }
        if control { flags.insert(.maskControl) }
        if option  { flags.insert(.maskAlternate) }
        if shift   { flags.insert(.maskShift) }
        return flags
    }

    /// Lookup table for key string → Carbon virtual key code.
    var keyCode: CGKeyCode? {
        KeyCombo.keyCodeMap[key.uppercased()]
    }

    static let empty = KeyCombo(key: "")

    // Standard US keyboard layout key codes (Carbon HIToolbox)
    static let keyCodeMap: [String: CGKeyCode] = [
        "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "H": 0x04,
        "G": 0x05, "Z": 0x06, "X": 0x07, "C": 0x08, "V": 0x09,
        "B": 0x0B, "Q": 0x0C, "W": 0x0D, "E": 0x0E, "R": 0x0F,
        "Y": 0x10, "T": 0x11, "U": 0x20, "I": 0x22, "O": 0x1F,
        "P": 0x23, "L": 0x25, "J": 0x26, "K": 0x28, "N": 0x2D,
        "M": 0x2E,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        "F1": 0x7A, "F2": 0x78, "F3": 0x63, "F4": 0x76,
        "F5": 0x60, "F6": 0x61, "F7": 0x62, "F8": 0x64,
        "F9": 0x65, "F10": 0x6D, "F11": 0x67, "F12": 0x6F,
        "SPACE": 0x31, "TAB": 0x30, "RETURN": 0x24, "ESCAPE": 0x35,
    ]

    /// All assignable key names for UI display.
    static let allKeys: [String] = [
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        "0","1","2","3","4","5","6","7","8","9",
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
    ]
}

/// Actions that can be assigned to a button.
enum ButtonAction: String, Codable, CaseIterable {
    case enter = "Enter"
    case ctrlC = "Ctrl+C"
    case accept = "Accept (y+Enter)"
    case reject = "Reject (n+Enter)"
    case tab = "Tab"
    case escape = "Escape"
    case voiceInput = "Voice Input"
    case presetMenu = "Preset Menu"
    case clear = "/clear"
    case arrowUp = "Arrow Up (↑)"
    case arrowDown = "Arrow Down (↓)"
    case arrowLeft = "Arrow Left (←)"
    case arrowRight = "Arrow Right (→)"
    case quit = "Quit"
    case none = "None"
}

/// Controller style preference for UI labels.
enum ControllerStyle: String, Codable, CaseIterable {
    case xbox = "Xbox"
    case ps5 = "PS5"
}

/// Centralized controller button labels and colors based on style preference.
struct ControllerLabels {
    let style: ControllerStyle

    // Face buttons
    var a: String { style == .xbox ? "A" : "✕" }
    var b: String { style == .xbox ? "B" : "○" }
    var x: String { style == .xbox ? "X" : "□" }
    var y: String { style == .xbox ? "Y" : "△" }

    // Triggers & bumpers
    var lt: String { style == .xbox ? "LT" : "L2" }
    var rt: String { style == .xbox ? "RT" : "R2" }
    var lb: String { style == .xbox ? "LB" : "L1" }
    var rb: String { style == .xbox ? "RB" : "R1" }

    // System
    var start: String { style == .xbox ? "Menu" : "Options" }
    var select: String { style == .xbox ? "View" : "Create" }
    var guide: String { style == .xbox ? "Xbox" : "PS" }
    var stickClick: String { style == .xbox ? "L3 / R3" : "L3 / R3" }

    // Face button colors — Xbox and PS5 use different color schemes
    var colorA: NSColor { style == .xbox ? .systemGreen : NSColor(red: 0.35, green: 0.55, blue: 0.90, alpha: 1) }
    var colorB: NSColor { style == .xbox ? .systemRed   : .systemRed }
    var colorX: NSColor { style == .xbox ? .systemBlue  : NSColor(red: 0.80, green: 0.45, blue: 0.70, alpha: 1) }
    var colorY: NSColor { style == .xbox ? .systemYellow : NSColor(red: 0.30, green: 0.75, blue: 0.55, alpha: 1) }

    /// Face button label for a key ("a", "b", "x", "y").
    func face(_ key: String) -> String {
        switch key {
        case "a": return a
        case "b": return b
        case "x": return x
        case "y": return y
        default: return key.uppercased()
        }
    }

    /// Face button color for a key.
    func faceColor(_ key: String) -> NSColor {
        switch key {
        case "a": return colorA
        case "b": return colorB
        case "x": return colorX
        case "y": return colorY
        default: return .white
        }
    }
}

import AppKit

/// Input element for command combos.
enum ComboInput: String, Codable, CaseIterable {
    case up = "↑"
    case down = "↓"
    case left = "←"
    case right = "→"
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"

    /// Display label respecting controller style.
    func displayLabel(_ labels: ControllerLabels) -> String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .a: return labels.a
        case .b: return labels.b
        case .x: return labels.x
        case .y: return labels.y
        }
    }
}

/// Command combo input style.
enum ComboStyle: String, Codable, CaseIterable {
    case fighting = "Fighting Game"
    case helldivers = "Helldivers 2"
}

/// A command combo: a sequence of inputs that triggers a prompt.
struct ComboEntry: Codable {
    var name: String
    var inputs: [ComboInput]
    var prompt: String
    var style: ComboStyle

    /// Display string for the input sequence.
    var inputDisplay: String {
        inputs.map(\.rawValue).joined(separator: " ")
    }
}

/// A category of preset prompts.
struct PresetCategory: Codable {
    var name: String
    var prompts: [String]
}

/// Preset prompt configuration and quick prompt mappings.
struct ButtonMapping: Codable {
    var categories: [PresetCategory]
    var presetPrompts: [String]  // flat list for Start menu cycling (derived from categories)
    var ltPrompts: QuickPrompts
    var rtPrompts: QuickPrompts
    var buttonActions: ButtonActions

    struct QuickPrompts: Codable {
        var a: String
        var b: String
        var x: String
        var y: String
    }

    /// All prompts flattened from categories.
    var allPrompts: [String] {
        categories.flatMap { $0.prompts }
    }

    struct ButtonActions: Codable {
        var a: ButtonAction
        var b: ButtonAction
        var x: ButtonAction
        var y: ButtonAction
        var lb: ButtonAction
        var rb: ButtonAction
        var start: ButtonAction
        var select: ButtonAction
        var stickClick: ButtonAction
        var dpadUp: ButtonAction
        var dpadDown: ButtonAction
        var dpadLeft: ButtonAction
        var dpadRight: ButtonAction

        static let `default` = ButtonActions(
            a: .enter,
            b: .ctrlC,
            x: .accept,
            y: .reject,
            lb: .tab,
            rb: .escape,
            start: .presetMenu,
            select: .clear,
            stickClick: .voiceInput,
            dpadUp: .arrowUp,
            dpadDown: .arrowDown,
            dpadLeft: .arrowLeft,
            dpadRight: .arrowRight
        )
    }

    static let defaultCategories: [PresetCategory] = [
        PresetCategory(name: "Debug", prompts: [
            "fix the failing tests",
            "find and fix the bug",
            "explain this error",
        ]),
        PresetCategory(name: "Code", prompts: [
            "explain what this code does",
            "refactor this to be cleaner",
            "optimize this for performance",
            "add types and documentation",
        ]),
        PresetCategory(name: "Edit", prompts: [
            "add error handling",
            "write tests for this",
            "continue",
            "undo the last change",
        ]),
        PresetCategory(name: "Git", prompts: [
            "show me the diff",
            "looks good, commit this",
        ]),
    ]

    static let defaultCombos: [ComboEntry] = [
        // Helldivers-style (d-pad only)
        ComboEntry(name: "Reinforce", inputs: [.up, .down, .right, .left, .up], prompt: "fix all the errors", style: .helldivers),
        ComboEntry(name: "Resupply", inputs: [.down, .down, .up, .right], prompt: "add the missing dependencies", style: .helldivers),
        ComboEntry(name: "Air Strike", inputs: [.up, .right, .down, .right], prompt: "delete all unused code", style: .helldivers),
        ComboEntry(name: "Shield", inputs: [.down, .up, .left, .right], prompt: "add error handling to this", style: .helldivers),
        ComboEntry(name: "Orbital", inputs: [.right, .right, .up], prompt: "refactor this completely", style: .helldivers),
        ComboEntry(name: "EAT", inputs: [.up, .down, .left, .up, .right], prompt: "write comprehensive tests", style: .helldivers),
        // Fighting-game-style (directions + face button finisher)
        ComboEntry(name: "Hadouken", inputs: [.down, .right, .a], prompt: "run the tests", style: .fighting),
        ComboEntry(name: "Shoryuken", inputs: [.right, .down, .right, .a], prompt: "fix the bug", style: .fighting),
        ComboEntry(name: "Tatsumaki", inputs: [.down, .left, .b], prompt: "explain this code", style: .fighting),
        ComboEntry(name: "Sonic Boom", inputs: [.left, .right, .x], prompt: "looks good, commit this", style: .fighting),
        ComboEntry(name: "Super", inputs: [.down, .right, .down, .right, .a], prompt: "find and fix all bugs in this file", style: .fighting),
    ]

    static let `default` = ButtonMapping(
        categories: defaultCategories,
        presetPrompts: defaultCategories.flatMap { $0.prompts },
        ltPrompts: QuickPrompts(
            a: "fix the failing tests",
            b: "explain this error",
            x: "continue",
            y: "undo the last change"
        ),
        rtPrompts: QuickPrompts(
            a: "run the tests",
            b: "show me the diff",
            x: "looks good, commit this",
            y: "refactor this to be cleaner"
        ),
        buttonActions: .default,
        guideKeyCombo: KeyCombo(key: "G", command: true),
        controllerStyle: .xbox,
        comboStyle: .helldivers,
        combos: defaultCombos
    )

    // MARK: - Guide Button

    var guideKeyCombo: KeyCombo

    // MARK: - Controller Style

    var controllerStyle: ControllerStyle

    /// Convenience accessor for labels based on current style.
    var labels: ControllerLabels { ControllerLabels(style: controllerStyle) }

    // MARK: - Command Combos

    var comboStyle: ComboStyle
    var combos: [ComboEntry]

    // MARK: - Persistence

    private static var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClaudeGamepad")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    init(categories: [PresetCategory], presetPrompts: [String],
         ltPrompts: QuickPrompts, rtPrompts: QuickPrompts,
         buttonActions: ButtonActions, guideKeyCombo: KeyCombo,
         controllerStyle: ControllerStyle,
         comboStyle: ComboStyle, combos: [ComboEntry]) {
        self.categories = categories
        self.presetPrompts = presetPrompts
        self.ltPrompts = ltPrompts
        self.rtPrompts = rtPrompts
        self.buttonActions = buttonActions
        self.guideKeyCombo = guideKeyCombo
        self.controllerStyle = controllerStyle
        self.comboStyle = comboStyle
        self.combos = combos
    }

    /// Custom decoder to handle backward compatibility when new fields are added.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decode([PresetCategory].self, forKey: .categories)
        presetPrompts = try container.decode([String].self, forKey: .presetPrompts)
        ltPrompts = try container.decode(QuickPrompts.self, forKey: .ltPrompts)
        rtPrompts = try container.decode(QuickPrompts.self, forKey: .rtPrompts)
        buttonActions = try container.decode(ButtonActions.self, forKey: .buttonActions)
        guideKeyCombo = try container.decodeIfPresent(KeyCombo.self, forKey: .guideKeyCombo) ?? KeyCombo(key: "G", command: true)
        controllerStyle = try container.decodeIfPresent(ControllerStyle.self, forKey: .controllerStyle) ?? .xbox
        comboStyle = try container.decode(ComboStyle.self, forKey: .comboStyle)
        combos = try container.decode([ComboEntry].self, forKey: .combos)
    }

    static func load() -> ButtonMapping {
        guard let data = try? Data(contentsOf: configURL),
              let mapping = try? JSONDecoder().decode(ButtonMapping.self, from: data) else {
            return .default
        }
        return mapping
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: ButtonMapping.configURL)
    }
}
