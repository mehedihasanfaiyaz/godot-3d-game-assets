# Vehicle HUD Setup Guide (UPDATED - SIMPLE METHOD)

## What Was Created

1. **vehicle_hud.tscn** - A modern racing-game style HUD
2. **Updated raycast_car.gd** - Automatically finds and updates the HUD

## ✅ **Simple Setup (2 Steps)**

### **Step 1: Add HUD to Your Vehicle Scene**

1. Open your **vehicle scene** (the one with RigidBody3D and raycast_car.gd)
2. Right-click on the **root vehicle node**
3. Select "Instantiate Child Scene"
4. Choose `vehicle_hud.tscn`
5. Done! The HUD is now part of your vehicle

### **Step 2: Test It**

Run the scene. The HUD will automatically:
- ✅ Find the speed label
- ✅ Find the boost bar
- ✅ Update them in real-time

**That's it!** No manual connections needed.

---

## 🎯 **How It Works**

The script automatically finds the UI nodes using **unique names** (the `%` symbol):
- `%SpeedLabel` - Automatically found
- `%BoostBar` - Automatically found

The HUD scene already has these unique names set, so everything works automatically!

---

## 📁 **Scene Structure**

Your vehicle scene should look like this:

```
Vehicle (RigidBody3D) - has raycast_car.gd script
├── CollisionShape3D
├── MeshInstance3D (car body)
├── Wheel1 (RayCast3D)
├── Wheel2 (RayCast3D)
├── Wheel3 (RayCast3D)
├── Wheel4 (RayCast3D)
├── Camera3D
└── VehicleHUD (CanvasLayer) ← Add this!
    └── Control
        └── BottomRight
            ├── SpeedPanel
            │   └── ... → SpeedLabel
            └── BoostPanel
                └── ... → BoostBar
```

---

## ⚙️ **Customization**

### Adjust Boost Settings

In the vehicle Inspector under **"Boost System"**:
- `Max Boost Fuel`: 100.0
- `Boost Consumption`: 25.0 (fuel per second)
- `Boost Recharge`: 15.0 (fuel per second)

### Change HUD Position

1. Open `vehicle_hud.tscn`
2. Select `Control > BottomRight`
3. Change anchor preset (top-left, top-right, bottom-left, etc.)

### Customize Colors

Edit `vehicle_hud.tscn`:
- Speed color: `SpeedLabel > Theme Overrides > Colors > Font Color`
- Border: Edit the StyleBoxFlat resource
- Background: Edit the StyleBoxFlat resource

---

## 🎨 **HUD Features**

- **Speed Display**: Real-time km/h conversion
- **Boost Fuel Bar**: Visual fuel level
- **Boost Percentage**: Color-coded (red/yellow/white)
- **Modern Design**: Cyan borders, semi-transparent panels

---

## ❓ **Troubleshooting**

**HUD not showing?**
- Make sure `vehicle_hud.tscn` is a child of your vehicle
- Check that it's a **CanvasLayer** (not Control)

**Speed shows 0?**
- Verify the vehicle is moving
- Check that the script found the label (no errors in console)

**Boost not working?**
- Ensure you have the "veh_boost" input action defined
- Check boost fuel > 0 in the Inspector

**"Node not found" error?**
- Make sure you're using the provided `vehicle_hud.tscn` file
- The nodes have unique names (marked with `%` in the scene)

---

## 🚀 **Why This Method is Better**

**Old Method (Complicated):**
- ❌ Add HUD to world scene
- ❌ Manually drag nodes into export variables
- ❌ Breaks if you instance the vehicle multiple times

**New Method (Simple):**
- ✅ HUD is part of the vehicle
- ✅ Automatically finds nodes
- ✅ Works with multiple vehicle instances
- ✅ Portable - vehicle scene is self-contained

---

## 🎮 **Input Actions Required**

Make sure these are in Project Settings > Input Map:
- `veh_accelerate` (W)
- `veh_back` (S)
- `veh_left` (A)
- `veh_right` (D)
- `veh_brake` (Space)
- `veh_boost` (Shift)
- `veh_jump` (Ctrl)
- `veh_cam` (C)

---

## 🎯 **Next Steps**

You can extend the HUD by adding:
- Gear indicator
- RPM meter
- Lap timer
- Position/rank display
- Minimap

Just add more UI elements to `vehicle_hud.tscn` and update the script to populate them!
