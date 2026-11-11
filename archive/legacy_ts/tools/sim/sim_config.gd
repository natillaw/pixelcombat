extends RefCounted
## D-083 simulator config: reads tools/sim/configs/*.json (// comments and "_comment" keys allowed), fills
## the defaults and expands "compare" x "sweep" into variants. Every variant is a full config the workers
## run as is. Validation of game ids (classes, items, constants...) lives in sim_main.gd.

const TOP_KEYS := ["name", "floors", "floor", "runs", "seed", "seeds", "max_time", "tick_hz", "workers", "bot", "party",
    "party_seed", "gear_seed", "enemies", "overrides", "compare", "sweep", "alerts", "label", "progress", "gear_style", "matrix"]
const BOT_KEYS := ["style", "retreat_hp", "retreat_standing", "ping_every", "use_commands", "use_skills", "revive",
    "aim_error_mult", "think_every", "engage", "gather", "knows_map", "regroup_wait", "camp", "camp_below", "loot"]
const HERO_KEYS := ["master", "class", "level", "stars", "rarity", "traits", "passives", "attrs", "skills", "gear", "seed", "name"]
const ENEMY_KEYS := ["hp", "damage", "count"]
## Hero rarity names -> stars (P-09 is pending: the code only has 1-5 stars, so a rarity is an alias).
const RARITY_STARS := {"common": 1, "comun": 1, "uncommon": 2, "poco_comun": 2, "rare": 3, "raro": 3, "epic": 4, "epico": 4,
    "legendary": 5, "legendario": 5}

const DEFAULTS := {
    "floors": [1],
    "runs": 10,
    "seed": 1000,
    "max_time": 1200.0,
    "tick_hz": 30,
    "party_seed": 1,
    "gear_seed": 1,
    "bot": {"style": "tactico", "retreat_hp": 0.3, "retreat_standing": 1, "ping_every": -1.0, "use_commands": true,
        "use_skills": true, "revive": true, "aim_error_mult": 1.0, "think_every": 0.25, "engage": 320.0, "gather": true,
        "knows_map": false, "regroup_wait": 3.0, "camp": true, "camp_below": 0.55, "loot": true},   # D-090 camp, pista D loot
    "progress": "",                  # "" = levels/gear of the party as written; else a profile of progress_profiles.json
    "gear_style": "mix",             # with a progress profile: "mix" (tierN), "def" (tierN_def) or "atk" (tierN_atk)
    "enemies": {"hp": 1.0, "damage": 1.0, "count": 1.0},
    "overrides": {},
    "alerts": {"impossible": 0.10, "trivial": 0.95},
    "party": [
        {"master": true, "class": "warrior", "level": 1, "gear": "kit_blanco"},
        {"class": "cleric", "level": 1, "stars": 2, "gear": "kit_blanco"},
        {"class": "archer", "level": 1, "stars": 2, "gear": "kit_blanco"},
        {"class": "mage", "level": 1, "stars": 2, "gear": "kit_blanco"},
        {"class": "rogue", "level": 1, "stars": 2, "gear": "kit_blanco"},
    ],
}


## JSON with // line comments (outside strings). Returns {"data": Dictionary} or {"error": String}.
static func load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"error": "config not found: %s" % path}
    var text := strip_comments(FileAccess.get_file_as_string(path))
    var j := JSON.new()
    if j.parse(text) != OK:
        return {"error": "%s line %d: %s" % [path, j.get_error_line(), j.get_error_message()]}
    if not (j.data is Dictionary):
        return {"error": "%s: the config must be a JSON object" % path}
    return {"data": j.data}


static func strip_comments(text: String) -> String:
    var out := PackedStringArray()
    for line in text.split("\n"):
        var in_str := false
        var esc := false
        var cut := -1
        for i in line.length():
            var ch := line[i]
            if esc:
                esc = false
                continue
            if ch == "\\":
                esc = true
            elif ch == "\"":
                in_str = not in_str
            elif not in_str and ch == "/" and i + 1 < line.length() and line[i + 1] == "/":
                cut = i
                break
        out.append(line.left(cut) if cut >= 0 else line)
    return "\n".join(out)


static func deep_merge(base: Variant, over: Variant) -> Variant:
    if base is Dictionary and over is Dictionary:
        var out: Dictionary = (base as Dictionary).duplicate(true)
        for k in over:
            out[k] = deep_merge(out.get(k), over[k]) if out.has(k) else _copy(over[k])
        return out
    return _copy(over)


static func _copy(v: Variant) -> Variant:
    return v.duplicate(true) if (v is Dictionary or v is Array) else v


## "1-10", 3, [1, 2, "5-7"] -> [1, 2, ...]
static func floors_of(v: Variant) -> Array:
    var out: Array = []
    var items: Array = v if v is Array else [v]
    for it in items:
        var s := str(it).strip_edges()
        if s.contains("-") and not s.begins_with("-"):
            var a := int(s.get_slice("-", 0))
            var b := int(s.get_slice("-", 1))
            for f in range(a, b + 1):
                out.append(f)
        else:
            out.append(int(float(s)))
    return out


## Unknown keys (typos) are errors; keys starting with "_" are comments.
static func check_keys(d: Dictionary, allowed: Array, where: String, errors: Array) -> void:
    for k in d:
        if String(k).begins_with("_"):
            continue
        if not allowed.has(String(k)):
            errors.append("%s: unknown key \"%s\" (allowed: %s)" % [where, k, ", ".join(allowed)])


static func _strip_private(v: Variant) -> Variant:
    if v is Dictionary:
        var out := {}
        for k in v:
            if not String(k).begins_with("_"):
                out[k] = _strip_private(v[k])
        return out
    if v is Array:
        return (v as Array).map(func(x): return _strip_private(x))
    return v


## The config -> [{"label", "config"}]. compare entries are merged over the base; a sweep sets one value
## per variant (a constant "Class.CONST[.key...]" goes to overrides, anything else is a config path such as
## "bot.retreat_hp" or "enemies.hp").
static func expand(raw: Dictionary, errors: Array) -> Array:
    raw = _strip_private(raw)
    check_keys(raw, TOP_KEYS, "config", errors)
    var base: Dictionary = deep_merge(DEFAULTS, raw)
    base.erase("compare")
    base.erase("sweep")
    if raw.has("floor") and not raw.has("floors"):
        base["floors"] = raw["floor"]
    base.erase("floor")
    base["floors"] = floors_of(base["floors"])
    if raw.has("party"):
        base["party"] = _copy(raw["party"])          # a party is replaced, never merged hero by hero
    var cmp: Array = raw.get("compare", [{}]) if raw.get("compare", []) is Array else []
    if raw.has("matrix"):
        cmp = matrix_variants(raw["matrix"], errors)
    if cmp.is_empty():
        cmp = [{}]
    var variants: Array = []
    for i in cmp.size():
        var c: Dictionary = cmp[i] if cmp[i] is Dictionary else {}
        var v: Dictionary = deep_merge(base, c)
        if c.has("party"):
            v["party"] = _copy(c["party"])
        if c.has("floor"):
            v["floors"] = floors_of(c["floor"])
            v.erase("floor")
        elif c.has("floors"):
            v["floors"] = floors_of(c["floors"])
        var label := String(c.get("label", raw.get("label", "base" if cmp.size() == 1 else "v%d" % (i + 1))))
        v.erase("label")
        var dims: Dictionary = c.get("_dims", {})
        v.erase("_dims")
        variants.append({"label": label, "config": v, "dims": dims, "pair": pair_key(label)})
    if raw.has("sweep"):
        var sw: Dictionary = raw["sweep"]
        var param := String(sw.get("param", ""))
        var values: Array = sw.get("values", [])
        if values.is_empty() and sw.has("from"):
            var a := float(sw["from"])
            var b := float(sw["to"])
            var st := float(sw.get("step", 0.0))
            if st <= 0.0:
                errors.append("sweep: \"step\" must be > 0")
                st = maxf(0.0001, b - a)
            var n := int(floor((b - a) / st + 0.0001))
            for k in n + 1:
                values.append(snappedf(a + st * k, 0.000001))
        if param == "" or values.is_empty():
            errors.append("sweep needs \"param\" and \"values\" or \"from\"/\"to\"/\"step\"")
        else:
            var out: Array = []
            for vv in variants:
                for val in values:
                    var cfg: Dictionary = (vv["config"] as Dictionary).duplicate(true)
                    set_param(cfg, param, val)
                    var lbl := "%s=%s" % [param.get_slice(".", param.get_slice_count(".") - 1) if is_constant(param) else param, _fmt(val)]
                    out.append({"label": lbl if variants.size() == 1 else "%s | %s" % [vv["label"], lbl], "config": cfg,
                        "sweep": {"param": param, "value": val}})
            variants = out
    for vv in variants:
        var cfg: Dictionary = vv["config"]
        check_keys(cfg["bot"], BOT_KEYS, "bot (%s)" % vv["label"], errors)
        check_keys(cfg["enemies"], ENEMY_KEYS, "enemies (%s)" % vv["label"], errors)
        for h in cfg["party"]:
            if h is Dictionary:
                check_keys(h, HERO_KEYS, "party (%s)" % vv["label"], errors)
            else:
                errors.append("party (%s): every hero must be an object" % vv["label"])
        cfg["bot"]["style"] = style_of(String(cfg["bot"]["style"]))
        if not ["tactical", "loco"].has(String(cfg["bot"]["style"])):
            errors.append("bot.style must be \"tactico\" or \"loco\" (got \"%s\")" % cfg["bot"]["style"])
    return variants


static func style_of(s: String) -> String:
    s = s.to_lower()
    return "tactical" if s in ["tactico", "táctico", "tactical"] else s


## A constant looks like "CombatRules.ARMOR_FLAT": a capitalised class, then an UPPER_CASE name.
static func is_constant(param: String) -> bool:
    if not param.contains("."):
        return false
    var head := param.get_slice(".", 0)
    var second := param.get_slice(".", 1)
    return head.length() > 0 and head[0] == head[0].to_upper() and head[0] != head[0].to_lower() and second == second.to_upper()


static func set_param(cfg: Dictionary, param: String, val: Variant) -> void:
    if is_constant(param):
        cfg["overrides"][param] = val
        return
    var parts := param.split(".")
    var d: Variant = cfg
    for i in parts.size() - 1:
        var k: Variant = parts[i]
        if d is Array:
            d = d[int(k)]
        else:
            if not (d as Dictionary).has(k):
                d[k] = {}
            d = d[k]
    if d is Array:
        d[int(parts[parts.size() - 1])] = val
    else:
        d[parts[parts.size() - 1]] = val


static func _fmt(v: Variant) -> String:
    if v is float:
        return String.num(v, 4)
    return str(v)


## The same variant with the bot style taken out: a "tactico" and a "loco" with the same pair are compared.
static func pair_key(label: String) -> String:
    var parts: Array = []
    for p in label.split("|"):
        var t := p.strip_edges()
        if not (t.to_lower() in ["tactico", "táctico", "tactical", "loco"]):
            parts.append(t)
    return " | ".join(parts)


## "matrix": {"master": [classes], "party": {"name": [heroes without the Master]}, "gear_style": [...],
## "bot": ["tactico", "loco"], "progress": [...]} -> every combination as a compare entry.
static func matrix_variants(m: Dictionary, errors: Array) -> Array:
    var out: Array = [{"label": "", "_dims": {}}]
    var masters: Array = m.get("master", ["warrior"])
    var parties: Dictionary = m.get("party", {})
    if parties.is_empty():
        errors.append("matrix.party: give at least one party archetype")
        return [{}]
    var next: Array = []
    for o in out:
        for mc in masters:
            for pn in parties:
                var party: Array = [{"master": true, "class": mc}]
                party.append_array((parties[pn] as Array).duplicate(true))
                next.append({"label": "%s | %s" % [mc, pn], "party": party, "_dims": {"master": mc, "party": pn}})
    out = next
    for key in ["gear_style", "progress"]:
        if m.has(key):
            next = []
            for o in out:
                for val in m[key]:
                    var c: Dictionary = (o as Dictionary).duplicate(true)
                    c[key] = val
                    c["label"] = "%s | %s" % [c["label"], val]
                    c["_dims"][key] = val
                    next.append(c)
            out = next
    next = []
    for o in out:
        for st in m.get("bot", ["tactico", "loco"]):
            var c: Dictionary = (o as Dictionary).duplicate(true)
            c["bot"] = {"style": st}
            c["label"] = "%s | %s" % [c["label"], st]
            c["_dims"]["bot"] = st
            next.append(c)
    return next
