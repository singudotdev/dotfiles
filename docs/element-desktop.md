[← Back to README](../README.md)

# `scripts/element-desktop.sh`

One-line wrapper around Element's own binary that forces `--password-store=gnome-libsecret`.

Symlinked to `~/.local/bin/element-desktop` by [`init.sh`](./init.md).

## Why

Chromium (which Electron apps like Element embed) only auto-picks the `libsecret` backend for OSCrypt on desktop environments it recognizes (GNOME, KDE, ...). niri isn't one of those, so without this override Chromium silently falls back to an unencrypted `basic_text` store for anything it encrypts locally (e.g. Element's access token).

```bash
exec /usr/bin/element-desktop --password-store=gnome-libsecret "$@"
```

## Caveat: not wired into the app launcher

This only takes effect when something invokes the bare `element-desktop` command through `$PATH` (a shell, or a launcher `Exec=` line that isn't a full path) with `~/.local/bin` ahead of `/usr/bin`. The package's actual desktop entry (`/usr/share/applications/io.element.Element.desktop`) hardcodes `Exec=/usr/bin/element-desktop %u`, bypassing `$PATH` entirely — so launching Element from fuzzel or any other `.desktop`-based app grid skips this wrapper and gets the default (unencrypted) store regardless. As of writing, nothing in this repo ships a `~/.local/share/applications` override to fix that — the wrapper is only confirmed effective from a terminal.
