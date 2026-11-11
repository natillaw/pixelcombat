class_name CameraDefs
extends RefCounted
## D-082b: the expedition camera and the window. The camera never changes its zoom on its own: the world
## is drawn at whole steps only (the project stretches 640x360 by an integer: 2x at 720p, 3x at 1080p, 4x
## at 1440p) and the player can add ZOOM_STEPS on top with the mouse wheel. Keys are data (rebind here);
## none of them takes QWER, F, 1/2/3, H/X/C/V, A/S/G/M/T/I, Space (dash) or Tab.

const ZOOM_STEPS := [1.0, 1.5, 2.0]     # camera zoom levels (2026-11-02, owner: "se ve un poco lejos": starts at 1.5)
const ZOOM_DEFAULT := 1

## Modes: "locked" follows the Master (default); "free" (KEY_TOGGLE) moves with the mouse at the screen
## edges, the arrow keys or a middle-button drag, inside the map and the explored area; "follow" = a hero
## picked with a double tap of its F-key, until the camera is moved, KEY_TOGGLE or KEY_CENTER.
const KEY_TOGGLE := KEY_Y
const KEY_CENTER := KEY_B               # hold: centred on the Master while held (Space stays the dash, D-071)
const HERO_KEYS := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5]   # F1 = the Master (slot 1)
const KEY_DEBUG := KEY_F10              # debug overlay (was F3)
const KEY_FULLSCREEN := KEY_F11         # also Alt+Enter
const DOUBLE_TAP := 0.35                # s between two presses of a hero key to follow that hero
const EDGE_PX := 6.0                    # screen px from the window edge that scroll the free camera
const PAN_SPEED := 520.0                # world px/s (edges and arrows)
const EXPLORED_MARGIN := 3              # cells: the free camera may look this far past the explored area

## Framing of the followed unit: the real view is the screen minus the HUD at the bottom; the unit is
## centred in it, leans LOOK_AHEAD s of its movement ahead (at most LOOK_AHEAD_MAX px), and is never
## closer than BOTTOM_MIN of the screen height to the bottom of the view.
const LOOK_AHEAD := 0.25
const LOOK_AHEAD_MAX := 36.0
const BOTTOM_MIN := 0.25

## Off-screen markers at the screen edges (heroes and pings); a click jumps there.
const INDICATOR_MARGIN := 14.0
const INDICATOR_RADIUS := 8.0
