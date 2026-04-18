## ADDED Requirements

### Requirement: Player can restart with R key
The Player SHALL reload the current scene when the R key is pressed, matching the Unity KeyCode.R behavior.

#### Scenario: Restart during gameplay
- **WHEN** player presses R key while not in editor mode
- **THEN** current scene reloads immediately

#### Scenario: Restart blocked while loading
- **WHEN** player presses R key but loading flag is true
- **THEN** no action is taken (prevents double-reload)

### Requirement: Player can quick-death with K key
The Player SHALL die instantly when K is pressed during active gameplay, matching Unity KeyCode.K behavior.

#### Scenario: Quick death during playing state
- **WHEN** player presses K key and game state is Playing
- **THEN** player dies (triggers death sequence with particles and sound)

#### Scenario: Quick death blocked when not playing
- **WHEN** player presses K key but game is not in Playing state
- **THEN** no action is taken

### Requirement: Player can toggle debug mode with D key (debug builds only)
The Player SHALL toggle a debug overlay display when D is pressed, but ONLY in debug builds (not in release exports), matching Unity UNITY_EDITOR compile-time behavior.

#### Scenario: Toggle debug in debug build
- **WHEN** player presses D key while running a debug build
- **THEN** debug overlay visibility toggles on/off

#### Scenario: Debug key ignored in release
- **WHEN** player presses D key in release export
- **THEN** no action is taken (debug not available in release)

### Requirement: Debug overlay displays real-time game info
The debug overlay SHALL display the following information when visible, matching Unity OnGUI debug display:
- FPS counter
- Level progress (percentage and elapsed time in seconds)
- Current game state
- Player position coordinates
- Player rotation
- Camera offset, rotation, and FOV

#### Scenario: Overlay updates in real-time
- **WHEN** debug overlay is visible
- **THEN** all displayed values update every frame with current game state

#### Scenario: Overlay hidden by default
- **WHEN** game starts
- **THEN** debug overlay is hidden until D key is pressed
