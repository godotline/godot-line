## ADDED Requirements

### Requirement: Split animations into individual AnimationPlayers

The AnimatorPlayerImportRoot SHALL provide a tool button that, when clicked, splits all animations in the `animations_root` AnimationPlayer into individual AnimationPlayer nodes, each containing a single animation with tracks filtered to the first animated node.

#### Scenario: Successful split
- **WHEN** user clicks the "Split Animations" tool button
- **AND** `animations_root` points to a valid AnimationPlayer node
- **THEN** for each animation in the source AnimationPlayer, a new child AnimationPlayer is created under the source's parent
- **AND** each new AnimationPlayer contains only that animation (with tracks filtered to the first node)
- **AND** each new AnimationPlayer is named after the animation it contains
- **AND** a summary message is printed listing created nodes

#### Scenario: animations_root not set
- **WHEN** user clicks the "Split Animations" tool button
- **AND** `animations_root` is empty or not set
- **THEN** a warning is printed: "animations_root not set."
- **AND** no nodes are created

#### Scenario: animations_root node not found
- **WHEN** user clicks the "Split Animations" tool button
- **AND** `animations_root` points to a path that does not exist in the scene tree
- **THEN** a warning is printed: "Missing animations_root: <path>"
- **AND** no nodes are created

#### Scenario: animations_root is not an AnimationPlayer
- **WHEN** user clicks the "Split Animations" tool button
- **AND** the node at `animations_root` is not an AnimationPlayer
- **THEN** a warning is printed: "animations_root is not an AnimationPlayer."
- **AND** no nodes are created

#### Scenario: Source AnimationPlayer has no animations
- **WHEN** user clicks the "Split Animations" tool button
- **AND** the target AnimationPlayer has an empty animation list
- **THEN** a warning is printed: "No animations to split."
- **AND** no nodes are created

#### Scenario: Animation has no valid tracks after filtering
- **WHEN** splitting an animation where all tracks belong to different nodes
- **THEN** that animation is skipped with warning: "Animation '<name>' has no valid tracks, skipped."
- **AND** other animations are still processed normally
