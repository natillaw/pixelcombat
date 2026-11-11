class_name HeroChatter
extends RefCounted
## Immersive Hero AI dialogue and personality chatter system (D-013, D-016).
## Generates human-like banter, tower floor entry thoughts, and situational reactions.

const ENTRY_LINES := {
    "trait.brave": [
        "A relic in the depths? Let's carve our way through!",
        "No monster stands between us and the extraction zone.",
        "Forward! We seize glory on this floor."
    ],
    "trait.cautious": [
        "Quiet... I smell traps. Don't rush blindly into the dark.",
        "We know the goal is the extraction portal, but let's check every corner first.",
        "Stick close together. One wrong step and we're surrounded."
    ],
    "trait.greedy": [
        "I didn't climb this tower for fresh air. Where's the loot?",
        "Relic first, gold second. Or both at the exact same time!",
        "Someone better be paying us double for this floor."
    ],
    "trait.arrogant": [
        "Hhmpf. Mere pests infest this floor. Watch and learn how it's done.",
        "The objective is clear enough. Try not to slow me down.",
        "Child's play. Let's finish this quickly."
    ],
    "trait.gloomy": [
        "Another floor of damp stone and inevitable doom...",
        "We know the goal, sure... but how many of us walk out alive?",
        "Don't get too attached to this room. It smells like a tomb."
    ],
    "trait.cheerful": [
        "Come on team, we've got this! Let's find that relic!",
        "Ooh, look at the architecture! Creepy, but exciting!",
        "Eyes up, smiles on! We'll reach the exit in no time!"
    ],
    "trait.hot_headed": [
        "Stop talking and let's start swinging!",
        "I see enemies, I hit enemies. Simple plan!",
        "Let's smash through their lines right now!"
    ]
}

const DEFAULT_ENTRY := [
    "We need to find the relic and reach the extraction point... but how do we get past them?",
    "Objective received: secure the artifact and escape. Let's move.",
    "This tower floor looks dangerous. Stay sharp."
]

static func get_entry_line(hero: HeroData) -> String:
    if hero == null:
        return "Let's move."
    for t in hero.traits:
        if ENTRY_LINES.has(t):
            var lines: Array = ENTRY_LINES[t]
            return String(lines[randi() % lines.size()])
    return String(DEFAULT_ENTRY[randi() % DEFAULT_ENTRY.size()])


## Short lines heroes say to each other while living in the town (visual only).
const TOWN_LINES := {
    "trait.brave": ["Next floor, I lead the way.", "Anyone up for sparring?"],
    "trait.cautious": ["Did you check your gear twice?", "Quiet days are the best days."],
    "trait.greedy": ["Heard the tower hides gold...", "Who owes me coins again?"],
    "trait.arrogant": ["Watch and learn.", "This town needs a statue. Of me."],
    "trait.gloomy": ["The forest was too quiet.", "Enjoy the sun while it lasts."],
    "trait.cheerful": ["What a lovely day!", "Let's grab food at the tavern!"],
    "trait.hot_headed": ["I'm bored. Where's the fight?", "Those goblins won't know what hit them."],
    "trait.kind": ["Are you hurt? Let me see.", "Rest well, friend."],
    "trait.curious": ["What's behind the tower gate?", "I found a strange mushroom!"],
    "trait.lazy": ["Five more minutes...", "Is it lunch yet?"],
}
const TOWN_DEFAULT := ["Nice weather.", "How was the last floor?", "I could use a drink.", "The blacksmith is busy today."]


static func town_line(hero: HeroData, rng: RandomNumberGenerator) -> String:
    var options: Array = []
    for t in hero.traits:
        options.append_array(TOWN_LINES.get(t, []))
    if options.is_empty() or rng.randf() < 0.3:
        options = TOWN_DEFAULT
    return String(options[rng.randi() % options.size()])


## D-082: short answers to a ping (and to ignoring it). Picked with the hero's seeded combat_rng.
const PING_REPLIES := {
    "regroup": ["Coming!", "On my way.", "Right behind you."],
    "attack": ["On it!", "Target sighted.", "Going in!"],
    "defend": ["I'll hold here.", "Nobody gets past.", "Holding."],
    "explore": ["I'll take a look.", "Scouting ahead.", "Let's see..."],
    "gather": ["I'll grab it.", "Gathering.", "Mine!"],
    "danger": ["Falling back!", "Pulling out!", "Careful!"],
    "spotted": ["I see it.", "Marked.", "Got eyes on it."],
    "help": ["I've got them!", "Hang on!", "Coming to help!"],
    "move": ["Moving.", "Going.", "Right."],
}
const PING_REFUSALS := ["Not now!", "I don't take orders like that.", "Hmph.", "Stop shouting at me."]
## Personality overrides: trait -> {ping kind or "ignore_danger"} -> line.
const PING_TRAIT_LINES := {
    "trait.reckless": {"ignore_danger": "Run? Never!", "attack": "Finally!"},
    "trait.hot_headed": {"ignore_danger": "Not while I can swing!", "attack": "Let me at them!"},
    "trait.cautious": {"attack": "...if you say so.", "danger": "I knew it!"},
    "trait.loyal": {"regroup": "Always at your side.", "help": "I won't leave anyone!"},
    "trait.lazy": {"explore": "Do I have to?"},
}


static func ping_line(hero: HeroData, kind: String, obeyed: bool, rng: RandomNumberGenerator) -> String:
    if hero != null:
        for t in hero.traits:
            var d: Dictionary = PING_TRAIT_LINES.get(t, {})
            if not obeyed and kind == "danger" and d.has("ignore_danger"):
                return String(d["ignore_danger"])
            if obeyed and d.has(kind):
                return String(d[kind])
    var pool: Array = PING_REPLIES.get(kind, ["Right."]) if obeyed else PING_REFUSALS
    return String(pool[rng.randi() % pool.size()])
