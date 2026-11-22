// Claude Router — принимает ссылки claude:// и отдаёт их нужному окну Claude.
//
// Зачем: два окна Claude (основное и «Claude 2» со своей папкой профиля) для macOS —
// одно приложение, и ссылку claude:// система отдаёт одному из них. Ответ входа
// через Google или SSO уходит не в то окно. Пока обработчик claude:// — роутер,
// Claude входит через окно входа Apple (ответ сразу в своё окно), а остальные
// ссылки роутер отдаёт окну, которое выберет человек.
//
// Claude при каждом запуске снова назначает себя обработчиком, поэтому роутер
// раз в 5 секунд проверяет и возвращает обработчик себе.

import AppKit

let claudeBundleId = "com.anthropic.claudefordesktop"
let claudeAppURL = URL(fileURLWithPath: "/Applications/Claude.app")
let scheme = "claude"

// MARK: - Журнал (без параметров ссылки: в ответах входа там коды)

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
    return keys.isEmpty ? base : "\(base) (параметры: \(keys.joined(separator: ", ")))"
}

// MARK: - Окна Claude

struct Instance {
    let app: NSRunningApplication
    let profileDir: String?   // nil — основное окно (папка по умолчанию)

    var pid: pid_t { app.processIdentifier }
    var title: String {
        guard let dir = profileDir else { return "Основной" }
        return (dir as NSString).lastPathComponent.replacingOccurrences(of: "-", with: " ")
    }
}

/// Аргументы запуска процесса (KERN_PROCARGS2): argc, путь, argv…
func arguments(of pid: pid_t) -> [String] {
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
    var buf = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > 4 else { return [] }
    let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
    var i = 4
    while i < size, buf[i] != 0 { i += 1 }          // путь к программе
    while i < size, buf[i] == 0 { i += 1 }          // выравнивание
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
        .sorted { ($0.profileDir ?? "") < ($1.profileDir ?? "") }   // основное — первым
}

// MARK: - Передача ссылки конкретному процессу

/// Событие «открыть ссылку» (GURL) адресом процесса — macOS не выбирает окно сам.
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
        log("отдал \(safe(url)) → \(inst.title) (pid \(inst.pid))")
        return true
    } catch {
        log("не смог отдать \(safe(url)) → \(inst.title) (pid \(inst.pid)): \(error)")
        return false
    }
}

func choose(for url: URL, among list: [Instance]) -> Instance? {
    // Проверка без окна: `defaults write local.claude.router testPick "Claude 2"` —
    // один раз выбирает окно по имени и сбрасывается.
    if let pick = UserDefaults.standard.string(forKey: "testPick") {
        UserDefaults.standard.removeObject(forKey: "testPick")
        log("проверка: выбор «\(pick)» без окна")
        return list.first { $0.title == pick }
    }
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "В какое окно Claude открыть ссылку?"
    var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
    c?.query = nil
    alert.informativeText = c?.string ?? url.absoluteString
    for inst in list { alert.addButton(withTitle: inst.title) }
    alert.addButton(withTitle: "Отмена")
    let r = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    return r >= 0 && r < list.count ? list[r] : nil
}

func route(_ url: URL) {
    let list = instances()
    switch list.count {
    case 0:
        log("окон Claude нет — запускаю основное с \(safe(url))")
        NSWorkspace.shared.open([url], withApplicationAt: claudeAppURL,
                                configuration: NSWorkspace.OpenConfiguration())
    case 1:
        _ = send(url, to: list[0])
    default:
        if let inst = choose(for: url, among: list) { _ = send(url, to: inst) }
        else { log("отмена: \(safe(url))") }
    }
}

// MARK: - Обработчик claude://

func currentHandler() -> URL? {
    NSWorkspace.shared.urlForApplication(toOpen: URL(string: "\(scheme)://x")!)
}

func claimScheme() {
    let me = Bundle.main.bundleURL.standardizedFileURL
    guard currentHandler()?.standardizedFileURL != me else { return }
    NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: scheme) { error in
        log(error.map { "не смог стать обработчиком \(scheme)://: \($0)" }
            ?? "стал обработчиком \(scheme):// (был \(currentHandler()?.lastPathComponent ?? "?"))")
    }
}

// MARK: - Приложение

final class Delegate: NSObject, NSApplicationDelegate {
    var timer: Timer?

    func applicationWillFinishLaunching(_ n: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handle(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        log("запущен")
        claimScheme()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in claimScheme() }
    }

    @objc func handle(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: s) else { return }
        log("пришла \(safe(url))")
        route(url)
    }
}

// Режим проверки из терминала: что запущено и кто обработчик.
if CommandLine.arguments.contains("--status") {
    print("обработчик \(scheme):// → \(currentHandler()?.path ?? "нет")")
    for i in instances() { print("\(i.title): pid \(i.pid)\(i.profileDir.map { ", папка \($0)" } ?? "")") }
    exit(0)
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
