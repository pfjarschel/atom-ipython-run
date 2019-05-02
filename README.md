# atom-ipython-run
Run `python` file being edited in `Atom` in an `ipython` session running inside a `terminal`, that remains open after execution for more interactivity. The same session is used in all subsequent runs. Tested on *Manjaro Linux*, but should work in any other distro. Supports Mac OS X and Windows (not yet, really) as well. On OS X, the reference terminal application is [`iTerm2`](https://www.iterm2.com/), on Windows the standard terminal is called, and on Linux any terminal emulator can be used.

On *Linux*, it requires `xdotool` and `wmctrl` to be installed; please install it with your distro package managers, for example:
Ubuntu/Debian:
```bash
sudo apt-get install xdotool wmctrl
```

Arch:
```bash
sudo pacman -S xdotool wmctrl
```

**Note:** This package is a fork of [atom-ipython-exec](https://github.com/daducci/atom-ipython-exec), which in turn is a fork of [r-exec](https://github.com/pimentel/atom-r-exec).
