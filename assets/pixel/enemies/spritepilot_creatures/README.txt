SpritePilot Creatures Pack — 8 animated pixel-art assets
https://spritepilot.com/free-game-assets

Bats, slimes, ghosts, bees, fish, birds, spiders and beetles — small animated critters and enemies for any 2D game.

LICENSE
CC0 1.0 (public domain): use these in any project, commercial or not,
change them and share them. No credit needed (a link to spritepilot.com is
always appreciated). See LICENSE.txt.

HOW THEY WERE MADE
Drawn pixel by pixel by code written for SpritePilot. Not AI-generated, and
not traced or adapted from anyone else's art.

WHAT'S INSIDE
  16px/ and 32px/    one PNG per asset: the frames side by side, left to right
  previews/          an animated GIF of each one at 4x size, plus a still PNG
  creatures-pack.json the frame size, frame count and speed of every file

  Bat              8 frames  14 fps  loops       bat-16px_strip8.png, bat-32px_strip8.png
  Slime           10 frames  10 fps  loops       slime-16px_strip10.png, slime-32px_strip10.png
  Ghost           12 frames  10 fps  loops       ghost-16px_strip12.png, ghost-32px_strip12.png
  Bee              8 frames  16 fps  loops       bee-16px_strip8.png, bee-32px_strip8.png
  Fish             8 frames  10 fps  loops       fish-16px_strip8.png, fish-32px_strip8.png
  Bird             8 frames  12 fps  loops       bird-16px_strip8.png, bird-32px_strip8.png
  Spider          12 frames  10 fps  loops       spider-16px_strip12.png, spider-32px_strip12.png
  Beetle           8 frames  12 fps  loops       beetle-16px_strip8.png, beetle-32px_strip8.png

The speeds are what each one was timed for; change them to taste.
Pixels are either fully opaque or fully transparent, so the art stays crisp
and never picks up dark fringes from blending.

USING A STRIP
The file name says how to slice it: bat-32px_strip8.png is 8 frames
of 32 x 32 pixels in one row. GameMaker reads the "_strip8" by itself.
  Godot 4   AnimatedSprite2D > SpriteFrames > Add Frames from Sprite Sheet,
            Horizontal = the frame count, Vertical = 1.
  Unity     Sprite Mode Multiple, Filter Mode Point (no filter), Compression
            None; Sprite Editor > Slice > Grid By Cell Size, 32 x 32.
  Phaser    this.load.spritesheet('bat', 'bat-32px_strip8.png',
              { frameWidth: 32, frameHeight: 32 })
  Anywhere  use nearest-neighbor ("point") filtering and scale by whole
            numbers (2x, 3x, 4x) so the pixels stay sharp.

Step-by-step guides:
  https://spritepilot.com/blog/godot-4-sprite-animation
  https://spritepilot.com/blog/unity-sprite-sheet-animation
  https://spritepilot.com/blog/phaser-sprite-sheets-and-atlases
Preview, re-time or convert any strip in your browser:
  https://spritepilot.com/sprite-player
