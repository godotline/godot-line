## 1. Add restart shortcut (R key)

- [x] 1.1 Add `var loading := false` variable to Player.gd (track loading state to prevent double-restart)
- [x] 1.2 Add R key handling in `_input()` to call `reload()` when pressed and not loading

## 2. Add quick-death shortcut (K key)

- [x] 2.1 Add K key handling in `_input()` to call `die()` when game is playing and player is alive

## 3. Add debug toggle and overlay (D key, debug builds only)

- [x] 3.1 Add `var debug := false` variable to Player.gd
- [x] 3.2 Add D key handling in `_input()` guarded by `OS.is_debug_build()` to toggle debug state
- [x] 3.3 Create DebugOverlay.gd script (extends CanvasLayer) with Label nodes for all debug info
- [x] 3.4 Display: FPS, level progress (% and seconds), game state, player position, player rotation
- [x] 3.5 Display: crown count, camera info (offset, rotation, FOV)
- [x] 3.6 Connect debug overlay to Player.debug toggle — show/hide CanvasLayer based on debug state

## 4. Verification

- [x] 4.1 Test R key restarts the scene during gameplay
- [x] 4.2 Test K key kills the player during gameplay
- [x] 4.3 Test D key toggles debug overlay in debug builds
- [x] 4.4 Verify all debug labels update correctly in real-time
