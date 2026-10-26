#!/usr/bin/env python3
"""Exercise real Matugen exports and automatic reload in an isolated editor."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
NVIM_ARGS = ["--headless", "--clean", "-u", "NONE", "-i", "NONE", "-n", "-l"]
SEEDS = {
    "green": "#44aa77",
    "blue": "#4488ee",
    "orange": "#cc8822",
    "red": "#ee3344",
    "purple": "#bb4488",
    "neutral": "#888888",
}


def run(command, env):
    result = subprocess.run(
        [str(part) for part in command],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def lua_string(value):
    return json.dumps(str(value))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nvim", default="nvim")
    parser.add_argument("--matugen", default="matugen")
    parser.add_argument("--preview", action="store_true", help="Also regenerate assets/preview.svg")
    args = parser.parse_args()
    nvim = shutil.which(args.nvim)
    matugen = shutil.which(args.matugen)
    if not nvim or not matugen:
        parser.error("Neovim and Matugen 4 must be installed")

    with tempfile.TemporaryDirectory(prefix="matugen-nvim-bridge-") as temporary:
        directory = Path(temporary)
        env = os.environ.copy()
        for name in ("CONFIG", "CACHE", "DATA", "STATE"):
            env[f"XDG_{name}_HOME"] = str(directory / name.lower())

        config = directory / "matugen.toml"
        palette = directory / "palette.json"
        config.write_text(
            "[config]\n\n[templates.neovim]\n"
            f"input_path = {json.dumps(str(ROOT / 'templates/palette.json'))}\n"
            f"output_path = {json.dumps(str(palette))}\n",
            encoding="utf-8",
        )
        base = [matugen, "--config", config, "--quiet"]

        fixtures = directory / "fixtures"
        fixtures.mkdir()
        for mode in ("dark", "light"):
            for name, seed in SEEDS.items():
                result = subprocess.run(
                    [str(part) for part in base + ["--mode", mode, "--json", "hex", "color", "hex", seed]],
                    cwd=ROOT,
                    env=env,
                    text=True,
                    capture_output=True,
                    timeout=30,
                )
                if result.returncode:
                    raise RuntimeError(result.stdout + result.stderr)
                native = json.loads(result.stdout)
                (fixtures / f"{name}-{mode}.native.json").write_text(
                    json.dumps(native), encoding="utf-8"
                )
                shutil.copyfile(palette, fixtures / f"{name}-{mode}.flat.json")

        print(run([nvim, *NVIM_ARGS, ROOT / "tests/run.lua", fixtures], env), end="")

        # The editor remains open while a real Matugen invocation rewrites its input.
        run(base + ["--mode", "dark", "color", "hex", SEEDS["green"]], env)
        command = "{ " + ", ".join(
            lua_string(part) for part in base + ["--mode", "light", "color", "hex", SEEDS["blue"]]
        ) + " }"
        script = directory / "reload.lua"
        script.write_text(
            f"vim.opt.rtp:append({lua_string(ROOT)})\n"
            "local bridge = require('matugen_nvim_bridge')\n"
            f"bridge.setup({{ palette_path = {lua_string(palette)} }})\n"
            "assert(bridge.current.mode == 'dark')\n"
            "local original = bridge.current.ui.primary\n"
            f"vim.fn.system({command})\n"
            "assert(vim.v.shell_error == 0, 'Matugen generation failed')\n"
            "assert(vim.wait(3000, function()\n"
            "    return bridge.current.mode == 'light' and bridge.current.ui.primary ~= original\n"
            "end, 10), 'The open editor did not update after Matugen generation')\n"
            "assert(vim.o.background == 'light')\n"
            "assert(vim.g.colors_name == 'matugen-nvim-bridge')\n"
            "local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })\n"
            "assert(normal.bg == tonumber(bridge.current.background:sub(2), 16))\n"
            "for role, ratio in pairs(bridge.current.contrast) do\n"
            "    assert(ratio >= 4.5, 'Low contrast after reload: ' .. role)\n"
            "end\n"
            "vim.api.nvim_exec_autocmds('VimLeavePre', {})\n"
            "print('Live Matugen reload: editor, syntax, mode and contrast checks passed')\n",
            encoding="utf-8",
        )
        print(run([nvim, *NVIM_ARGS, script], env), end="")

        if args.preview:
            (ROOT / "assets").mkdir(exist_ok=True)
            print(run([
                nvim, *NVIM_ARGS, ROOT / "scripts/preview.lua",
                fixtures / "blue-dark.flat.json", fixtures / "blue-light.flat.json",
                ROOT / "assets/preview.svg",
            ], env), end="")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error)) from error
