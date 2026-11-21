# Porto

A macOS menu bar app that lists the ports currently open (TCP listeners)
and lets you close them with a click.

## Run it

```sh
cd PortBar
swift run Porto
```

To print the discovered listening ports to the terminal instead of the menu
bar (handy for debugging the parser):

```sh
swift run Porto --dump-ports
```

## Build the .app

```sh
./scripts/build_app.sh
```

This builds a release binary and assembles a double-clickable `Porto.app`
(a menu bar item only; it has no Dock icon).

## Requirements

- macOS (status items need macOS 10.10+; `lsof` at `/usr/sbin/lsof` is the default on macOS)
- Xcode command line tools (`swift`)