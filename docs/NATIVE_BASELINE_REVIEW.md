# Native Baseline Visual Review

## Reviewed Build

- Windows executable SHA-256: `1edeef2171ef1dc274f2175bf90de4da4658731983edb3a855415a4d9dabfb4b`
- Resource pack SHA-256: `87e26bb92c868c38561f20a59ce7be41d93cd4401b6c1b7c1550bfcf57ad045f`
- The downloaded native executable launched successfully using the local NVIDIA OpenGL renderer.
- The short manual review covered the Chinese title screen, an existing island exploration state, the starter ship at port, animated actors, and camera zoom. The review process is now closed.

## Direct Visual Findings

- The baseline has an actual isometric scene with visible character movement, water, props, a ship hull, and a port. It is a native Godot application.
- In the reviewed starter ship, a bed, storage/shelving, furniture, crew, mast, and ordinary props occupy the same exposed deck. The screenshots show no furnished below-deck interior.
- At the overview zoom, the ship reads as a shallow, compact single deck. The human-to-hull scale and usable floor area do not support the user's intended substantial multi-level vessel.
- The HUD displays an all-decks label. The short review did not establish which level mechanics exist elsewhere or on upgraded hulls. Inspect the implementation before deciding what to retain.
- The port composition contains a small set of repeated building shapes. Expand authored scene identity, furnishings, paths, shoreline detail, and landmark variety alongside the ship redesign.

## Scope Clarification for the Earlier TUI Message

The port and island were viewed as separate existing gameplay states. A complete landing or rowing transition was not exercised. The absence of a rowboat in the reviewed frames does not establish that no transition exists anywhere. Likewise, the visible starter deck does not establish that no other hull has internal deck data. The user's required multi-level architecture remains the implementation target regardless.

## Required Next Build

Apply [NATIVE_POLISH_REQUEST.md](design/NATIVE_POLISH_REQUEST.md), including the user's multi-deck correction: reserve the exposed upper deck for movement and boarding combat, put ordinary facilities inside connected furnished interior levels, enlarge actual ship space relative to crew, and provide clear floor visibility controls. Preserve saves and enforce placement restrictions. Continue the requested handcrafted art and openly licensed audio integration.

## Evidence

- `baseline-native-title.png`: Chinese title screen.
- `baseline-native-ship-close.png`: exposed deck and facilities at close zoom.
- `baseline-native-ship-overview.png`: overall starter hull and port at overview zoom.
