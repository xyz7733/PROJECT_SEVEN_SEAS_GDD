# Project Seven Seas: Visual Rework

## User feedback and priority

The user says the current version is completely below expectations. They want a beautiful, asset-complete 2D game. They describe the current presentation as a text-box simulator and reject it as the intended product.

Stop the current playtesting and automated testing workflow. Do not restart browser tests, campaign bots, or test suites. Focus the next implementation on visual quality, complete assets, and a playable scene. Keep all communication, source identifiers, comments, and documentation in English. Maintain English and Simplified Chinese game localization.

This brief supersedes the previous lightweight visual placeholder approach. Keep the confirmed gameplay systems and saved progression where practical. Do not claim that passing logic tests establishes visual or product acceptance.

## Mandatory engine and native delivery

The user explicitly rejects opening the game in a browser. Use **Godot 4 with GDScript** as the game engine. Deliver a real Godot project and a native Windows x86-64 executable, with its resource pack if not embedded. Native Linux builds may support development on the remote host.

Do not deliver HTML, DOM, Canvas-in-a-browser, a localhost web server, a Web export, Electron, a webview shell, or a desktop wrapper around the current website. Stop all previous browser-first implementation work. Do not open or launch a browser. The current JavaScript implementation can serve as a reference for mechanics and data only; port the relevant systems to the engine rather than embedding their web runtime.

Use real engine scenes, nodes, TileMap or TileMapLayer resources, textures, sprite sheets, animation resources, input actions, native UI controls, and the engine's save and localization systems. Supply `project.godot`, source scenes and scripts, imported source artwork, a native export configuration, and documented native launch/export instructions. If the engine or export templates are missing, install the official stable Godot 4 tools within the project's tools directory and perform the native export. Do not fall back to a browser deliverable.

## User-provided visual references

- `art/reference/user_ship_interior.jpg`: a furnished isometric interior with warm wood, patterned floors, walls, furniture, lamps, plants, numerous facilities, and small animated inhabitants.
- `art/reference/user_ship_decks.png`: a multi-level wooden ship with ocean, stairs, railings, masts, rigging, decorative props, crew, and monsters inhabiting the same scene.

Inspect both image files with your image-reading tools before implementation. Use them to understand perspective, detail density, proportions, color, and scene composition. The delivered game should contain its own coherent artwork. Do not include the screenshots, their watermarks, or their UI overlays as gameplay artwork.

## Required presentation

The primary gameplay surface is a detailed isometric pixel-art ship scene occupying most of the viewport. The ship must feel like a place: visible deck elevation, stairs, railings, rooms, facilities, furnishings, shadows, lighting details, ocean, and inhabitants. Use a consistent approximately 2:1 isometric perspective, coherent scale, crisp pixel rendering, and correct depth sorting.

Crew should visibly idle, walk, work, and react in the scene. Facilities should have recognizable sprites and working or idle states. Combat should show characters and monsters fighting in spatial deck or island arenas, with movement, attack and hit animation, effects, and readable health indicators.

Provide camera pan and zoom, deck selection or upper-deck visibility controls, facility selection and placement previews, and contextual interaction. Use a compact HUD for resources and objectives, with menus supporting the scene. The main experience must not remain a collection of large text panels or static combatant cards.

## Asset completeness

Create a consistent asset library in the project, with real raster tiles, sprites, sprite sheets, atlases, and metadata as needed. Include:

- ocean and shoreline or port terrain;
- ship floor tiles, hull edges, walls, doors, railings, stairs, masts, sails, and rigging;
- furnished facility sprites for all existing facility categories, plus ordinary props such as crates, barrels, tables, lamps, plants, and storage;
- crew appearance variants, role and outfit differentiation, idle and walking animations, and work and combat actions;
- monsters and pets with recognizable silhouettes, movement, attack, hit, and defeat states;
- island or dungeon environment tiles, obstacles, and interactable objects;
- polished icons, selection outlines, placement states, effects, and compact HUD artwork.

Keep a documented asset inventory with dimensions, animation frames, origin or generation method, and usage. Use original assets or compatible reusable assets and record any attribution requirements. Avoid generic colored rectangles, tiny symbolic stand-ins, and placeholder art as the final presentation. An atlas generated by code is acceptable only when its finished visual quality meets the reference direction; procedural generation alone is not evidence of quality.

## Implementation and delivery

Implement in Godot 4's native 2D engine. Preserve the confirmed game rules, deterministic identities, progression, maps, and bilingual text when porting them to GDScript and engine resources. There must be no browser or Node.js runtime requirement for playing the delivered game. Keep the previous website as a reference or archive outside the active engine project, clearly marked as superseded.

Implement autonomously, including the actual artwork files and their integration. Prioritize a convincing complete ship interior and multi-deck exterior, then carry the same art direction through ports, islands, crew, pets, and battles. Keep the game playable and all work saved under `/root/workspace/project-seven-seas`.

Update the README with native Windows launch and Godot editor/export instructions, the export output path, and the asset inventory location. Engine import and native export commands are permitted implementation work; do not resume test suites, playtesting, or browser automation. Report the engine migration, visual changes, generated native artifacts, and any remaining unfinished artwork honestly in English. Do not end with only a proposal or declare the product accepted. The user will judge the revised presentation.
