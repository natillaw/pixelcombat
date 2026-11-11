extends RefCounted
## D-083 simulator report: aggregates the run results per variant and floor and writes runs.csv,
## heroes.csv, results.json and resumen.md (mean ± standard deviation, alerts) into the report folder.


## runs: every run result (with "variant"). Returns the summary rows (no timings: comparable across runs).
static func aggregate(variants: Array, runs: Array) -> Array:
    var rows: Array = []
    for v in variants:
        var label := String(v["label"])
        for f in (v["config"]["floors"] as Array):
            var rs: Array = runs.filter(func(r): return String(r["variant"]) == label and int(r["floor"]) == int(f))
            if rs.is_empty():
                continue
            var row := {"variant": label, "floor": int(f), "style": String(v["config"]["bot"]["style"]), "runs": rs.size(),
                "mission": String(rs[0]["mission"]), "party": int(rs[0]["party"]), "sweep": v.get("sweep", {}),
                "pair": String(v.get("pair", label)), "dims": v.get("dims", {})}
            row["win_rate"] = float(rs.filter(func(r): return bool(r["win"])).size()) / float(rs.size())
            for key in ["time", "downs", "deaths", "killed", "consumables_used", "reward_items"]:
                row[key] = _ms(rs.map(func(r): return float(r[key])))
            row["time_win"] = _ms(rs.filter(func(r): return bool(r["win"])).map(func(r): return float(r["time"])))
            var reasons := {}
            for r in rs:
                if String(r["reason"]) != "":
                    reasons[r["reason"]] = int(reasons.get(r["reason"], 0)) + 1
            row["reasons"] = reasons
            var per_class := {}
            for r in rs:
                for h in r["heroes"]:
                    var c := String(h["class"]) + (" (Máster)" if bool(h["master"]) else "")
                    if not per_class.has(c):
                        per_class[c] = {"damage": [], "healing": [], "taken": [], "downs": [], "deaths": [], "kills": []}
                    for k in ["damage", "healing", "taken", "downs", "kills"]:
                        per_class[c][k].append(float(h[k]))
                    per_class[c]["deaths"].append(1.0 if bool(h["dead"]) else 0.0)
            var pc := {}
            for c in per_class:
                pc[c] = {}
                for k in per_class[c]:
                    pc[c][k] = _ms(per_class[c][k])
            row["classes"] = pc
            row["gathered"] = _res_means(rs, "gathered")
            row["kept"] = _res_means(rs, "kept")
            row["reward"] = _res_means(rs, "reward")
            row["bot"] = _res_means(rs, "bot")
            row["pista_a"] = _res_means(rs.filter(func(r): return r.has("pista_a")), "pista_a")   # D-090
            row["loot"] = _res_means(rs.filter(func(r): return r.has("loot")), "loot")   # pista D
            var killers := {}
            for r in rs:
                for h in r["heroes"]:
                    if String(h["killed_by"]) != "":
                        killers[h["killed_by"]] = int(killers.get(h["killed_by"], 0)) + 1
            row["killers"] = killers
            rows.append(row)
    return rows


static func alerts(rows: Array, cfg: Dictionary) -> Array:
    var out: Array = []
    var lo := float(cfg.get("alerts", {}).get("impossible", 0.10))
    var hi := float(cfg.get("alerts", {}).get("trivial", 0.95))
    for r in rows:
        if float(r["win_rate"]) < lo:
            out.append("**Piso %d imposible** (%s): %.0f %% de victorias (< %.0f %%)" % [r["floor"], r["variant"], float(r["win_rate"]) * 100.0, lo * 100.0])
        elif float(r["win_rate"]) > hi:
            out.append("**Piso %d trivial** (%s): %.0f %% de victorias (> %.0f %%)" % [r["floor"], r["variant"], float(r["win_rate"]) * 100.0, hi * 100.0])
    # D-084: the tactical player must beat the "loco" by at least GAP points (same floor, build and sweep value)
    var gap := float(cfg.get("alerts", {}).get("tactical_gap", 0.30))
    for a in rows:
        if String(a["style"]) != "loco":
            continue
        for b in rows:
            if String(b["style"]) == "tactical" and int(b["floor"]) == int(a["floor"]) and str(a["sweep"]) == str(b["sweep"]) \
                    and String(a["pair"]) == String(b["pair"]) and float(b["win_rate"]) - float(a["win_rate"]) < gap \
                    and not (float(a["win_rate"]) == 0.0 and float(b["win_rate"]) == 0.0):
                out.append("**%s** en el piso %d%s: táctico %.0f %%, loco %.0f %% (objetivo: +%.0f pts)" % [
                    "Loco ≥ táctico" if float(a["win_rate"]) >= float(b["win_rate"]) else "Ventaja táctica corta", a["floor"],
                    "" if String(a["pair"]) == "" else " (%s)" % a["pair"], float(b["win_rate"]) * 100.0, float(a["win_rate"]) * 100.0, gap * 100.0])
    return out


static func write(dir: String, name: String, raw_cfg: Dictionary, variants: Array, runs: Array, rows: Array, speed: Dictionary, applied: Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute(dir)
    # runs.csv: one row per run
    var f := FileAccess.open(dir.path_join("runs.csv"), FileAccess.WRITE)
    f.store_line("variant,floor,seed,mission,outcome,win,reason,time_s,first_contact_s,party,downs,deaths,killed,enemies,damage,healing,taken,pings,commands,skills,revives,gathered,kept,lost,reward,reward_items,consumables_used,wall_ms")
    for r in runs:
        var dmg := 0
        var heal := 0
        var taken := 0
        for h in r["heroes"]:
            dmg += int(h["damage"])
            heal += int(h["healing"])
            taken += int(h["taken"])
        f.store_line(",".join([_q(r["variant"]), r["floor"], r["seed"], r["mission"], r["outcome"], 1 if r["win"] else 0, r["reason"],
            String.num(float(r["time"]), 1), String.num(float(r["first_contact"]), 1), r["party"], r["downs"], r["deaths"], r["killed"], r["enemies"],
            dmg, heal, taken, r["bot"]["pings"], r["bot"]["commands"], r["bot"]["skills"], r["bot"]["revives"], _q(_kv(r["gathered"])),
            _q(_kv(r["kept"])), _q(_kv(r["lost"])), _q(_kv(r["reward"])), r["reward_items"], r["consumables_used"], roundi(float(r.get("wall_ms", 0.0)))].map(func(x): return _q(x) if (x is float) else str(x))))
    f.close()
    # heroes.csv: one row per hero per run
    f = FileAccess.open(dir.path_join("heroes.csv"), FileAccess.WRITE)
    f.store_line("variant,floor,seed,hero,class,master,level,damage,healing,shield,taken,kills,downs,dead,killed_by")
    for r in runs:
        for h in r["heroes"]:
            f.store_line(",".join([_q(r["variant"]), r["floor"], r["seed"], _q(h["name"]), h["class"], 1 if h["master"] else 0, h["level"], h["damage"],
                h["healing"], h["shield"], h["taken"], h["kills"], h["downs"], 1 if h["dead"] else 0, _q(h["killed_by"])].map(func(x): return _q(x) if (x is float) else str(x))))
    f.close()
    f = FileAccess.open(dir.path_join("results.json"), FileAccess.WRITE)
    f.store_string(JSON.stringify({"name": name, "config": raw_cfg, "variants": variants, "overrides_applied": applied,
        "summary": rows, "speed": speed, "runs": runs}, "  "))
    f.close()
    f = FileAccess.open(dir.path_join("resumen.md"), FileAccess.WRITE)
    f.store_string(markdown(name, variants, rows, speed, applied))
    f.close()


static func markdown(name: String, variants: Array, rows: Array, speed: Dictionary, applied: Dictionary) -> String:
    var cfg0: Dictionary = variants[0]["config"]
    var L: PackedStringArray = []
    L.append("# Simulación: %s" % name)
    L.append("")
    L.append("Generado por `tools/sim/run_sim.gd` (D-083). %d runs, %d variantes, paso fijo %d Hz, máximo %d s de juego por run." % [
        speed.get("runs", 0), variants.size(), int(cfg0["tick_hz"]), int(cfg0["max_time"])])
    L.append("")
    var al := alerts(rows, cfg0)
    L.append("## Alertas")
    L.append("")
    if al.is_empty():
        L.append("Ninguna.")
    for a in al:
        L.append("- " + a)
    L.append("")
    L.append("## Resultados por variante y piso")
    L.append("")
    L.append("| Variante | Piso | Misión | Party | Runs | Victoria | Duración (s) | Derribos | Muertes | Enemigos muertos | Motivos de derrota |")
    L.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        L.append("| %s | %d | %s | %d | %d | **%.0f %%** | %s | %s | %s | %s | %s |" % [r["variant"], r["floor"], r["mission"], r["party"], r["runs"],
            float(r["win_rate"]) * 100.0, _pm(r["time"], 0), _pm(r["downs"], 1), _pm(r["deaths"], 2), _pm(r["killed"], 1), _kv(r["reasons"], ", ")])
    L.append("")
    var dims := {}
    for r in rows:
        for k in (r["dims"] as Dictionary):
            var key := "%s = %s" % [k, r["dims"][k]]
            if not dims.has(key):
                dims[key] = []
            dims[key].append(float(r["win_rate"]))
    if not dims.is_empty():
        L.append("## Victoria media por dimensión (todas las combinaciones y pisos)")
        L.append("")
        L.append("| Dimensión | Victoria media | Filas |")
        L.append("|---|---|---|")
        var ks: Array = dims.keys()
        ks.sort()
        for k in ks:
            var s := 0.0
            for x in dims[k]:
                s += x
            L.append("| %s | %.0f %% | %d |" % [k, s / float(dims[k].size()) * 100.0, dims[k].size()])
        L.append("")
    L.append("## Por clase (media por run)")
    L.append("")
    L.append("| Variante | Piso | Clase | Daño | Curación | Daño recibido | Muertes enemigas | Derribos | Muere |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        var cls: Array = (r["classes"] as Dictionary).keys()
        cls.sort()
        for c in cls:
            var d: Dictionary = r["classes"][c]
            L.append("| %s | %d | %s | %s | %s | %s | %s | %s | %.0f %% |" % [r["variant"], r["floor"], c, _pm(d["damage"], 0), _pm(d["healing"], 0),
                _pm(d["taken"], 0), _pm(d["kills"], 1), _pm(d["downs"], 2), float(d["deaths"]["mean"]) * 100.0])
    L.append("")
    L.append("## Recursos e ítems (media por run)")
    L.append("")
    L.append("| Variante | Piso | Recogido en el piso | Guardado al volver | Recompensa del piso | Ítems de recompensa | Consumibles usados | Bot (pings / comandos / skills / revividos) |")
    L.append("|---|---|---|---|---|---|---|---|")
    for r in rows:
        var b: Dictionary = r["bot"]
        L.append("| %s | %d | %s | %s | %s | %s | %s | %.1f / %.1f / %.1f / %.1f |" % [r["variant"], r["floor"], _kv(r["gathered"], ", ", 1), _kv(r["kept"], ", ", 1),
            _kv(r["reward"], ", ", 1), _pm(r["reward_items"], 1), _pm(r["consumables_used"], 1), float(b.get("pings", 0)), float(b.get("commands", 0)),
            float(b.get("skills", 0)), float(b.get("revives", 0))])
    L.append("")
    L.append("## Sinergias, campamentos y flechas (D-090, media por run)")
    L.append("")
    L.append("| Variante | Piso | Campamentos (hechos / interrumpidos) | Flechas al final | Sinergias activadas |")
    L.append("|---|---|---|---|---|")
    for r in rows:
        var pa: Dictionary = r.get("pista_a", {})
        var syn := {}
        for k in pa:
            if String(k).begins_with("syn_"):
                syn[String(k).trim_prefix("syn_")] = pa[k]
        L.append("| %s | %d | %.1f / %.1f | %.1f | %s |" % [r["variant"], r["floor"], float(pa.get("camps", 0)), float(pa.get("camps_interrupted", 0)),
            float(pa.get("arrows_left", 0)), _kv(syn, ", ", 1) if not syn.is_empty() else "—"])
    L.append("")
    L.append("## Botín de los cuerpos (pista D, media por run)")
    L.append("")
    L.append("| Variante | Piso | Cuerpos con botín | Ítems en cuerpos | Basura | Saqueados | A casa | Perdidos | Retenidos (avaricioso) | Saqueos del bot |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        var lo: Dictionary = r.get("loot", {})
        L.append("| %s | %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.2f | %.1f |" % [r["variant"], r["floor"], float(lo.get("bodies", 0)), float(lo.get("items", 0)),
            float(lo.get("junk", 0)), float(lo.get("looted", 0)), float(lo.get("home", 0)), float(lo.get("lost", 0)), float(lo.get("greedy_kept", 0)),
            float((r["bot"] as Dictionary).get("loots", 0))])
    L.append("")
    var any_k := rows.any(func(r): return not (r["killers"] as Dictionary).is_empty())
    if any_k:
        L.append("## Quién mata a los héroes (total)")
        L.append("")
        for r in rows:
            if not (r["killers"] as Dictionary).is_empty():
                L.append("- %s, piso %d: %s" % [r["variant"], r["floor"], _kv(r["killers"], ", ")])
        L.append("")
    if not applied.is_empty():
        L.append("## Overrides aplicados")
        L.append("")
        for k in applied:
            L.append("- %s: %s" % [k, ", ".join(applied[k])])
        L.append("")
    L.append("## Velocidad")
    L.append("")
    L.append("- Tiempo de juego simulado: %.0f s en %.1f s reales de CPU por proceso → **×%.1f** tiempo real por proceso." % [
        float(speed.get("sim_s", 0.0)), float(speed.get("cpu_s", 0.0)), float(speed.get("x_per_process", 0.0))])
    L.append("- Con %d procesos en paralelo: %.1f s de reloj en total → **×%.1f** tiempo real." % [int(speed.get("workers", 1)),
        float(speed.get("wall_s", 0.0)), float(speed.get("x_total", 0.0))])
    L.append("")
    L.append("Archivos: `runs.csv` (una fila por run), `heroes.csv` (una fila por héroe y run), `results.json` (todo, con la config).")
    L.append("")
    return "\n".join(L)


static func _ms(vals: Array) -> Dictionary:
    if vals.is_empty():
        return {"mean": 0.0, "sd": 0.0, "n": 0}
    var m := 0.0
    for v in vals:
        m += float(v)
    m /= float(vals.size())
    var s := 0.0
    for v in vals:
        s += (float(v) - m) * (float(v) - m)
    var sd := sqrt(s / float(vals.size() - 1)) if vals.size() > 1 else 0.0
    return {"mean": snappedf(m, 0.001), "sd": snappedf(sd, 0.001), "n": vals.size()}


static func _res_means(rs: Array, key: String) -> Dictionary:
    var tot := {}
    for r in rs:
        for k in (r[key] as Dictionary):
            tot[k] = float(tot.get(k, 0.0)) + float(r[key][k])
    var out := {}
    var ks: Array = tot.keys()
    ks.sort()
    for k in ks:
        out[k] = snappedf(float(tot[k]) / float(rs.size()), 0.01)
    return out


static func _pm(d: Dictionary, decimals: int) -> String:
    if int(d.get("n", 0)) == 0:
        return "—"
    return "%s ± %s" % [String.num(float(d["mean"]), decimals), String.num(float(d["sd"]), decimals)]


static func _kv(d: Dictionary, sep: String = ";", decimals: int = -1) -> String:
    if d.is_empty():
        return "—" if sep != ";" else ""
    var ks: Array = d.keys()
    ks.sort()
    return sep.join(ks.map(func(k): return "%s %s" % [k, String.num(float(d[k]), decimals) if decimals >= 0 else str(d[k])]))


static func _q(v: Variant) -> String:
    var s := str(int(v)) if (v is float and is_equal_approx(v, roundf(v)) and absf(v) < 1e15) else str(v)
    if s.contains(",") or s.contains("\"") or s.contains(";"):
        return "\"" + s.replace("\"", "\"\"") + "\""
    return s
