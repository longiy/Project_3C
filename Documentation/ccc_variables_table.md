# CCC System - Variable Reference (Table Format)

## Camera System

### CameraSystem (Main Coordinator)

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `enabled` | bool | `true` | Master switch for entire camera system. When false, camera stops updating | - |
| `camera_height_offset` | float | `1.5` | Height above character position where camera pivot sits. Higher = looks from higher position | 1.0-2.0 |
| `camera_distance_offset` | float | `2.0` | Additional distance added to SpringArm base length. Pushes camera back from default position | 0.0-5.0 |

---

### CameraDelay Component

#### Horizontal Following

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `horizontal_delay_time` | float | `0.3` | Time in seconds for camera to catch up horizontally (XZ plane). Lower = instant, Higher = more lag | 0.1-0.5s |

**Feel Guide:**
- `0.1` = Tight, responsive (action games)
- `0.3` = Smooth, cinematic (adventure games)
- `0.5` = Loose, floaty (casual games)

#### Vertical Following

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `vertical_delay_time` | float | `0.5` | Time in seconds for camera to catch up vertically (Y axis). Usually slower than horizontal | 0.3-1.0s |
| `vertical_deadzone` | float | `0.5` | Vertical distance character can move before camera follows. Prevents camera bobbing | 0.2-1.0 |
| `vertical_deadzone_exit_speed` | float | `0.5` | Currently unused. Reserved for future deadzone exit behavior | - |

#### Camera Lead System

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `enable_camera_lead` | bool | `true` | Enables camera positioning ahead of movement direction for better forward visibility | - |
| `camera_lead_distance` | float | `1.5` | Maximum distance camera shifts ahead of character. Scales with movement speed | 1.0-3.0 |
| `persistent_lead` | bool | `true` | Whether lead persists when stopped. true = keeps view ahead, false = recenters | - |
| `max_movement_speed` | float | `6.0` | Speed at which lead reaches maximum strength. Lead strength = current_speed / max_movement_speed | Match sprint_speed |
| `lead_start_multiplier` | float | `8.0` | How fast lead responds when starting to move. Higher = snappier response | 4.0-12.0 |
| `lead_end_multiplier` | float | `3.0` | How fast lead returns when stopping (only if persistent_lead = false). Usually slower than start | 2.0-6.0 |

**Lead Speed Feel:**
- `lead_start_multiplier 4.0` = Smooth, cinematic
- `lead_start_multiplier 8.0` = Balanced
- `lead_start_multiplier 12.0` = Instant, responsive

#### Smoothing Thresholds

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `movement_threshold` | float | `0.1` | Minimum movement speed to count as "moving" for lead system. Prevents activation from tiny movements | 0.05-0.2 |
| `position_close_threshold` | float | `0.01` | Distance threshold to consider camera "caught up". Optimization for smoothing calculation | 0.005-0.02 |
| `target_visualization` | Node3D | `null` | Optional mesh showing where camera is targeting. Visual debug for lead offset | - |

---

### CameraZoom Component

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `initial_distance` | float | `3.0` | Starting camera distance from character. Default zoom level when game starts | 2.0-6.0 |
| `min_distance` | float | `2.0` | Closest camera can zoom in. Must be ≤ initial_distance | 1.0-3.0 |
| `max_distance` | float | `10.0` | Farthest camera can zoom out. Must be ≥ initial_distance | 5.0-15.0 |
| `zoom_speed` | float | `1.0` | How much each mouse wheel notch changes target distance. Higher = coarser control | 0.5-2.0 |
| `zoom_smoothing` | float | `4.0` | Speed of smooth transition to target zoom. Lower = gradual, Higher = snappy | 2.0-8.0 |

**Distance Reference:**
- `2.0` = Close (over-shoulder view)
- `3.0` = Medium (standard third-person)
- `5.0` = Far (strategic view)

**Zoom Smoothing Feel:**
- `2.0` = Cinematic, slow
- `4.0` = Balanced
- `8.0` = Instant, responsive

---

### CameraRotation Component

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `horizontal_smoothing` | float | `6.0` | Speed camera rotates horizontally. Lower = sluggish, Higher = responsive | 4.0-15.0 |
| `vertical_smoothing` | float | `12.0` | Speed camera rotates vertically. Usually higher than horizontal to reduce motion sickness | 8.0-20.0 |
| `invert_horizontal` | bool | `false` | Reverses horizontal look. false = right looks right, true = right looks left | - |
| `invert_vertical` | bool | `false` | Reverses vertical look. false = down looks down, true = down looks up (flight sim) | - |

**Rotation Feel Guide:**
- Horizontal `4.0` = Heavy, cinematic
- Horizontal `6.0` = Balanced
- Horizontal `10.0` = Snappy, arcade
- Horizontal `15.0` = Nearly instant

---

## Movement System

### MovementConfig Resource

#### Movement Speeds

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `walk_speed` | float | `1.3` | Character speed when holding walk modifier (Ctrl). Slowest tier ≈ slow human walk | 1.0-2.0 m/s |
| `run_speed` | float | `3.0` | Default character speed with no modifiers. Standard tier ≈ casual jog | 2.5-4.0 m/s |
| `sprint_speed` | float | `6.3` | Character speed when holding sprint modifier (Shift). Fastest tier ≈ fast run | 5.0-8.0 m/s |

**Speed Reference:**
- Walk: `1.3 m/s` = 4.7 km/h
- Run: `3.0 m/s` = 10.8 km/h
- Sprint: `6.3 m/s` = 22.7 km/h

#### Speed Transitions

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `speed_transition_rate` | float | `4.0` | How fast character transitions between speed tiers. Higher = instant changes | 1.0-8.0 units/s |

**Example:** `4.0` = takes 0.5 seconds to go from run to sprint

#### Movement Physics

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `acceleration` | float | `30.0` | How fast character reaches target velocity. Lower = sluggish, Higher = snappy | 15.0-50.0 units/s² |
| `deceleration` | float | `10.0` | How fast character stops when input released. Lower = slide, Higher = instant stop | 5.0-30.0 units/s² |
| `air_direction_control` | float | `0.3` | Percentage of ground acceleration available in air (0.3 = 30% control while jumping) | 0.1-0.5 |
| `air_rotation_control` | float | `0.1` | Percentage of ground rotation speed in air (0.1 = 10% turn speed while jumping) | 0.05-0.3 |

**Acceleration Feel:**
- `15.0` = Realistic, heavy character
- `30.0` = Balanced, responsive
- `50.0` = Arcade, instant response

**Air Control Examples:**
- `air_direction_control 0.1` = Minimal (realistic)
- `air_direction_control 0.3` = Moderate (balanced)
- `air_direction_control 0.5` = High (arcade)

#### Jump Settings

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `jump_height` | float | `1.5` | Maximum height character reaches. Automatically calculates jump_velocity. 1.5 ≈ human jump | 1.0-3.0 units |
| `gravity` | float | `-20.0` | Downward acceleration when airborne. More negative = fall faster. Must be negative. -20 ≈ 2× Earth | -30.0 to -10.0 |
| `coyote_time` | float | `0.15` | Grace period after leaving ground where jump still works. Prevents "missed" jumps | 0.1-0.2s |
| `jump_buffer_time` | float | `0.1` | Input window before landing where jump request persists. Allows early jump press | 0.05-0.15s |

**Jump Height Reference:**
- `1.0 units` ≈ 3 feet (0.45s airtime)
- `1.5 units` ≈ 5 feet, human (0.55s airtime)
- `2.0 units` ≈ 6.5 feet (0.63s airtime)
- `3.0 units` ≈ 10 feet (0.77s airtime)

#### Rotation

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `rotation_speed` | float | `8.0` | Maximum turn speed at zero velocity (radians/second). 8.0 ≈ 458°/s. Reduces with speed | 5.0-15.0 rad/s |
| `min_rotation_speed` | float | `0.1` | Minimum turn speed at maximum velocity. Creates momentum feel at high speeds | 0.05-0.5 rad/s |
| `speed_rotation_reduction` | float | `0.7` | How aggressively rotation decreases with velocity. 0.0 = no reduction, 1.0 = maximum | 0.4-1.0 |
| `enable_directional_snapping` | bool | `false` | Locks character rotation to specific angles. true = tank controls, false = smooth rotation | - |
| `snap_angle_degrees` | float | `45.0` | Angle increment for snapping. Only matters if enable_directional_snapping = true | 45° or 90° |

**Rotation Reduction Feel:**
- `0.4` = Slight momentum
- `0.7` = Noticeable momentum
- `1.0` = Heavy momentum

#### Movement Feel (Hybrid System)

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `max_rotation_influence` | float | `1.0` | Max blend between input and facing. 0.0 = pure arcade, 1.0 = full momentum | 0.5-1.0 |
| `rotation_influence_start_speed` | float | `2.0` | Speed where momentum begins. Below this = pure input control. Set between walk and run | 1.5-3.0 m/s |
| `rotation_influence_curve` | float | `1.0` | Exponential curve for influence. 1.0 = linear, 2.0 = delayed onset, 0.5 = early onset | 0.5-2.0 |
| `momentum_rotation_bonus` | float | `0.2` | Extra influence when maintaining direction. Rewards sustained movement | 0.1-0.3 |

**Influence Examples:**
- `max_rotation_influence 0.5` = Moderate momentum
- `max_rotation_influence 1.0` = Full momentum preservation

**Curve Guide:**
- `1.0` = Balanced (start here)
- `>1.0` = Momentum feels "sudden"
- `<1.0` = Momentum feels "gradual"

#### Camera Alignment (Legacy)

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `camera_align_on_movement` | bool | `false` | Enables auto-alignment with camera when holding walk. Legacy feature, typically disabled | - |
| `camera_align_rotation_speed` | float | `5.0` | Speed of alignment rotation. Only matters if camera_align_on_movement = true | 3.0-8.0 rad/s |

#### Gamepad Settings

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `gamepad_movement_multiplier` | float | `1.0` | Scales movement speed for gamepad. 1.0 = same as keyboard, 1.2 = 20% faster | 0.8-1.2 |
| `gamepad_acceleration_multiplier` | float | `1.2` | Scales acceleration for gamepad. Makes gamepad feel snappier | 1.0-1.5 |
| `gamepad_rotation_speed_multiplier` | float | `1.1` | Scales rotation for gamepad. Compensates for analog stick precision | 1.0-1.3 |

---

## Input System

### InputConfig Resource

#### Mouse Settings

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `mouse_sensitivity` | Vector2 | `(0.002, 0.002)` | Multiplier for mouse movement (X=horizontal, Y=vertical). Lower = precise, Higher = fast | 0.001-0.005 |
| `invert_y` | bool | `false` | Reverses vertical mouse. false = down looks down, true = down looks up (flight sim) | - |
| `mouse_acceleration` | float | `1.0` | Currently unused. Reserved for non-linear mouse response | - |

**Example:** `0.002` = 1 pixel movement = 0.002 radian rotation

#### Gamepad Settings

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `gamepad_look_sensitivity` | Vector2 | `(0.3, 0.15)` | Multiplier for right stick (X=horizontal, Y=vertical). Y usually lower to reduce motion sickness | 0.1-0.5 |
| `left_stick_deadzone` | float | `0.1` | Minimum stick deflection for movement. Prevents drift from worn sticks. 0.1 = ignore below 10% | 0.05-0.2 |
| `right_stick_deadzone` | float | `0.1` | Minimum stick deflection for camera look. Same purpose as left stick | 0.05-0.2 |
| `gamepad_acceleration` | float | `1.0` | Currently unused. Reserved for non-linear stick response | - |

#### Input Detection

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `auto_detect_input_device` | bool | `true` | Auto-switches between keyboard/mouse and gamepad. true = last used becomes active | - |
| `input_switch_threshold` | float | `0.1` | Minimum input to trigger device switch. Prevents accidental switching | 0.05-0.2 |

#### Camera Integration

| Variable | Type | Default | Description | Typical Range |
|----------|------|---------|-------------|---------------|
| `vertical_look_limit` | float | `80.0` | Maximum vertical look angle in degrees. Prevents camera flip. 90° causes gimbal lock (avoid) | 70.0-89.0° |
| `horizontal_smoothing` | float | `10.0` | DEPRECATED - Moved to CameraRotation. Kept for backward compatibility | - |
| `vertical_smoothing` | float | `10.0` | DEPRECATED - Moved to CameraRotation. Kept for backward compatibility | - |

**Vertical Limit Examples:**
- `80°` = Can look almost straight up/down
- `70°` = More restricted vertical view

---

## Quick Reference Tables

### Movement Feel Presets

| Preset | Acceleration | Deceleration | Max Influence | Rotation Reduction |
|--------|--------------|--------------|---------------|-------------------|
| **Arcade** | 50.0 | 30.0 | 0.0 | 0.0 |
| **Balanced** | 30.0 | 10.0 | 1.0 | 0.7 |
| **Realistic** | 15.0 | 5.0 | 1.0 | 1.0 |

### Camera Responsiveness Presets

| Preset | Horizontal Smooth | Vertical Smooth | Delay Time |
|--------|------------------|-----------------|------------|
| **Low** | 4.0 | 8.0 | 0.5s |
| **Medium** | 6.0 | 12.0 | 0.3s |
| **High** | 10.0 | 20.0 | 0.1s |

### Common Configuration Scenarios

#### Fast-Paced Action Game
```
Movement:
- acceleration: 50.0
- deceleration: 30.0
- max_rotation_influence: 0.5
- speed_rotation_reduction: 0.4

Camera:
- horizontal_delay_time: 0.1
- horizontal_smoothing: 10.0
- enable_camera_lead: true
- lead_distance: 2.0
```

#### Exploration/Adventure Game
```
Movement:
- acceleration: 30.0
- deceleration: 10.0
- max_rotation_influence: 1.0
- speed_rotation_reduction: 0.7

Camera:
- horizontal_delay_time: 0.3
- horizontal_smoothing: 6.0
- enable_camera_lead: true
- lead_distance: 1.5
```

#### Realistic/Simulation Game
```
Movement:
- acceleration: 15.0
- deceleration: 5.0
- max_rotation_influence: 1.0
- speed_rotation_reduction: 1.0

Camera:
- horizontal_delay_time: 0.4
- horizontal_smoothing: 4.0
- enable_camera_lead: false
```

---

## Variable Dependencies

### Critical Relationships

| Parent Variable | Depends On | Relationship |
|----------------|------------|--------------|
| `jump_velocity` | `gravity`, `jump_height` | Auto-calculated: `sqrt(-2 * gravity * jump_height)` |
| `camera_lead_distance` | `max_movement_speed` | Lead strength = `current_speed / max_movement_speed` |
| `rotation_influence_start_speed` | `walk_speed`, `run_speed` | Best between walk and run speeds |
| `max_movement_speed` | `sprint_speed` | Should match sprint_speed for consistent behavior |

### Common Mistakes

| Issue | Cause | Fix |
|-------|-------|-----|
| No momentum at high speed | `max_rotation_influence = 0.0` | Set to 0.5-1.0 |
| Too much air control | `air_direction_control > 0.5` | Reduce to 0.1-0.3 |
| Camera gimbal lock | `vertical_look_limit = 90.0` | Reduce to 80.0-89.0 |
| Momentum never activates | `rotation_influence_start_speed > sprint_speed` | Set between walk and run |
| Camera lead too subtle | `camera_lead_distance < 1.0` | Increase to 1.5-3.0 |
| Camera snapping on move | SpringArm `collision_mask` includes character | Set mask to 1 (environment only) |