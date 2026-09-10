import AppKit

// ponytail: single-file menu bar wrapper around /usr/bin/caffeinate — no Xcode project needed
final class App: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var process: Process?
    var offTimer: Timer?

    // flag -> (title, on by default)
    let flags: [(flag: String, title: String)] = [
        ("-d", "Prevent display sleep"),
        ("-i", "Prevent idle system sleep"),
        ("-m", "Prevent disk sleep"),
        ("-s", "Prevent sleep on AC power"),
        ("-u", "Declare user is active"),
    ]
    var enabledFlags: Set<String> = ["-d", "-i"]
    var timeoutSeconds: Int = 0  // 0 = indefinitely
    let durations: [(title: String, seconds: Int)] = [
        ("Indefinitely", 0),
        ("15 minutes", 15 * 60),
        ("30 minutes", 30 * 60),
        ("1 hour", 3600),
        ("2 hours", 2 * 3600),
        ("4 hours", 4 * 3600),
        ("8 hours", 8 * 3600),
    ]

    var isActive: Bool { process?.isRunning ?? false }

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.action = #selector(toggle)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
    }

    @objc func toggle() {
        // right-click (or ctrl-click) shows the menu; left-click toggles
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }
        isActive ? stop() : start()
    }

    func showMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: isActive ? "Caffeinate: On" : "Caffeinate: Off",
                                action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(NSMenuItem(title: isActive ? "Disable" : "Enable",
                                action: #selector(toggleFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())

        for f in flags {
            let item = NSMenuItem(title: f.title, action: #selector(toggleFlag(_:)), keyEquivalent: "")
            item.representedObject = f.flag
            item.state = enabledFlags.contains(f.flag) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let durMenu = NSMenu()
        for d in durations {
            let item = NSMenuItem(title: d.title, action: #selector(setDuration(_:)), keyEquivalent: "")
            item.representedObject = d.seconds
            item.state = timeoutSeconds == d.seconds ? .on : .off
            durMenu.addItem(item)
        }
        let durItem = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        durItem.submenu = durMenu
        menu.addItem(durItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // so left-click keeps toggling
    }

    @objc func toggleFromMenu() { isActive ? stop() : start() }

    @objc func toggleFlag(_ sender: NSMenuItem) {
        guard let flag = sender.representedObject as? String else { return }
        if enabledFlags.contains(flag) { enabledFlags.remove(flag) } else { enabledFlags.insert(flag) }
        if enabledFlags.isEmpty { enabledFlags = ["-i"] }  // caffeinate with no flags = -i anyway
        if isActive { stop(); start() }  // apply new flags immediately
    }

    @objc func setDuration(_ sender: NSMenuItem) {
        timeoutSeconds = sender.representedObject as? Int ?? 0
        if isActive { stop(); start() }
    }

    func start() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        var args = Array(enabledFlags).sorted()
        if timeoutSeconds > 0 { args += ["-t", String(timeoutSeconds)] }
        p.arguments = args
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.process = nil
                self?.updateIcon()
            }
        }
        do {
            try p.run()
            process = p
        } catch {
            NSSound.beep()
        }
        updateIcon()
    }

    func stop() {
        process?.terminate()
        process = nil
        updateIcon()
    }

    func updateIcon() {
        let name = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        statusItem.button?.image = NSImage(systemSymbolName: name,
                                           accessibilityDescription: "Caffeinate")
        // nil = standard menu bar color (adapts to light/dark); green = active
        statusItem.button?.contentTintColor = isActive ? .systemGreen : nil
        statusItem.button?.toolTip = isActive ? "Caffeinate is on — click to disable"
                                              : "Caffeinate is off — click to enable"
    }

    @objc func quit() {
        stop()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ note: Notification) { stop() }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
app.run()
