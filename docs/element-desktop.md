[← Back to README](../README.md)

# `scripts/element-desktop.sh`

Wrapper around Element's binary that forces `--password-store=gnome-libsecret`.

Symlinked to `~/.local/bin/element-desktop` by [`init.sh`](./init.md).

## Why

Chromium (which Electron apps like Element embed) only auto-picks the `libsecret` backend for OSCrypt on desktop environments it recognizes (GNOME, KDE, ...). niri isn't one of those, so without this override Chromium silently falls back to an unencrypted `basic_text` store for anything it encrypts locally (e.g. Element's access token).

```bash
exec /usr/bin/element-desktop --password-store=gnome-libsecret "$@"
```

## Caveat: not used by the app launcher

The wrapper only applies when `element-desktop` is resolved through `$PATH` with `~/.local/bin` ahead of `/usr/bin`, e.g. from a terminal. The package's desktop entry (`/usr/share/applications/io.element.Element.desktop`) hardcodes `Exec=/usr/bin/element-desktop %u`, so launching Element from fuzzel bypasses it and uses the unencrypted store. This repo doesn't ship a `~/.local/share/applications` override for it.
