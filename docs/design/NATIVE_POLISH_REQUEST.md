# Native Game Visual and Audio Polish Request

The user reviewed the implementation status and requests substantially finer handcrafted scene design, more art assets, and integration of openly licensed game audio. Continue the Godot 4 native Windows game autonomously, using the current Opus 5.5 / xhigh Claude Code TUI session. All project files, comments, and documentation remain English. Preserve English and Simplified Chinese support.

## Scene craftsmanship

- Study both user reference images in `art/reference/`. Target detailed, readable isometric pixel art with warm furnished ship interiors, convincing layered decks, populated spaces, and a coherent visual style.
- Replace generic scene layouts with authored compositions. Create distinctive ports, island landings, dungeon rooms, and battle arenas with landmarks, paths, elevation, region-specific props, and deliberate framing. Prioritize a beautifully finished starting ship, first port, first island, and first battle, then carry that quality across the remaining regions.
- Furnish the ship with coordinated floors, walls, stairs, railings, masts, rigging, doors, beds, tables, lamps, crates, barrels, storage, and small decorative props. Use meaningful spacing, cast shadows, occlusion, and animated crew activity so scenes feel inhabited.
- Improve weak silhouettes and animation: palm trees, hooded faces, bosses, pets, boarding action, and large readable battle effects. Provide a rowboat or an equally convincing visual transition for island landings.
- Expand art variety and integrate it in gameplay. More files or larger atlases alone do not meet the requirement. Use depth sorting, clear character scale, contextual animations, camera composition, and unobstructed HUD placement.
- Keep all essential interactions readable in both languages, using the bundled CJK font and language-independent saves. Add a practical text/UI size option.

## Required Multi-Deck Ship Architecture

The user has clarified that the ship must have many usable levels. The exposed top deck is reserved for circulation and boarding combat. Ordinary management buildings on the top deck are inappropriate. This requirement takes priority over earlier unrestricted deck placement or visual-polish assumptions.

- Build actual connected interior levels inside a substantial hull. Use at least three usable levels for the starter ship (an exposed combat deck plus two interior levels), with additional interior levels and larger floor areas on advanced hulls where their silhouettes support them.
- Keep the top deck open and tactically readable. Permit appropriate naval fittings such as masts, helm, rails, hatches, stairs, and limited ship equipment; place crew housing, kitchens, workshops, research, storage, and other management facilities in the interior levels.
- Design the interior levels as furnished ship spaces with clear room purposes, sensible circulation, believable headroom, walls, doors, lighting, and stairs. Match character, furniture, floor, and hull scale across all levels.
- Add clear floor switching and cutaway/visibility controls that expose each usable interior without upper layers obscuring it. Show level names and building eligibility in both game languages.
- Integrate stairs and hatches with crew pathfinding, facility access, work assignments, and boarding encounters. Make the exposed deck an actual in-world boarding arena with usable space for crew and enemies.
- Enforce level restrictions in placement previews and the underlying action validation. Save the level identity of facilities and linked access points. Safely migrate existing saves that contain ordinary facilities on the combat deck into suitable interior spaces, preserving progress and avoiding invalid placements.
- Update the GDD, implementation status, ship-building guidance, and asset inventory to describe the final architecture. Re-export the native game after implementation. Treat this structural redesign and the user-reported ship/crew proportion issue as high priorities alongside art and audio improvements.

## Openly licensed audio

- Find and integrate suitable openly licensed music, ambience, and sound effects. Prefer Kenney CC0 audio packs; OpenGameArt and Freesound may be used only after checking the license of each selected asset. Verify actual licenses rather than assuming an entire host has one license. Prefer CC0 or CC-BY; avoid NC, ND, missing, or ambiguous permissions.
- Include original source URLs, creator names, asset filenames, exact licenses, attribution text, and required license copies in an English `docs/AUDIO_LICENSES.md` and the distributed credits/license files.
- Add ocean and ship ambience, port/island/dungeon ambience, music appropriate to travel and battle, UI confirm/cancel cues, placement/repair/deck sounds, attack/hit/skill/retreat/victory/defeat feedback, and separate master/music/effects volume controls.
- Use consistent mixing, seamless loops, and restrained repeated cues. Keep essential events understandable through visible feedback as well.

## Delivery

- Continue with Godot and a real Windows executable with its resource pack. Preserve the native application workflow.
- I have downloaded the current `build/windows/ProjectSevenSeas.exe` and `.pck` for a local manual Windows playtest. Concrete findings will follow; do not wait for them before improving the game.
- Do not start automated test suites, browsers, web servers, or additional playtest instances. Native asset import and export are permitted for producing the revised build.
- Update the implementation status and asset inventory honestly, then export the improved native build. Record what was actually integrated, the artifact paths, and remaining incomplete areas.
