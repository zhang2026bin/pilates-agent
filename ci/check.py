#!/usr/bin/env python3
"""Validate DSH plugin bundles in this repository."""
import json
import re
import sys
from pathlib import Path

import yaml

SEMVER = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")
errors = []
root = Path(".").resolve()


class JsLoader(yaml.SafeLoader):
    pass


JsLoader.add_constructor("tag:yaml.org,2002:js", lambda loader, node: None)


def check_package(path: Path) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        errors.append(f"{path}: invalid JSON ({exc})")
        return
    name = data.get("name", "")
    if not name.startswith("dsh-"):
        errors.append(f"{path}: name '{name}' should start with 'dsh-'")
    version = data.get("version", "")
    if not SEMVER.match(version):
        errors.append(f"{path}: version '{version}' is not SemVer")
    dsh = data.get("dsh") or {}
    bundle = dsh.get("bundle")
    if bundle is not None:
        patch = bundle.get("patch")
        if not patch:
            errors.append(f"{path}: dsh.bundle.patch is required")
        elif not (path.parent / patch).exists():
            errors.append(f"{path}: dsh.bundle.patch '{patch}' does not exist")
    client = dsh.get("client")
    if client is not None and client.get("platform") != "web":
        errors.append(f"{path}: dsh.client.platform must be 'web'")


def check_patch(path: Path) -> None:
    try:
        data = yaml.load(path.read_text(encoding="utf-8"), Loader=JsLoader)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"{path}: invalid YAML ({exc})")
        return
    if not isinstance(data, list):
        errors.append(f"{path}: top level must be a list")
        return
    for row in data:
        if not isinstance(row, dict):
            continue
        for item in row.get("insert") or []:
            if not item.get("id") or not item.get("name"):
                errors.append(f"{path}: every insert row needs id and name")


packages = [p for p in root.rglob("package.json") if "node_modules" not in p.parts]
if not packages:
    errors.append("no package.json found")

for pkg in packages:
    check_package(pkg)

for patch in root.rglob("cordis.patch.yml"):
    check_patch(patch)

patches = list(root.rglob("cordis.patch.yml"))
install = root / "install.ps1"
if patches and not install.exists():
    errors.append("install.ps1 is required: presets reference absolute paths")
elif patches:
    script = install.read_text(encoding="utf-8", errors="ignore")
    patch_text = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in patches)
    for token in sorted(set(re.findall(r"\\agents\\([A-Za-z0-9_-]+)\\", patch_text))):
        if f"\\agents\\{token}\\" not in script:
            errors.append(f"install.ps1 does not rewrite '\\agents\\{token}\\'")

readme = root / "README.md"
if not readme.exists():
    errors.append("README.md is missing")
elif len(readme.read_text(encoding="utf-8")) < 500:
    errors.append("README.md is too short (<500 chars)")

if errors:
    print("Validation failed:")
    for err in errors:
        print(" -", err)
    sys.exit(1)

print(f"OK: {len(packages)} package(s), {len(list(root.rglob('cordis.patch.yml')))} patch file(s)")
