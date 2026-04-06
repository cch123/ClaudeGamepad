import Foundation

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
        controllerStyle: .xbox,
        comboStyle: .helldivers,
        combos: defaultCombos
    )

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
         buttonActions: ButtonActions, controllerStyle: ControllerStyle,
         comboStyle: ComboStyle, combos: [ComboEntry]) {
        self.categories = categories
        self.presetPrompts = presetPrompts
        self.ltPrompts = ltPrompts
        self.rtPrompts = rtPrompts
        self.buttonActions = buttonActions
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
