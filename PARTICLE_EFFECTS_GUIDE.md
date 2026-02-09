# Vehicle Damage Particle Effects Guide

## ✅ **What's New**

Your vehicle now has visual damage indicators:
- **Smoke** - Appears when health drops below 30%
- **Fire + Heavy Smoke** - Appears when vehicle is destroyed (0 health)

---

## 🎯 **How It Works**

### **Damage Smoke (Health < 30%)**
- Starts emitting when health drops below threshold
- Intensity increases as health decreases
- Automatically stops when destroyed or health recovers

### **Destruction Effects (Health = 0)**
- Fire particles start
- Heavy smoke particles start
- Vehicle controls disabled
- (Optional: Auto-respawn after delay)

---

## 🛠️ **Setup Instructions**

### **Step 1: Create Particle Nodes**

In your vehicle scene, add 3 GPUParticles3D nodes:

```
Vehicle (RigidBody3D)
├── Body (MeshInstance3D)
├── Wheels...
├── DamageSmoke (GPUParticles3D)        ← Light smoke
├── DestructionFire (GPUParticles3D)    ← Fire
└── DestructionSmoke (GPUParticles3D)   ← Heavy smoke
```

### **Step 2: Configure Damage Smoke**

Select `DamageSmoke` node:

**Transform:**
- Position: `(0, 0.5, 0)` (above vehicle center)

**GPUParticles3D Settings:**
- **Emitting**: OFF (script controls this)
- **Amount**: 20-30
- **Lifetime**: 2.0-3.0
- **One Shot**: OFF
- **Explosiveness**: 0.0
- **Randomness**: 0.3

**Process Material** (ParticleProcessMaterial):
- **Direction**: Y (0, 1, 0)
- **Spread**: 15-20 degrees
- **Initial Velocity**: 1.0-2.0
- **Gravity**: (0, 0.5, 0) - slight upward drift
- **Scale**: 0.5 → 2.0 (grows over time)
- **Color**: Gray (0.3, 0.3, 0.3, 1.0) → Transparent

**Draw Pass 1:**
- Add a QuadMesh
- Material: StandardMaterial3D
  - **Transparency**: Alpha
  - **Albedo**: Gray smoke texture or color
  - **Billboard**: Enabled

### **Step 3: Configure Destruction Fire**

Select `DestructionFire` node:

**Transform:**
- Position: `(0, 0.3, 0)` (lower, at engine level)

**GPUParticles3D Settings:**
- **Emitting**: OFF
- **Amount**: 50-80
- **Lifetime**: 0.5-1.0
- **Explosiveness**: 0.7
- **Randomness**: 0.5

**Process Material:**
- **Direction**: Y (0, 1, 0)
- **Spread**: 30 degrees
- **Initial Velocity**: 2.0-4.0
- **Gravity**: (0, 1.0, 0) - upward
- **Scale**: 0.3 → 0.8
- **Color**: Orange/Red gradient
  - Start: (1.0, 0.5, 0.0, 1.0) - Orange
  - End: (1.0, 0.0, 0.0, 0.0) - Red fade

**Draw Pass 1:**
- QuadMesh
- Material: StandardMaterial3D
  - **Transparency**: Alpha
  - **Albedo**: Orange/yellow
  - **Emission**: Enabled (bright!)
  - **Emission Energy**: 2.0-3.0
  - **Billboard**: Enabled

### **Step 4: Configure Destruction Smoke**

Select `DestructionSmoke` node:

**Transform:**
- Position: `(0, 0.5, 0)`

**GPUParticles3D Settings:**
- **Emitting**: OFF
- **Amount**: 40-60
- **Lifetime**: 3.0-5.0
- **Explosiveness**: 0.3
- **Randomness**: 0.4

**Process Material:**
- **Direction**: Y (0, 1, 0)
- **Spread**: 25 degrees
- **Initial Velocity**: 1.5-3.0
- **Gravity**: (0, 0.3, 0)
- **Scale**: 1.0 → 3.0 (large billowing smoke)
- **Color**: Dark gray → Light gray → Transparent

**Draw Pass 1:**
- QuadMesh
- Material: Dark smoke (similar to damage smoke but denser)

### **Step 5: Connect in Inspector**

Select your **Vehicle** node:

In **"Vehicle Health & Fuel"** section:
1. **Damage Smoke Threshold**: `30.0` (smoke starts at 30% health)
2. **Damage Smoke Particles**: Drag `DamageSmoke` node here
3. **Destruction Fire Particles**: Drag `DestructionFire` node here
4. **Destruction Smoke Particles**: Drag `DestructionSmoke` node here

---

## 🎨 **Quick Setup (No Textures)**

If you don't have smoke/fire textures, use simple colored particles:

### **Damage Smoke (Simple)**
```
Material: StandardMaterial3D
- Albedo Color: (0.3, 0.3, 0.3, 0.5) - Semi-transparent gray
- Transparency: Alpha
- Billboard: Enabled
```

### **Fire (Simple)**
```
Material: StandardMaterial3D
- Albedo Color: (1.0, 0.5, 0.0, 0.8) - Orange
- Emission: Enabled
- Emission: (1.0, 0.5, 0.0)
- Emission Energy: 3.0
- Transparency: Alpha
- Billboard: Enabled
```

### **Heavy Smoke (Simple)**
```
Material: StandardMaterial3D
- Albedo Color: (0.2, 0.2, 0.2, 0.7) - Dark gray
- Transparency: Alpha
- Billboard: Enabled
```

---

## 🧪 **Testing**

### **1. Test Damage Smoke**
1. Run the game
2. Take damage until health < 30%
3. Smoke should start appearing
4. More damage = more smoke

### **2. Test Destruction**
1. Crash until health = 0
2. Fire and heavy smoke should start
3. Vehicle should stop responding to input
4. Console shows "VEHICLE DESTROYED"

---

## ⚙️ **Customization**

### **Change Smoke Threshold**

In Inspector:
- **Damage Smoke Threshold**: `30.0` (default)
- Lower = smoke appears earlier
- Higher = smoke appears later

Examples:
- `50.0` - Smoke at half health
- `20.0` - Smoke only when critical
- `0.0` - No damage smoke (only destruction)

### **Adjust Smoke Intensity**

The script automatically scales smoke based on health:
- 30% health = 30% smoke intensity
- 15% health = 65% smoke intensity
- 5% health = 100% smoke intensity

### **Add More Effects**

You can add additional particles:
- Sparks when damaged
- Oil leaks
- Steam from radiator
- Explosion burst on destruction

Just create the GPUParticles3D and control them in the script!

---

## 🎯 **Particle Tips**

1. **Performance**: Keep particle counts low (20-80 per emitter)
2. **Lifetime**: Longer lifetime = more particles on screen
3. **Billboard**: Always enable for smoke/fire
4. **Emission**: Fire should have high emission energy
5. **Scale Curve**: Smoke should grow over time
6. **Color Gradient**: Fade to transparent at the end

---

## 🔥 **Advanced: Explosion on Destruction**

Add a one-shot explosion particle:

```gdscript
# In _on_vehicle_destroyed():
var explosion = preload("res://explosion.tscn").instantiate()
get_parent().add_child(explosion)
explosion.global_position = global_position
```

Create `explosion.tscn`:
- GPUParticles3D
- **One Shot**: ON
- **Explosiveness**: 1.0
- **Amount**: 100-200
- **Lifetime**: 0.3-0.5
- Bright orange/yellow with high emission

---

## 📋 **Checklist**

- [ ] Created 3 GPUParticles3D nodes
- [ ] Configured particle materials
- [ ] Set emitting to OFF on all particles
- [ ] Connected particles in Inspector
- [ ] Set damage smoke threshold
- [ ] Tested damage smoke (< 30% health)
- [ ] Tested destruction effects (0 health)

---

Your vehicle now has realistic damage visualization! 🔥💨
