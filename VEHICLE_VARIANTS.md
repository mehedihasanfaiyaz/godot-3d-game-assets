# Vehicle Variants

This document describes the three vehicle variants created based on the `tata.tscn` template.

## 🚌 Bus (`vehicles/4 wheeler/bus.tscn`)

**Visual Characteristics:**
- **Body Size**: 2.5 x 2.5 x 8 units (long and tall)
- **Color Scheme**: Yellow/gold body with light-colored windows
- **Textures**: 
  - Body: `Light/texture_07.png`
  - Windows: `Light/texture_05.png` (semi-transparent)
  - Wheels: `Dark/texture_04.png`

**Physics & Performance:**
- **Mass**: 3000 kg (heavy, stable)
- **Jump Impulse**: 8000 (lower than standard)
- **Max Boost Fuel**: 8000
- **Boost Consumption**: 1200
- **Max Fuel**: 1500 (highest capacity)
- **Fuel Consumption**: 1.5/sec
- **Damage Threshold**: 25.0 (more durable)

**Unique Features:**
- Longer wheelbase (wheels at ±2.5 front/back)
- Wider wheel spacing (±1.3 left/right)
- Larger wheels (radius 0.7)
- Windows mesh for passenger area
- Cameras positioned higher for better view

---

## 🏎️ Buggy (`vehicles/4 wheeler/buggy.tscn`)

**Visual Characteristics:**
- **Body Size**: 1.5 x 0.3 x 2.5 units (compact, low chassis)
- **Color Scheme**: Red/orange with black roll cage
- **Textures**:
  - Frame: `Red/texture_05.png`
  - Wheels: `Dark/texture_04.png`

**Physics & Performance:**
- **Mass**: 600 kg (lightest, most agile)
- **Jump Impulse**: 12000 (highest jump)
- **Max Boost Fuel**: 12000 (best boost capacity)
- **Boost Consumption**: 800 (most efficient)
- **Max Fuel**: 800
- **Fuel Consumption**: 0.8/sec (most efficient)
- **Damage Threshold**: 15.0 (fragile)

**Unique Features:**
- Exposed roll cage (4 vertical bars at corners)
- Visible racing seat
- Compact wheelbase (wheels at ±1.1 front/back)
- Smaller wheels (radius 0.65)
- Metallic frame material (0.3 metallic)
- Best for stunts and jumps

---

## 🚙 Monster Truck (`vehicles/4 wheeler/monster_truck.tscn`)

**Visual Characteristics:**
- **Body Size**: 3 x 1.5 x 5 units (large, elevated)
- **Color Scheme**: Green body with dark cabin
- **Textures**:
  - Body: `Green/texture_05.png`
  - Details: `Light/texture_07.png`
  - Wheels: `Dark/texture_04.png`

**Physics & Performance:**
- **Mass**: 2500 kg (heavy but powerful)
- **Jump Impulse**: 15000 (extreme jumping power)
- **Max Boost Fuel**: 15000 (highest boost)
- **Boost Consumption**: 1500 (high consumption)
- **Max Fuel**: 1200
- **Fuel Consumption**: 1.8/sec (highest)
- **Fuel Boost Multiplier**: 3.0 (most powerful boost)
- **Damage Threshold**: 30.0 (most durable)

**Unique Features:**
- MASSIVE wheels (radius 1.2, height 0.5)
- Elevated body (1.5 units high)
- Wide wheelbase (±1.7 left/right, ±2.0 front/back)
- 4 front lights (2 on bumper, 2 on roof)
- Separate cabin mesh on top of body
- Highest ground clearance
- Best for crushing obstacles

---

## Common Features (All Vehicles)

All three vehicles share:
- ✅ Raycast-based physics (`raycast_car.gd`)
- ✅ Vehicle HUD integration
- ✅ Front lights (white/yellow)
- ✅ Rear brake lights (red)
- ✅ Turn signal indicators (orange)
- ✅ Multiple camera angles (FD, RL, RR, top, back)
- ✅ Damage smoke particles
- ✅ Destruction fire particles
- ✅ Destruction smoke particles
- ✅ Fuel system with boost
- ✅ Damage threshold system

---

## Usage

To use these vehicles in your game:

1. **Instance the scene** in your level
2. **Assign to a player** or AI controller
3. **Customize parameters** in the inspector if needed
4. **Test different vehicles** for different gameplay styles:
   - **Bus**: Slow, stable, high capacity (good for transport missions)
   - **Buggy**: Fast, agile, great jumps (good for racing/stunts)
   - **Monster Truck**: Powerful, durable, extreme (good for destruction/obstacles)

---

## Texture References

All vehicles use textures from `res://assets/texture/`:
- **Dark/** - Black/dark gray textures (wheels, tires)
- **Green/** - Green textures (monster truck body)
- **Light/** - Light/white textures (bus body, windows)
- **Red/** - Red/orange textures (buggy frame)

Make sure these texture folders exist in your project!
