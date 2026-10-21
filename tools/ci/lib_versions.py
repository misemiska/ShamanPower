#!/usr/bin/env python3
"""lib_versions: is every library ShamanPower ships the newest one out there?

LibStub hands every addon the highest version of a library that any addon loads, and a newer copy
loading later runs its upgrade over ours (2026-10-21: AceDBOptions-3.0 17 in another addon reset our
Profiles page). So ShamanPower ships the newest version of each library it bundles. This compares each
bundled file with:
  --online   the library's official source (Ace3's GitHub, WowAce trunk, the authors' GitHub)
  --local    every copy in the installed addons of every WoW client on this machine (default on)
and fails when ours is older. Run by sp-ci (local; online too with --release) and by shamanpower-package.

    python3 tools/ci/lib_versions.py [--tree T] [--online] [--no-local] [-v]
"""
import argparse, os, re, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

ACE3 = "https://raw.githubusercontent.com/WoWUIDev/Ace3/master/"
WOWACE = "https://repos.wowace.com/wow/"
WOW_DIR = os.environ.get("SP_WOW_DIR", os.path.expanduser("~/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft"))

# bundled file (under Libs/) -> its official source
SOURCES = {
    "AceAddon-3.0/AceAddon-3.0.lua": ACE3 + "AceAddon-3.0/AceAddon-3.0.lua",
    "AceBucket-3.0/AceBucket-3.0.lua": ACE3 + "AceBucket-3.0/AceBucket-3.0.lua",
    "AceComm-3.0/AceComm-3.0.lua": ACE3 + "AceComm-3.0/AceComm-3.0.lua",
    "AceComm-3.0/ChatThrottleLib.lua": ACE3 + "AceComm-3.0/ChatThrottleLib.lua",
    "AceConfig-3.0/AceConfig-3.0.lua": ACE3 + "AceConfig-3.0/AceConfig-3.0.lua",
    "AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua": ACE3 + "AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua",
    "AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua": ACE3 + "AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua",
    "AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua": ACE3 + "AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
    "AceConsole-3.0/AceConsole-3.0.lua": ACE3 + "AceConsole-3.0/AceConsole-3.0.lua",
    "AceDB-3.0/AceDB-3.0.lua": ACE3 + "AceDB-3.0/AceDB-3.0.lua",
    "AceDBOptions-3.0/AceDBOptions-3.0.lua": ACE3 + "AceDBOptions-3.0/AceDBOptions-3.0.lua",
    "AceEvent-3.0/AceEvent-3.0.lua": ACE3 + "AceEvent-3.0/AceEvent-3.0.lua",
    "AceGUI-3.0/AceGUI-3.0.lua": ACE3 + "AceGUI-3.0/AceGUI-3.0.lua",
    "AceLocale-3.0/AceLocale-3.0.lua": ACE3 + "AceLocale-3.0/AceLocale-3.0.lua",
    "AceTimer-3.0/AceTimer-3.0.lua": ACE3 + "AceTimer-3.0/AceTimer-3.0.lua",
    "CallbackHandler-1.0/CallbackHandler-1.0.lua": ACE3 + "CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "LibDBIcon-1.0/CallbackHandler-1.0/CallbackHandler-1.0.lua": ACE3 + "CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "LibSharedMedia-3.0/CallbackHandler-1.0/CallbackHandler-1.0.lua": ACE3 + "CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "LibStub/LibStub.lua": ACE3 + "LibStub/LibStub.lua",
    "LibDBIcon-1.0/LibStub/LibStub.lua": ACE3 + "LibStub/LibStub.lua",
    "LibSharedMedia-3.0/LibStub/LibStub.lua": ACE3 + "LibStub/LibStub.lua",
    "LibSharedMedia-3.0/LibSharedMedia-3.0/LibSharedMedia-3.0.lua": WOWACE + "libsharedmedia-3-0/trunk/LibSharedMedia-3.0/LibSharedMedia-3.0.lua",
    "LibDBIcon-1.0/LibDBIcon-1.0/LibDBIcon-1.0.lua": WOWACE + "libdbicon-1-0/trunk/LibDBIcon-1.0/LibDBIcon-1.0.lua",
    "LibDBIcon-1.0/LibDataBroker-1.1/LibDataBroker-1.1.lua": "https://raw.githubusercontent.com/tekkub/libdatabroker-1-1/master/LibDataBroker-1.1.lua",
    "LibUIDropDownMenu/LibUIDropDownMenu/LibUIDropDownMenu.lua": WOWACE + "libuidropdownmenu/trunk/LibUIDropDownMenu/LibUIDropDownMenu.lua",
    "LibSerialize/LibSerialize.lua": "https://raw.githubusercontent.com/rossnichols/LibSerialize/main/LibSerialize.lua",
    "LibDeflate/LibDeflate.lua": "https://raw.githubusercontent.com/SafeteeWoW/LibDeflate/main/LibDeflate.lua",
    "LibClassicDurations/core.lua": "https://raw.githubusercontent.com/rgd87/LibClassicDurations/master/core.lua",
}
# kept back on purpose, each with why (printed on every run, never a failure)
HELD = {
    "LibSharedMedia-3.0/Anniversary/LibSharedMedia-3.0.lua":
        "Anniversary keeps 3.0.9.3's LibSharedMedia: 12000004 (WoW: Forever only) reports a file an addon registers"
        " that isn't there, and WeakAuras 5.22.0 registers CartoonHop.ogg without shipping it (owner, 2026-10-21)",
}

SMW = "AceGUI-3.0-SharedMediaWidgets/AceGUI-3.0-SharedMediaWidgets/"
for w in ("BackgroundWidget", "BorderWidget", "FontWidget", "SoundWidget", "StatusbarWidget", "prototypes"):
    SOURCES[SMW + w + ".lua"] = WOWACE + "ace-gui-3-0-shared-media-widgets/trunk/AceGUI-3.0-SharedMediaWidgets/" + w + ".lua"

# a file's version, the first of these that matches (a number, or a release string for LibDeflate)
PATTERNS = [
    r'CTL_VERSION\s*=\s*(\d+)',
    r'widgetVersion\s*=\s*(\d+)',
    r'local\s+Type\s*,\s*Version\s*=\s*"[^"]+"\s*,\s*(\d+)',
    r'MINOR_VERSION\s*=\s*(\d+)',
    r'\w*MAJOR\w*\s*,\s*\w*MINOR\w*\s*=\s*"[^"]+"\s*,\s*(\d+)',
    r'\b\w*MINOR\w*\s*=\s*(\d+)',
    r'NewLibrary\(\s*"[^"]+"\s*,\s*(\d+)',
    r'_VERSION\s*=\s*"(\d[^"]*)"',
]

def version(text):
    # LibUIDropDownMenu up to r135: 90000 + its SVN revision
    m = re.search(r'MINOR_VERSION\s*=\s*(\d+)\s*\+\s*tonumber\(\(\s*"\$Rev:\s*(\d+)', text)
    if m:
        return int(m.group(1)) + int(m.group(2))
    for rx in PATTERNS:
        m = re.search(rx, text)
        if m:
            v = m.group(1)
            return int(v) if v.isdigit() else v
    return None

def newer(a, b):
    """is a newer than b"""
    if a is None or b is None: return False
    if isinstance(a, int) and isinstance(b, int): return a > b
    if isinstance(a, str) and isinstance(b, str):
        na, nb = [int(x) for x in re.findall(r'\d+', a)], [int(x) for x in re.findall(r'\d+', b)]
        return na > nb
    return False

def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()

def bundled(tree):
    """every library file we ship: SOURCES plus Ace3's GUI widgets"""
    libs = os.path.join(tree, "Libs")
    files = [rel for rel in SOURCES if os.path.isfile(os.path.join(libs, rel))]
    wdir = os.path.join(libs, "AceGUI-3.0", "widgets")
    if os.path.isdir(wdir):
        for n in sorted(os.listdir(wdir)):
            if n.endswith(".lua"):
                rel = "AceGUI-3.0/widgets/" + n
                SOURCES.setdefault(rel, ACE3 + rel)
                files.append(rel)
    return files

def fetch(url):
    try:
        with urllib.request.urlopen(url, timeout=25) as r:
            return r.read().decode("utf-8", "replace")
    except Exception as e:
        return e

def online(files):
    urls = sorted({SOURCES[f] for f in files})
    with ThreadPoolExecutor(max_workers=8) as ex:
        got = dict(zip(urls, ex.map(fetch, urls)))
    return {f: got[SOURCES[f]] for f in files}

def local_copies(files):
    """the highest version of each file among the installed addons (matched by its folder and name)"""
    want = {}
    for rel in files:
        parts = rel.split("/")
        want.setdefault(parts[-1].lower(), []).append((rel, parts[-2].lower() if len(parts) > 1 else ""))
    best = {}
    if not os.path.isdir(WOW_DIR):
        return best
    for client in sorted(os.listdir(WOW_DIR)):
        addons = os.path.join(WOW_DIR, client, "Interface", "AddOns")
        if not os.path.isdir(addons):
            continue
        for addon in os.listdir(addons):
            if addon.lower().startswith("shamanpower"):
                continue
            for d, _, fs in os.walk(os.path.join(addons, addon)):
                for f in fs:
                    for rel, parent in want.get(f.lower(), ()):
                        if os.path.basename(d).lower() != parent:
                            continue
                        v = version(read(os.path.join(d, f)))
                        if v is not None and (rel not in best or newer(v, best[rel][0])):
                            best[rel] = (v, "%s/%s" % (client, addon))
    return best

def check(tree, use_online=False, use_local=True, verbose=False):
    """(ok, lines)"""
    files = bundled(tree)
    ours = {f: version(read(os.path.join(tree, "Libs", f))) for f in files}
    lines, behind = [], []
    up = online(files) if use_online else {}
    loc = local_copies(files) if use_local else {}
    for f in files:
        o = ours[f]
        uv = None
        if use_online:
            u = up.get(f)
            if isinstance(u, Exception) or u is None:
                behind.append(f)
                lines.append("BEHIND? %s: could not read its official source (%s)" % (f, u))
                continue
            uv = version(u)
            if newer(uv, o):
                behind.append(f)
                lines.append("BEHIND  %s: ours %s, official newest %s" % (f, o, uv))
                continue
        # another addon's copy newer than ours: with the official source read, a copy newer than it is
        # that addon's own change (Questie's TreeGroup 50, ForeverAuras' FontWidget 15), a note;
        # without it, a warning to check
        lv = loc.get(f)
        if lv and newer(lv[0], o):
            lines.append("%s %s: ours %s, %s in %s" % ("note:" if use_online else "warn:", f, o, lv[0], lv[1])
                         + (" (official is %s: that addon's own copy)" % uv if use_online else ""))
        elif verbose:
            lines.append("ok      %s: %s" % (f, o))
    for f, why in HELD.items():
        if os.path.isfile(os.path.join(tree, "Libs", f)):
            lines.append("held: %s (%s): %s" % (f, version(read(os.path.join(tree, "Libs", f))), why))
    if use_online and not behind:
        lines.insert(0, "every bundled library matches its official newest")
    return (not behind), lines

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--tree", default=os.getcwd())
    ap.add_argument("--online", action="store_true")
    ap.add_argument("--no-local", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args()
    ok, lines = check(os.path.abspath(a.tree), a.online, not a.no_local, a.verbose)
    for l in lines:
        print(l)
    print("libraries: %s" % ("all newest" if ok else "UPDATE THE ONES ABOVE before shipping"))
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
