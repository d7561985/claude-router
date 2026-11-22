// Claude Router — receives claude:// links and hands each one to the right Claude window.
//
// Why: two Claude windows (the main one and "Claude 2" with its own profile folder) are
// one app to macOS, so the system gives a claude:// link to just one of them, and the
// reply of a Google or SSO sign-in lands in the wrong window. While the router is the
// claude:// handler, Claude signs in through Apple's sign-in sheet (the reply goes
// straight to its window), and the router hands other links to the window the person picks.
//
// Claude makes itself the handler again every time it starts, so every 5 seconds the
// router checks and takes the handler back.

import AppKit

let claudeBundleId = "com.anthropic.claudefordesktop"
let claudeAppURL = URL(fileURLWithPath: "/Applications/Claude.app")
let scheme = "claude"

// MARK: - Texts in the system language (the first of en, ru, de, fr in the user's list)

struct Texts { let question, main, cancel: String }

let texts: Texts = {
    let all: [String: Texts] = [
        "en": Texts(question: "Which Claude window should open the link?", main: "Main", cancel: "Cancel"),
        "ru": Texts(question: "В какое окно Claude открыть ссылку?", main: "Основное", cancel: "Отмена"),
        "de": Texts(question: "Welches Claude-Fenster soll den Link öffnen?", main: "Hauptfenster", cancel: "Abbrechen"),
        "fr": Texts(question: "Quelle fenêtre Claude doit ouvrir le lien ?", main: "Principale", cancel: "Annuler"),
    ]
    for id in Locale.preferredLanguages {
        if let code = Locale.Language(identifier: id).languageCode?.identifier, let t = all[code] { return t }
    }
    return all["en"]!
}()

// MARK: - Log (without link parameters: sign-in replies carry codes there)

let logURL: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Claude Router")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("router.log")
}()

func log(_ text: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
    if let h = try? FileHandle(forWritingTo: logURL) {
        h.seekToEndOfFile()
        h.write(line.data(using: .utf8)!)
        try? h.close()
    } else {
        try? line.write(to: logURL, atomically: true, encoding: .utf8)
    }
}

func safe(_ url: URL) -> String {
    var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let keys = c?.queryItems?.map(\.name) ?? []
    c?.query = nil
    let base = c?.string ?? "\(scheme)://…"
    return keys.isEmpty ? base : "\(base) (parameters: \(keys.joined(separator: ", ")))"
}

// MARK: - Claude windows

struct Instance {
    let app: NSRunningApplication
    let profileDir: String?   // nil — the main window (default profile folder)

    var pid: pid_t { app.processIdentifier }
    var title: String {
        guard let dir = profileDir else { return texts.main }
        return (dir as NSString).lastPathComponent.replacingOccurrences(of: "-", with: " ")
    }
}

/// Launch arguments of a process (KERN_PROCARGS2): argc, path, argv…
func arguments(of pid: pid_t) -> [String] {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
    var buf = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > 4 else { return [] }
    let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
    var i = 4
    while i < size, buf[i] != 0 { i += 1 }          // executable path
    while i < size, buf[i] == 0 { i += 1 }          // padding
    var out: [String] = []
    while out.count < argc, i < size {
        var j = i
        while j < size, buf[j] != 0 { j += 1 }
        out.append(String(decoding: buf[i..<j], as: UTF8.self))
        i = j + 1
    }
    return out
}

func instances() -> [Instance] {
    NSRunningApplication.runningApplications(withBundleIdentifier: claudeBundleId)
        .filter { !$0.isTerminated }
        .map { app in
            let dir = arguments(of: app.processIdentifier)
                .first { $0.hasPrefix("--user-data-dir=") }
                .map { String($0.dropFirst("--user-data-dir=".count)) }
            return Instance(app: app, profileDir: dir)
        }
        .sorted { ($0.profileDir ?? "") < ($1.profileDir ?? "") }   // main window first
}

// MARK: - Handing a link to a specific process

/// "Open URL" event (GURL) addressed by pid — macOS doesn't pick the window itself.
func send(_ url: URL, to inst: Instance) -> Bool {
    let target = NSAppleEventDescriptor(processIdentifier: inst.pid)
    let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kInternetEventClass),
        eventID: AEEventID(kAEGetURL),
        targetDescriptor: target,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID))
    event.setParam(NSAppleEventDescriptor(string: url.absoluteString), forKeyword: keyDirectObject)
    do {
        _ = try event.sendEvent(options: [.noReply], timeout: 10)
        inst.app.activate()
        log("sent \(safe(url)) → \(inst.title) (pid \(inst.pid))")
        return true
    } catch {
        log("could not send \(safe(url)) → \(inst.title) (pid \(inst.pid)): \(error)")
        return false
    }
}

func choose(for url: URL, among list: [Instance]) -> Instance? {
    // Test without the dialog: `defaults write local.claude.router testPick "Claude 2"` —
    // picks a window by name once, then resets.
    if let pick = UserDefaults.standard.string(forKey: "testPick") {
        UserDefaults.standard.removeObject(forKey: "testPick")
        log("test: picked \"\(pick)\" without the dialog")
        return list.first { $0.title == pick }
    }
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = texts.question
    var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
    c?.query = nil
    alert.informativeText = c?.string ?? url.absoluteString
    for inst in list { alert.addButton(withTitle: inst.title) }
    alert.addButton(withTitle: texts.cancel)
    let r = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    return r >= 0 && r < list.count ? list[r] : nil
}

func route(_ url: URL) {
    let list = instances()
    switch list.count {
    case 0:
        log("no Claude windows — starting the main one with \(safe(url))")
        NSWorkspace.shared.open([url], withApplicationAt: claudeAppURL,
                                configuration: NSWorkspace.OpenConfiguration())
    case 1:
        _ = send(url, to: list[0])
    default:
        if let inst = choose(for: url, among: list) { _ = send(url, to: inst) }
        else { log("cancelled: \(safe(url))") }
    }
}

// MARK: - claude:// handler

func currentHandler() -> URL? {
    NSWorkspace.shared.urlForApplication(toOpen: URL(string: "\(scheme)://x")!)
}

func claimScheme() {
    let me = Bundle.main.bundleURL.standardizedFileURL
    guard currentHandler()?.standardizedFileURL != me else { return }
    NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: scheme) { error in
        log(error.map { "could not become the \(scheme):// handler: \($0)" }
            ?? "became the \(scheme):// handler (was \(currentHandler()?.lastPathComponent ?? "?"))")
    }
}

// MARK: - App

final class Delegate: NSObject, NSApplicationDelegate {
    var timer: Timer?

    func applicationWillFinishLaunching(_ n: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handle(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        log("started")
        claimScheme()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in claimScheme() }
    }

    @objc func handle(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: s) else { return }
        log("received \(safe(url))")
        route(url)
    }
}

// Check from the terminal: who is the handler and which windows are running.
if CommandLine.arguments.contains("--status") {
    print("\(scheme):// handler → \(currentHandler()?.path ?? "none")")
    for i in instances() { print("\(i.title): pid \(i.pid)\(i.profileDir.map { ", profile \($0)" } ?? "")") }
    exit(0)
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
