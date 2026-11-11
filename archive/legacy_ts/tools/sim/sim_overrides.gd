extends RefCounted
## D-083: balance constants overridden at run time without touching the code. GDScript folds a constant
## into every script that uses it when they compile, so a value cannot be changed after start-up. Instead
## the parent writes a pack (zip) with patched COPIES of the scripts that declare the constants, and each
## worker loads that pack before any game script compiles (tools/sim/run_sim.gd). The files in the repo
## are never written.
##
## Names: "Class.CONST" (CombatRules.ARMOR_FLAT) or a key inside a Dictionary/Array constant
## ("EnemyDefs.SOME_TABLE.bandido_maton.hp", "TowerExpedition.FLOORS.1.threat").


## {"Class.CONST[.key...]": value} -> {"files": {res_path: new_source}, "errors": [...], "applied": [...]}
static func build(overrides: Dictionary) -> Dictionary:
    var errors: Array = []
    var applied: Array = []
    var classes := {}
    for c in ProjectSettings.get_global_class_list():
        classes[String(c["class"])] = String(c["path"])
    var per_const := {}                          # "Class.CONST" -> new value (after nested keys)
    var keys: Array = overrides.keys()
    keys.sort()
    for name in keys:
        var parts := String(name).split(".")
        if parts.size() < 2:
            errors.append("override \"%s\": use Class.CONSTANT" % name)
            continue
        var cls := parts[0]
        var cname := parts[1]
        if not classes.has(cls):
            errors.append("override \"%s\": there is no class %s" % [name, cls])
            continue
        var scr := load(classes[cls]) as Script
        var consts := scr.get_script_constant_map() if scr != null else {}
        if not consts.has(cname):
            errors.append("override \"%s\": %s has no constant %s" % [name, cls, cname])
            continue
        var key := "%s.%s" % [cls, cname]
        var cur: Variant = per_const.get(key, _copy(consts[cname]))
        if parts.size() == 2:
            var coerced: Variant = _coerce(cur, overrides[name])
            if coerced == null:
                errors.append("override \"%s\": a %s cannot take %s" % [name, type_string(typeof(cur)), str(overrides[name])])
                continue
            per_const[key] = coerced
        else:
            var err := _set_nested(cur, parts.slice(2), overrides[name])
            if err != "":
                errors.append("override \"%s\": %s" % [name, err])
                continue
            per_const[key] = cur
        applied.append("%s = %s" % [name, str(overrides[name])])
    var files := {}
    for key in per_const:
        var cls := String(key).get_slice(".", 0)
        var cname := String(key).get_slice(".", 1)
        var path: String = classes[cls]
        var src: String = files.get(path, FileAccess.get_file_as_string(path))
        var patched := patch_source(src, cname, var_to_str(per_const[key]))
        if patched == "":
            errors.append("override %s: could not find \"const %s\" in %s" % [key, cname, path])
            continue
        files[path] = patched
    return {"files": files, "errors": errors, "applied": applied}


## Writes the patched files into a zip pack (paths relative to res://). "" on success.
static func write_pack(files: Dictionary, zip_path: String) -> String:
    var z := ZIPPacker.new()
    if z.open(zip_path) != OK:
        return "cannot write %s" % zip_path
    for path in files:
        z.start_file(String(path).trim_prefix("res://"))
        z.write_file(String(files[path]).to_utf8_buffer())
        z.close_file()
    z.close()
    return ""


## Replaces the value of "const NAME ... = <value>" (the value may span lines: brackets are balanced,
## strings and # comments are skipped). Returns "" when the constant is not declared at the top level.
static func patch_source(src: String, cname: String, new_value: String) -> String:
    var re := RegEx.new()
    re.compile("(?m)^(static\\s+)?const\\s+" + cname + "\\b[^=\\n]*?:?=\\s*")
    var m := re.search(src)
    if m == null:
        return ""
    var start := m.get_end()
    var i := start
    var depth := 0
    var in_str := ""
    while i < src.length():
        var ch := src[i]
        if in_str != "":
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = ""
        elif ch == "\"" or ch == "'":
            in_str = ch
        elif ch == "#":
            if depth == 0:
                break                            # trailing comment of a one-line value
            while i < src.length() and src[i] != "\n":
                i += 1
            continue
        elif ch in ["(", "[", "{"]:
            depth += 1
        elif ch in [")", "]", "}"]:
            depth -= 1
        elif ch == "\n" and depth == 0:
            break
        i += 1
    return src.left(start) + new_value + src.substr(i)


static func _copy(v: Variant) -> Variant:
    return v.duplicate(true) if (v is Dictionary or v is Array) else v


## The JSON value in the constant's own type (int stays int, float stays float). null = incompatible.
static func _coerce(cur: Variant, val: Variant) -> Variant:
    match typeof(cur):
        TYPE_INT:
            if (val is float or val is int) and is_equal_approx(float(val), roundf(float(val))):
                return int(val)
            return null
        TYPE_FLOAT:
            return float(val) if (val is float or val is int) else null
        TYPE_BOOL:
            return bool(val) if val is bool else null
        TYPE_STRING, TYPE_STRING_NAME:
            return String(val) if val is String else null
        TYPE_DICTIONARY:
            return val if val is Dictionary else null
        TYPE_ARRAY:
            return val if val is Array else null
    return val


static func _set_nested(container: Variant, path: Array, val: Variant) -> String:
    var d: Variant = container
    for i in path.size():
        var k: String = path[i]
        var last := i == path.size() - 1
        if d is Dictionary:
            var key: Variant = k
            if not (d as Dictionary).has(key) and k.is_valid_int() and (d as Dictionary).has(int(k)):
                key = int(k)                     # tables keyed by floor number etc.
            if not (d as Dictionary).has(key):
                return "no key \"%s\"" % k
            if last:
                var c: Variant = _coerce(d[key], val)
                if c == null:
                    return "key \"%s\" is a %s, cannot take %s" % [k, type_string(typeof(d[key])), str(val)]
                d[key] = c
            else:
                d = d[key]
        elif d is Array:
            if not k.is_valid_int() or int(k) < 0 or int(k) >= (d as Array).size():
                return "index %s out of range" % k
            if last:
                var c2: Variant = _coerce(d[int(k)], val)
                if c2 == null:
                    return "index %s is a %s, cannot take %s" % [k, type_string(typeof(d[int(k)])), str(val)]
                d[int(k)] = c2
            else:
                d = d[int(k)]
        else:
            return "\"%s\" is not a table" % k
    return ""
