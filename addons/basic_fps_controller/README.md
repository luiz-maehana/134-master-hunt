# Basic 3D FPS Controller in Godot

A clean first-person movement system built in 3D for **Godot 4**

![Asset Logo](https://raw.githubusercontent.com/ar-bh/basic-fps-controller-godot/main/addons/basic_fps_controller/assets/fps.png)

# **Demo**

[![Watch the demo](https://img.youtube.com/vi/_U7ih_c0CjA/hqdefault.jpg)](https://www.youtube.com/watch?v=_U7ih_c0CjA)

---

# **General**

This asset provides a basic, beginner-friendly `CharacterBody3D` FPS movement controller.

It is complete with a graybox test map with orange ramps, obstacles, and more. They are included for immediate testing of player movement, physics, and camera controls.

The controller is designed with `@export` to make it easy for beginners to adjust, change, and personalize the system without direct code.

This asset is 100% hand-written in clean GDScript with comments for explanations and derivations.

# Compatibility

- **Godot 4.0 - 4.7**: Fully supported out of the box

---

# **Features**

**Player Character**
- Simple 3D velocity-based movement using `CharacterBody3D`
- Customizable walking speed and acceleration using `@export` variables, also adjustable in code
- Gravity pulled from project settings
- Jump mechanics through floor checks

**Camera and Mouse Look**
- 360° horizontal mouse rotation
- Vertical head rotation, clamped from -90° to 90°
- Adjustable horizontal mouse sensitivity
- Adjustable vertical mouse sensitivity
- Cursor capture toggle (mouse click to lock, esc to unlock)

**World and Environment**
- 3D graybox playground level built with `CSG` nodes
- Ramps, platforms, and obstacles for testing ground and air physics

**UI**
- Debug setting that can be enabled or disabled; includes a `RichTextLabel` text box upon startup in the top left corner that includes the following:
  - FPS
  - grounded
  - sprinting
  - speed
  - velocity (vel)
  - position (pos)
  - look (yaw, pitch)
  - input vector (input)
- Crosshair in the middle of the screen

**Developer Experience**
- Inspector category grouping (`@export_group`)
- Self-contained scene setup with zero external library dependencies

---

# Installation / Quickstart

## Step 1: Download or Clone

Download or clone this repository and open the project inside Godot.

## Step 2: Input Actions

This FPS controller uses **custom input actions** that are manually set in the `Input Map`.

If these input actions are not set beforehand, go to **Project -> Project Settings -> Input Map** and configure the following:

| Input Action Name | Purpose | Key |
|---|---|---|
| `move_left` | Strafe left | A |
| `move_right` | Strafe right | D |
| `move_forward` | Move forward | W |
| `move_backward` | Move backward | S |
| `jump` | Jump | Spacebar |
| `sprint` | Sprint (hold) | Shift (left) |

## Step 3: Adding Player to Your Own Scene

1. Instance `res://addons/basic_fps_controller/scenes/fps_controller.tscn` into your 3D world scene. You can either make a duplicate or instance it directly, but ensure to make necessary edits like changing its scene name, class name, and more.
2. Ensure your world contains collision geometry (`StaticBody3D` or `CSGBox3D`, or any other `CSG` nodes with collision enabled).
3. Select the `FPSController`, rename to `Player` or whatever you want if necessary, and tweak whichever values you want to change directly in the **Inspector**.
   This is done by expanding the category you would like to edit:
   - **Movement**:
	 - `Walk Speed`: How fast the player moves while walking normally
	 - `Jump Velocity`: Vertical jump power
	 - `Sprint Enabled`: Toggle whether or not the player can sprint
	 - `Sprint Speed`: How fast the player moves when sprinting
   - **Sensitivity**:
	 - `Horizontal Mouse Sensitivity`: Sensitivity when the mouse is moved horizontally (stick to low decimals for best performance)
	 - `Vertical Mouse Sensitivity`: Sensitivity when the mouse is moved vertically (stick to low decimals for best performance)
   - **Debug**:
	 - Toggles the debug `RichTextLabel`: `InfoLabel`
4. Press **F5** to run your project.

# **Project Structure**

```
res://
├── addons/
│   └── basic_fps_controller/
│       ├── assets/
│       │   ├── crosshair.png
│       │   ├── fps.png
│       │   ├── fps2.png
│       │   ├── icon.png
│       │   ├── GodotPrototypeBlack512.png
│       │   └── GodotPrototypeOrange512.png
│       ├── scenes/
│       │   ├── fps_controller.tscn
│       │   ├── main.tscn
│       │   └── map.tscn
│       ├── scripts/
│       │   └── fps_controller.gd
│       ├── LICENSE.txt
│       ├── README.md
│       ├── plugin.cfg
│       └── plugin.gd
├── LICENSE.txt
├── README.md
└── project.godot
```

# **Requests & Contributing**

- **Bug Reports**: Open an issue in the [Issues](../../issues) section.
- **Feature Requests**: Share ideas in the [Discussions](../../discussions) section.

# **License**

This project is open-source and available under the [MIT License](https://opensource.org/license/MIT). Free to use in personal, non-commercial, and commercial projects.

# **Credits**

- Made by Arjun Bhumula
- Inspired by [Jeheno's Godot FPS assets](https://github.com/Jeh3no)
- Prototype Textures by Kenney, available on the [Godot Asset Library](https://godotengine.org/asset-library/asset/781)
- Crosshair Texture from Crosshair Pack by Kenney, available on [Kenney.nl](https://kenney.nl/assets/crosshair-pack)
