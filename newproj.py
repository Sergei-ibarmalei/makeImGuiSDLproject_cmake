#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

PS_SCRIPT = r"D:\Code\Again\__Script_for_making_projects\imguisdl_maker\new_sdl_imgui_project.ps1"


def find_powershell_exe() -> str:
    # Prefer PowerShell 7
    for candidate in ("pwsh", "pwsh.exe", "powershell.exe"):
        p = shutil.which(candidate)
        if p:
            return p
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create C++ SDL2 + SDL2_image + ImGui project via PowerShell script."
    )
    parser.add_argument("name", help="Project folder name (you can use hyphens)")
    parser.add_argument("--git", action="store_true", help="Initialize git repo")
    parser.add_argument("--demo", action="store_true", help="Enable ImGui demo in generated presets")
    parser.add_argument("--ps1", default=PS_SCRIPT, help="Path to .ps1 script (optional override)")
    args = parser.parse_args()

    ps_exe = find_powershell_exe()
    if not ps_exe:
        print("ERROR: PowerShell not found (pwsh/powershell.exe). Install PowerShell or fix PATH.", file=sys.stderr)
        return 2

    ps1_path = Path(args.ps1)
    if not ps1_path.exists():
        print(f"ERROR: .ps1 script not found: {ps1_path}", file=sys.stderr)
        return 2

    # Build PowerShell command
    cmd = [
        ps_exe,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ps1_path),
        "-Name",
        args.name,
    ]
    if args.git:
        cmd.append("-git")
    if args.demo:
        cmd.append("-demo")

    print("Running:", " ".join(f'"{c}"' if " " in c else c for c in cmd))
    try:
        completed = subprocess.run(cmd, check=False)
        return completed.returncode
    except Exception as e:
        print(f"ERROR: Failed to run PowerShell: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
