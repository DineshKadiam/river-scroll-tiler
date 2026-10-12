# Rill
A minimalist scrolling window manager for [river](https://isaacfreund.com/software/river/), implementing the [river-window-management-v1](https://isaacfreund.com/docs/wayland/river-window-management-v1/) protocol

## Features
* Scrolling layout
* Floating layout
* Workspaces
* Animations
* Live-reloading config
* Multi-output

<video src="https://pub-da8894d425e3482384b5adec2dcc2361.r2.dev/recording.mp4" controls> </video>

## Build
### Dependencies
* zig 0.17
* wayland
* wayland-protocols
* xkbcommon
```sh
zig build --release=safe
```

## Configuration
Rill searches for a config file at the following locations in order:  
`$XDG_CONFIG_HOME/rill/config.zon`  
`$HOME/.config/rill/config.zon`  
See the [default config](https://codeberg.org/lzj15/rill/src/branch/main/config.zon) as an example.

## Usage
[River](https://isaacfreund.com/software/river/) needs to be installed first.  
Run `rill` in [river's init file](https://codeberg.org/river/river#usage), or directly run `river -c rill`.

### Default Keybindings
| Keybinding | Action |
|----------|--------|
| `Super` `q` | Close window |
| `Super` `f` | Toggle maximize |
| `Super` `Shift` `f` | Toggle fullscreen |
| `Super` `v` | Toggle workspace floating |
| `Super` `minus` | Decrease window's width by a proportion of 0.1 |
| `Super` `equal` | Increase window's width by a proportion of 0.1 |
| `Super` `Escape` | Exit river |
| `Super` `r` | Reload config |
| `Super` `t` | Spawn Alacritty |
| `Super` `Left` | Focus window left |
| `Super` `Right` | Focus window right |
| `Super` `Shift` `Left` | Move window left |
| `Super` `Shift` `Right` | Move window right |
| `Super` `Up` | Focus workspace above |
| `Super` `Down` | Focus workspace below |
| `Super` `1~0` | Focus workspace 1~10 |
| `Super` `Shift` `Up` | Move window to workspace above |
| `Super` `Shift` `Down` | Move window to workspace below |
| `Super` `Shift` `1~0` | Move window to workspace 1~10 |
| `Super` `Ctrl` `Up` | Send window to workspace above |
| `Super` `Ctrl` `Down` | Send window to workspace below |
| `Super` `Ctrl` `1~0` | Send window to workspace 1~10 |
| `Super` `h` | Focus output left |
| `Super` `l` | Focus output right |
| `Super` `k` | Focus output above |
| `Super` `j` | Focus output below |
| `Super` `Shift` `h` | Move window to output left |
| `Super` `Shift` `l` | Move window to output right |
| `Super` `Shift` `k` | Move window to output above |
| `Super` `Shift` `j` | Move window to output below |
| `Super` `Ctrl` `h` | Send window to output left |
| `Super` `Ctrl` `l` | Send window to output right |
| `Super` `Ctrl` `k` | Send window to output above |
| `Super` `Ctrl` `j` | Send window to output below |

### Default Pointer Bindings
| Pointer Binding | Action |
|----------|--------|
| `Super` `Left Click` | Move floating window |
| `Super` `Right Click` | Resize floating window |
