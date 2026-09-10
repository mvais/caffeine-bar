# caffeine-bar

A tiny macOS menu bar app for toggling [`caffeinate`](https://ss64.com/mac/caffeinate.html) — keep your Mac awake without opening a terminal.

☕ **Left-click** the cup in the menu bar to toggle. Filled mocha-brown cup = awake, outline = normal sleep behavior.

🖱️ **Right-click** (or ⌃-click) for settings:

- Prevent display sleep (`-d`)
- Prevent idle system sleep (`-i`)
- Prevent disk sleep (`-m`)
- Prevent sleep on AC power (`-s`)
- Declare user is active (`-u`)
- Duration: indefinitely, 15/30 min, 1/2/4/8 hours (`-t`)

Changing a setting while active restarts `caffeinate` with the new flags. Quitting the app always kills the `caffeinate` process, so your Mac can never get stuck awake.

No dependencies, no dock icon, no background daemons — just a ~180-line wrapper around the `caffeinate` binary that ships with macOS.

## Install

Requires macOS 12+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/mvais/caffeine-bar.git
cd caffeine-bar
./build.sh
mv Caffeinate.app /Applications
open /Applications/Caffeinate.app
```

To launch at login: System Settings → General → Login Items → add Caffeinate.

The app is ad-hoc signed, so if Gatekeeper complains on first launch, right-click the app → Open.

## Source

- `main.m` — the app (Objective-C, built by `build.sh`)
- `main.swift` — identical Swift implementation, kept for when your toolchain prefers it; swap the compile line in `build.sh` to use it

## License

[MIT](LICENSE)
