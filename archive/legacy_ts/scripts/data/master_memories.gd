class_name MasterMemories
extends RefCounted
## D-081: memories of the Former Master. Beating the boss of every tenth floor (10, 20 ... 100) unlocks the
## next fragment once: a short scene (text panel) and a reward. Ids are stable (memory_01..memory_10).
## Rewards: {"leadership": n} (Leadership points), {"passive": id} (HeroTables.PASSIVES, added to the
## Master) or {"command": id} (MasterDefs.COMMANDS; none of these yet: no new command is designed).
## TODO(lore): every title and text below is a placeholder for the owner's lore.

const MEMORIES := [
    {"id": "memory_01", "floor": 10, "title": "The first circle",
        "text": "TODO lore: a chalk circle on a stone floor, and the first voice that answered.", "reward": {"leadership": 5}},
    {"id": "memory_02", "floor": 20, "title": "A name in the ledger",
        "text": "TODO lore: a book of names, and one of them crossed out by your own hand.", "reward": {"passive": "passive.inspiring"}},
    {"id": "memory_03", "floor": 30, "title": "The bell tower",
        "text": "TODO lore: the bell that called the summoned home, ringing for the last time.", "reward": {"leadership": 5}},
    {"id": "memory_04", "floor": 40, "title": "Ash on the banner",
        "text": "TODO lore: a banner you carried, burnt at the edges.", "reward": {"leadership": 5}},
    {"id": "memory_05", "floor": 50, "title": "The broken oath",
        "text": "TODO lore: a promise you made to the circle, and the night you broke it.", "reward": {"passive": "passive.resolute"}},
    {"id": "memory_06", "floor": 60, "title": "The empty hall",
        "text": "TODO lore: the hall where your summoned waited, and nobody came back.", "reward": {"leadership": 5}},
    {"id": "memory_07", "floor": 70, "title": "A rival's face",
        "text": "TODO lore: someone who stood beside you, then against you.", "reward": {"leadership": 5}},
    {"id": "memory_08", "floor": 80, "title": "Fire below",
        "text": "TODO lore: the deep floors burning, and what you left there.", "reward": {"passive": "passive.iron_will"}},
    {"id": "memory_09", "floor": 90, "title": "The last order",
        "text": "TODO lore: the last command you gave, and who obeyed it.", "reward": {"leadership": 10}},
    {"id": "memory_10", "floor": 100, "title": "The top of the tower",
        "text": "TODO lore: what waits at the top, and why you climbed it before.", "reward": {"leadership": 10}},
]


## The memory a floor's boss unlocks, or {} (only tenth floors have one).
static func for_floor(floor_num: int) -> Dictionary:
    for m in MEMORIES:
        if int(m["floor"]) == floor_num:
            return m
    return {}


static func info(id: String) -> Dictionary:
    for m in MEMORIES:
        if String(m["id"]) == id:
            return m
    return {}
