"""Generate yancer-quests/Data/QuestDB.lua from the pfQuest-wotlk database.

pfQuest-wotlk (https://github.com/Sattva-108/pfQuest-wotlk, MIT, (c) Shagu) ships
about 26 MB of Lua. yancer-quests only needs each quest's objectives and where
they come from, so this keeps:

  quests[questID]  = { k = {unitId, ...},                     -- mobs to kill
                       i = { [itemId] = { u = {unitId, chance, ...},  -- item drops from
                                          o = {objectId, ...} } },    -- item found in
                       o = {objectId, ...} }                  -- objects to use
  units[id]   = { "Name", zoneId }  (only units referenced above)
  objects[id] = "Name"
  items[id]   = "Name"
  zones[id]   = "Zone"

Usage: python -I tools/gen_questdb.py [folder with the pfQuest db files]
Without a folder the files are downloaded to a temp folder first.
"""
import os
import re
import sys
import tempfile
import urllib.request
from collections import Counter

BASE = "https://raw.githubusercontent.com/Sattva-108/pfQuest-wotlk/master/db/"
FILES = {
    "quests.lua": "quests.lua",
    "items.lua": "items.lua",
    "refloot.lua": "refloot.lua",
    "units.lua": "units.lua",
    "objects.lua": "objects.lua",
    "enUS_units.lua": "enUS/units.lua",
    "enUS_items.lua": "enUS/items.lua",
    "enUS_objects.lua": "enUS/objects.lua",
    "enUS_zones.lua": "enUS/zones.lua",
}
OUT = os.path.join(os.path.dirname(__file__), "..", "yancer-quests", "Data", "QuestDB.lua")
MAX_UNITS = 8    # drop sources kept per item (highest chance first)
MAX_OBJECTS = 5

TOKEN = re.compile(r"""
    \s+ | --[^\n]* |
    (?P<str>"(?:[^"\\]|\\.)*") |
    (?P<num>-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?) |
    (?P<name>[A-Za-z_][A-Za-z_0-9]*) |
    (?P<sym>[{}\[\]=,;])
""", re.VERBOSE)


def tokens(text):
    pos, n = 0, len(text)
    while pos < n:
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError("bad character at %d: %r" % (pos, text[pos:pos + 20]))
        pos = m.end()
        kind = m.lastgroup
        if kind:
            yield kind, m.group(kind)


ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}


def unquote(s):
    return re.sub(r"\\(.)", lambda m: ESCAPES.get(m.group(1), m.group(1)), s[1:-1])


class Parser:
    def __init__(self, text):
        self.toks = list(tokens(text))
        self.i = 0

    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else (None, None)

    def take(self, value=None):
        tok = self.toks[self.i]
        if value is not None and tok[1] != value:
            raise ValueError("expected %r, got %r at token %d" % (value, tok, self.i))
        self.i += 1
        return tok

    def value(self):
        kind, v = self.take()
        if kind == "num":
            return float(v) if ("." in v or "e" in v.lower()) else int(v)
        if kind == "str":
            return unquote(v)
        if kind == "name":
            return {"true": True, "false": False, "nil": None}[v]
        if v == "{":
            return self.table()
        raise ValueError("unexpected %r" % v)

    def table(self):
        result, idx = {}, 1
        while self.peek()[1] != "}":
            kind, v = self.peek()
            if v == "[":
                self.take()
                key = self.value()
                self.take("]")
                self.take("=")
                result[key] = self.value()
            elif kind == "name" and self.toks[self.i + 1][1] == "=":
                self.take()
                self.take("=")
                result[v] = self.value()
            else:
                result[idx] = self.value()
                idx += 1
            if self.peek()[1] in (",", ";"):
                self.take()
        self.take("}")
        return result


def load(path):
    """Parses a file of the form pfDB["a"]["b"] = { ... }."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    start = text.index("=", text.index("pfDB")) + 1
    p = Parser(text[start:])
    return p.value()


def seq(t):
    """A Lua array table parsed as {1: a, 2: b} -> [a, b]."""
    if not isinstance(t, dict):
        return []
    return [t[k] for k in sorted(k for k in t if isinstance(k, int))]


def fetch(folder):
    for local, remote in FILES.items():
        path = os.path.join(folder, local)
        if not os.path.exists(path):
            print("downloading", remote)
            urllib.request.urlretrieve(BASE + remote, path)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def num(x):
    if isinstance(x, float):
        r = round(x, 2)
        return str(int(r)) if r == int(r) else ("%g" % r)
    return str(x)


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(tempfile.gettempdir(), "pfquest-wotlk-db")
    os.makedirs(folder, exist_ok=True)
    fetch(folder)
    L = lambda name: load(os.path.join(folder, name))  # noqa: E731

    quests = L("quests.lua")
    items = L("items.lua")
    refloot = L("refloot.lua")
    units = L("units.lua")
    unit_names = L("enUS_units.lua")
    item_names = L("enUS_items.lua")
    object_names = L("enUS_objects.lua")
    zone_names = L("enUS_zones.lua")
    print("parsed: %d quests, %d items, %d units" % (len(quests), len(items), len(units)))

    def item_sources(item_id):
        data = items.get(item_id) or {}
        drops, objs = Counter(), Counter()
        for uid, chance in (data.get("U") or {}).items():
            drops[uid] = max(drops[uid], chance)
        for oid, chance in (data.get("O") or {}).items():
            objs[oid] = max(objs[oid], chance)
        # Reference loot: the item is in a shared loot table that these units/objects use.
        for ref, chance in (data.get("R") or {}).items():
            r = refloot.get(ref) or {}
            for uid in (r.get("U") or {}):
                drops[uid] = max(drops[uid], chance)
            for oid in (r.get("O") or {}):
                objs[oid] = max(objs[oid], chance)
        drops = [(u, c) for u, c in drops.most_common() if u in unit_names][:MAX_UNITS]
        objs = [o for o, _ in objs.most_common() if o in object_names][:MAX_OBJECTS]
        return drops, objs

    used_units, used_objects, used_items = set(), set(), set()
    out_quests = {}
    for qid, q in quests.items():
        obj = q.get("obj") or {}
        kill = [u for u in seq(obj.get("U")) if u in unit_names]
        use = [o for o in seq(obj.get("O")) if o in object_names]
        its = {}
        for item_id in seq(obj.get("I")):
            if item_id not in item_names:
                continue
            drops, objs = item_sources(item_id)
            its[item_id] = (drops, objs)
            used_items.add(item_id)
            used_units.update(u for u, _ in drops)
            used_objects.update(objs)
        if not (kill or use or its):
            continue
        used_units.update(kill)
        used_objects.update(use)
        out_quests[qid] = (kill, its, use)

    def main_zone(uid):
        coords = seq((units.get(uid) or {}).get("coords"))
        zones = Counter(seq(c)[2] for c in coords if len(seq(c)) >= 3)
        return zones.most_common(1)[0][0] if zones else 0

    unit_zone = {u: main_zone(u) for u in used_units}
    used_zones = {z for z in unit_zone.values() if z in zone_names}

    lines = [
        "-- Generated by tools/gen_questdb.py. Do not edit by hand.",
        "-- Data from pfQuest-wotlk (https://github.com/Sattva-108/pfQuest-wotlk),",
        "-- MIT License, Copyright (c) 2017-2021 Eric Mauser (Shagu). See LICENSE-pfQuest.txt.",
        "local _, ns = ...",
        "local DB = {}",
        "ns.DB = DB",
        "",
        "DB.quests = {",
    ]
    for qid in sorted(out_quests):
        kill, its, use = out_quests[qid]
        parts = []
        if kill:
            parts.append("k={%s}" % ",".join(map(str, kill)))
        if its:
            entries = []
            for item_id in sorted(its):
                drops, objs = its[item_id]
                sub = []
                if drops:
                    sub.append("u={%s}" % ",".join("%d,%s" % (u, num(c)) for u, c in drops))
                if objs:
                    sub.append("o={%s}" % ",".join(map(str, objs)))
                entries.append("[%d]={%s}" % (item_id, ",".join(sub)))
            parts.append("i={%s}" % ",".join(entries))
        if use:
            parts.append("o={%s}" % ",".join(map(str, use)))
        lines.append("\t[%d]={%s}," % (qid, ",".join(parts)))
    lines.append("}")
    lines.append("")
    lines.append("DB.units = {")
    for uid in sorted(used_units):
        z = unit_zone[uid] if unit_zone[uid] in used_zones else 0
        lines.append("\t[%d]={%s,%d}," % (uid, lua_str(unit_names[uid]), z))
    lines.append("}")
    lines.append("")
    for name, ids, names in (("objects", used_objects, object_names), ("items", used_items, item_names),
                             ("zones", used_zones, zone_names)):
        lines.append("DB.%s = {" % name)
        for i in sorted(ids):
            lines.append("\t[%d]=%s," % (i, lua_str(names[i])))
        lines.append("}")
        lines.append("")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote %s: %d quests, %d units, %d objects, %d items, %d zones, %d KB" % (
        os.path.normpath(OUT), len(out_quests), len(used_units), len(used_objects), len(used_items),
        len(used_zones), os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
