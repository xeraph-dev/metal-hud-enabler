import ArgumentParser
import Foundation

enum Errors: Error, CustomStringConvertible {
    case notMatch

    var description: String {
        switch self {
        case .notMatch: "No application matches the bundle identifier/name passed"
        }
    }
}

@main
struct MetalHUD: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Permanently enabling the Metal 3 performance HUD on a per-application basis for any Metal-enabled application on macOS Ventura.",
        subcommands: [Enable.self, Disable.self]
    )
}

struct Enable: ParsableCommand {
    @Argument(help: "Bundle identifier or bundle name of the application to enable.")
    var app: String

    func run() throws {
        let ids = try findIdentifier(app)
        let id = try ensureOneIdentifier(ids)
        try enableMetalHUD(id)
        print("Enabled Metal HUD for \(id)")
    }
}

struct Disable: ParsableCommand {
    @Argument(help: "Bundle identifier or bundle name of the application to disable.")
    var app: String

    func run() throws {
        let ids = try findIdentifier(app)
        let id = try ensureOneIdentifier(ids)
        try disableMetalHUD(id)
        print("Disabled Metal HUD for \(id)")
    }
}

func findIdentifier(_ app: String, _ appsPath: String = "/Applications") throws -> [String: String] {
    var ids = [String: String]()

    for appPath in try FileManager().contentsOfDirectory(atPath: appsPath) {
        guard appPath.hasSuffix(".app") else {
            continue
        }
        let info = "\(appsPath)/\(appPath)/Contents/Info.plist"
        guard let plist = NSDictionary(contentsOfFile: info),
              let name = plist.value(forKey: "CFBundleName") as? String,
              let id = plist.value(forKey: "CFBundleIdentifier") as? String
        else {
            continue
        }
        if id.lowercased() == app.lowercased() || name.lowercased().contains(app.lowercased()) {
            ids[id] = name
        }
    }

    return ids
}

func ensureOneIdentifier(_ ids: [String: String]) throws -> String {
    guard ids.count > 0 else {
        throw Errors.notMatch
    }

    guard ids.count > 1 else {
        return ids.first!.key
    }

    print("Multiple values match the bundle identifier/name passed, select one:")
    for (idx, (id, value)) in ids.enumerated() {
        print("\(idx + 1). \(id) -> \(value)")
    }
    var id = ""
    repeat {
        print("\u{001B}[0K", terminator: "")
        guard let output = readLine(),
              let parsed = Int(output),
              parsed > 0, parsed < ids.count
        else {
            print("\u{001B}[1F", terminator: "")
            continue
        }
        id = ids[ids.index(ids.startIndex, offsetBy: parsed)].key
        print("\u{001B}[1F", terminator: "")
        print("\u{001B}[0K", terminator: "")
    } while ids[id] == nil

    return id
}

func enableMetalHUD(_ id: String) throws {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    proc.arguments = ["write", id, "MetalForceHudEnabled", "-bool", "true"]
    try proc.run()
}

func disableMetalHUD(_ id: String) throws {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    proc.arguments = ["delete", id, "MetalForceHudEnabled"]
    try proc.run()
}
