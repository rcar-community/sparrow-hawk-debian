#!/usr/bin/env python3
import json
import hashlib
import os
import sys
import tempfile
import subprocess
from datetime import datetime

# Usage:
#   python3 scripts/04_update_repo_json.py <repo_json_path> <icon_url> \
#     <image_xz_path> <image_url> <variant> [<image_xz_path> <image_url> <variant> ...]
#
# <variant> is the name of the desktop environment (ex. xfce), or "" for the
# headless image.
#
# Example:
#   python3 scripts/04_update_repo_json.py out/repo.json \
#     https://example.com/icons/myos.png \
#     out/myos.img.xz https://example.com/images/myos.img.xz "" \
#     out/myos-xfce.img.xz https://example.com/images/myos-xfce.img.xz xfce

repo_path = sys.argv[1]
icon_url = sys.argv[2]
images = [sys.argv[i:i + 3] for i in range(3, len(sys.argv), 3)]
if not images or any(len(i) != 3 for i in images):
    sys.exit("Usage: <repo_json_path> <icon_url> (<image_xz_path> <image_url> <variant>)...")

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def xz_decompress_to_temp_img(xz_file: str) -> str:
    """
    Decompress .img.xz into a temporary .img file using system 'xz'.
    Returns the temp file path. Caller must delete it.
    """
    # Create temp file (we want a path, not an already-open fd, to let xz write it)
    fd, tmp_img = tempfile.mkstemp(prefix="imager_extract_", suffix=".img")
    os.close(fd)

    # xz -dc input.xz > tmp_img
    # Use -T0 for parallel threads if supported; harmless if not.
    cmd = ["xz", "-dc", xz_file]
    with open(tmp_img, "wb") as out:
        subprocess.run(cmd, check=True, stdout=out)

    return tmp_img

def image_metadata(xz_path: str) -> dict:
    # Compressed download metadata (.img.xz)
    meta = {
        "image_download_size": os.path.getsize(xz_path),
        "image_download_sha256": sha256_file(xz_path),
    }
    # Extracted image metadata (temporary .img)
    tmp_img = None
    try:
        tmp_img = xz_decompress_to_temp_img(xz_path)
        meta["extract_size"] = os.path.getsize(tmp_img)
        meta["extract_sha256"] = sha256_file(tmp_img)
    finally:
        if tmp_img and os.path.exists(tmp_img):
            try:
                os.remove(tmp_img)
            except Exception:
                pass
    return meta

# ? release_date = script run date (local)
release_date = datetime.now().date().isoformat()

# ---- Device profiles (Pi4 + Pi5 + no filtering) ----
imager_block = {
    "latest_version": "2.0.0",
    "url": "https://www.raspberrypi.com/software/",
    "devices": [
        {
            "name": "No filtering",
            "tags": ["all"],
            "default": True,
            "matching_type": "inclusive",
            "description": "Show all images without filtering"
        },
        {
            "name": "Sparrow Hawk 8GB/16GB",
            "icon": icon_url.replace("sh-mascot","sh"),
            "tags": ["sh"],
            "matching_type": "exclusive",
            "description": "Retronix SparrowHawk (R-Car V4H)"
        },
    ]
}

# ---- OS entries ----
os_list = []
for xz_path, image_url, variant in images:
    meta = image_metadata(xz_path)
    name = "SparrowHawk Debian based OS"
    description = "Debian based rootfs + cloud-init"
    if variant:
        name += f" ({variant})"
        description += f" + {variant} desktop"
    os_list.append({
        "name": name,
        "description": description,
        "icon": icon_url,
        "url": image_url,
        "release_date": release_date,
        "init_format": "cloudinit",

        # Pi4/Pi5 + no-filter
        "devices": ["sh", "all"],

        **meta
    })
    print(f"{name}: {xz_path}")
    for k, v in meta.items():
        print(f"  {k}: {v}")

repo = {
    "imager": imager_block,
    "os_list": os_list
}

os.makedirs(os.path.dirname(repo_path) or ".", exist_ok=True)
with open(repo_path, "w", encoding="utf-8") as f:
    json.dump(repo, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Wrote: {repo_path}")
print(f"release_date: {release_date}")
