# twofold

A small grid puzzle game made in Godot 4. You control one blob that can split into more. On every move made, all the blobs will move together,
and walls block each blob on its own. Get a blob onto every goal tile to solve the level.

## How to play

- Move every blob at once with the arrow keys.
- Press space (or enter) to split. A new blob appears next to the first one, but only while there are fewer blobs than goals.
- Blobs that end up on the same tile merge back into one.
- Move blobs onto buttons to open gates. Every button has to be held at the same time, and a gate stays solid until they are.
- A level is solved when every goal tile has a blob on it.

| Key | Action |
| --- | --- |
| Arrow keys | Move all blobs |
| Space / Enter | Split, or go to the next level after solving |
| Z | Undo |
| R | Restart the level |
| Esc | Pause |

## Making levels

Levels live in `levels.gd` as arrays of strings, one string per row:

| Character | Meaning |
| --- | --- |
| `#` | Wall |
| `.` | Floor |
| `B` | Starting blob |
| `G` | Goal |
| 'b' | Button |
| `D` | Gate (opens while every button is held) |

For example, the first level looks like this:

```
#######
#B...G#
#.###.#
#..G..#
#######
```

feel free to PR any levels you make!

## Music

"New Direction" by Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
http://creativecommons.org/licenses/by/4.0/
