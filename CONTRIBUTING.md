# Contributing

Bug reports and focused pull requests are welcome.

## Development

The runtime is Lua and uses Neovim's built-in APIs. Keep it free of external
runtime dependencies and configuration specific to one machine.

Run the core suite with Neovim 0.10.4 or newer:

```sh
make test
```

With Matugen 4 and Python 3.10 or newer installed, also run:

```sh
make test-matugen
```

The integration suite generates twelve palettes in a temporary directory, checks
flat templates against native exports, and verifies that an open editor updates
after a real Matugen run. It uses an isolated configuration and does not touch
your wallpaper or Matugen configuration.

Changes to color generation should retain contrast checks in light and dark
mode. Changes to reloading should cover invalid input, atomic file replacement,
colorscheme switching and repeated setup.

Use four spaces for Lua and Python. Keep public options small, document any
behavior changes in the README and Neovim help, and add a changelog entry.

## Reporting a bug

Include your Neovim and Matugen versions, a minimal setup, the input JSON format,
and the output of `:checkhealth matugen_nvim_bridge`. A small palette that reproduces
the issue is usually more useful than a full editor configuration.
