#!/usr/bin/env python3
"""
Builds a release ZIP of NeonScript.

    python tools/build_release.py

Writes, into <pack>/dist/:
    NeonScript-<version>.zip     the pack plus install.ps1, README and LICENSE at the top
    latest.txt                   the update-feed file for this version (host it next to the release)
    SHA256SUMS.txt               hashes of the files above

Only files that belong to the pack are included - never your own settings (neon.ini, profiles.ini,
custom.ini, access.ini, chan.ini), logs, backups, topic history or imported themes.
"""
import datetime
import hashlib
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.normpath(os.path.join(HERE, ".."))
DIST = os.path.join(PACK, "dist")

# MTS themes written for NeonScript (others in data\mts are the user's imports and are not shipped)
SHIPPED_THEMES = {"irssi_night.mts", "bluebox_2003.mts", "green_terminal.mts"}
# message lists ship from data\defaults so a customised copy is never published
DEFAULT_LISTS = ["quit", "part", "kick", "slap", "away"]
TOP_FILES = ["README.md", "LICENSE", "CHANGELOG.md"]
TOOLS = ["make_assets.py", "mock_irc.py", "mock_web.py", "build_release.py", "install.ps1",
         os.path.join("dll", "neonsec.c"), os.path.join("dll", "neonsec.def"), os.path.join("dll", "build.cmd")]


def version():
    text = open(os.path.join(PACK, "neon.mrc"), encoding="utf-8").read()
    m = re.search(r"^alias ns\.ver return ([0-9][0-9.]*)\s*$", text, re.M)
    if not m:
        sys.exit("cannot read the version from neon.mrc")
    return m.group(1)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def collect():
    """Returns [(source path, path inside the 'neonscript' folder)]."""
    files = []
    for name in sorted(os.listdir(PACK)):
        if name.lower().endswith(".mrc") and name.lower().startswith("neon"):
            files.append((os.path.join(PACK, name), name))
    for name in TOP_FILES + ["neonsec.dll"]:
        p = os.path.join(PACK, name)
        if os.path.exists(p):
            files.append((p, name))
    for folder in ("assets",):
        for dirpath, _dirs, names in os.walk(os.path.join(PACK, folder)):
            for n in sorted(names):
                full = os.path.join(dirpath, n)
                files.append((full, os.path.relpath(full, PACK)))
    data = os.path.join(PACK, "data")
    for n in ("themes.ini", "networks.ini", "commands.txt", "popups_none.ini", "neonsec.sha256"):
        files.append((os.path.join(data, n), os.path.join("data", n)))
    for n in DEFAULT_LISTS:
        files.append((os.path.join(data, "defaults", "msg_%s.txt" % n), os.path.join("data", "msg_%s.txt" % n)))
        files.append((os.path.join(data, "defaults", "msg_%s.txt" % n), os.path.join("data", "defaults", "msg_%s.txt" % n)))
    for n in sorted(os.listdir(os.path.join(data, "mts"))):
        if n.lower() in SHIPPED_THEMES:
            files.append((os.path.join(data, "mts", n), os.path.join("data", "mts", n)))
    for n in TOOLS:
        p = os.path.join(PACK, "tools", n)
        if os.path.exists(p):
            files.append((p, os.path.join("tools", n)))
    return files


def main():
    ver = version()
    dll = os.path.join(PACK, "neonsec.dll")
    sumfile = os.path.join(PACK, "data", "neonsec.sha256")
    if os.path.exists(dll):
        want = open(sumfile).read().strip().lower()
        if sha256(dll) != want:
            sys.exit("neonsec.dll does not match data/neonsec.sha256 - rebuild it with tools\\dll\\build.cmd")
    files = collect()
    missing = [s for s, _ in files if not os.path.exists(s)]
    if missing:
        sys.exit("missing files:\n  " + "\n  ".join(missing))

    os.makedirs(DIST, exist_ok=True)
    top = "NeonScript-%s" % ver
    out = os.path.join(DIST, top + ".zip")
    if os.path.exists(out):
        os.remove(out)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for src, rel in files:
            z.write(src, "%s/neonscript/%s" % (top, rel.replace("\\", "/")))
        z.write(os.path.join(HERE, "install.ps1"), "%s/install.ps1" % top)
        z.write(os.path.join(PACK, "README.md"), "%s/README.md" % top)
        z.write(os.path.join(PACK, "LICENSE"), "%s/LICENSE" % top)

    feed = os.path.join(DIST, "latest.txt")
    with open(feed, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("[latest]\nversion=%s\nreleased=%s\nurl=\nnotes=\n" % (ver, datetime.date.today().isoformat()))
    with open(os.path.join(DIST, "SHA256SUMS.txt"), "w", encoding="utf-8", newline="\n") as fh:
        for p in (out, feed):
            fh.write("%s  %s\n" % (sha256(p), os.path.basename(p)))
    print("built", out, "(%d files, %.1f KB)" % (len(files) + 3, os.path.getsize(out) / 1024))
    print("feed ", feed, "- fill in url= and notes= before publishing")


if __name__ == "__main__":
    main()
