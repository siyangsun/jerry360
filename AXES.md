# World Axis Reference — Jerry360

Godot 4 uses a **right-handed Y-up** coordinate system.

```
        +Y (up)
        |
        |
        +------→ +X (right)
       /
      /
    +Z (toward camera / up the hill)
```

| Axis | Direction | In this game |
|------|-----------|--------------|
| **+X** | Right | Right across the slope (toward right lane boundary) |
| **-X** | Left  | Left across the slope (toward left lane boundary) |
| **+Y** | Up    | Skyward (jumps go +Y) |
| **-Y** | Down  | Into the ground (gravity pulls -Y) |
| **+Z** | Back  | Up the hill / toward the camera |
| **-Z** | Forward | **Downhill — direction of travel** |

## Notes

- Jerry's forward movement is `velocity.z = -speed` (negative Z).
- Lane switching moves Jerry on the **X axis** only.
- The **lateral fog** boundary uses `abs(WORLD_POSITION.x)` — fog walls
  close in from the sides. The boundary grows with `WORLD_POSITION.y`,
  so near the floor the fog is tight; higher up (sky) the boundary
  expands and the sky stays open.
- Chunks are spawned ahead in the **-Z** direction.
