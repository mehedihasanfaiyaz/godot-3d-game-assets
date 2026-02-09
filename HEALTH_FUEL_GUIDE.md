# Vehicle Health & Fuel System Guide

## ✅ **What's New**

Your vehicle now has:
- **Health System** - Takes damage from collisions
- **Fuel System** - Consumes fuel while driving
- **Updated HUD** - Shows health and fuel bars

---

## 🎯 **Health System**

### **How It Works**
- Vehicle starts with **100 health**
- Takes damage when colliding at high speed
- Damage = `(impact_velocity - threshold) × multiplier`
- Vehicle is destroyed when health reaches 0

### **Configuration (Inspector)**

Under **"Vehicle Health & Fuel"**:

- **Max Health**: `100.0` (total health)
- **Damage Threshold**: `10.0` (minimum collision speed for damage)
- **Damage Multiplier**: `2.0` (damage scaling)
- **Health Regeneration**: `0.0` (health per second, 0 = no regen)

### **Examples**

**Light Damage:**
- Threshold: `10.0`
- Multiplier: `1.0`
- Result: Gentle collisions

**Heavy Damage:**
- Threshold: `5.0`
- Multiplier: `5.0`
- Result: Realistic crash damage

**Regenerating Health:**
- Health Regeneration: `5.0`
- Result: Heals 5 HP per second

---

## ⛽ **Fuel System**

### **How It Works**
- Vehicle starts with **100 fuel**
- Fuel depletes while driving (throttle/reverse)
- **Extra consumption** when boosting (3x by default)
- Vehicle **stops** when fuel reaches 0

### **Configuration (Inspector)**

- **Max Fuel**: `100.0` (total fuel capacity)
- **Fuel Consumption Rate**: `5.0` (fuel per second while driving)
- **Fuel Boost Multiplier**: `3.0` (extra consumption when boosting)
- **Fuel Regeneration**: `0.0` (fuel per second when idle, 0 = no regen)

### **Fuel Consumption Examples**

**Normal Driving:**
- Rate: `5.0`
- Result: 20 seconds of driving

**With Boost:**
- Rate: `5.0`
- Multiplier: `3.0`
- Result: `15.0` fuel/sec when boosting

**Arcade Mode (Infinite Fuel):**
- Fuel Regeneration: `999.0`
- Result: Never runs out

---

## 🎨 **HUD Display**

The HUD now shows 4 bars:

### **1. Speed** (Cyan)
- Shows current speed in km/h

### **2. Boost** (White/Yellow/Red)
- White: > 50%
- Yellow: 25-50%
- Red: < 25%

### **3. Health** (Green/Yellow/Red)
- Green: > 50%
- Yellow: 25-50%
- Red: < 25%

### **4. Fuel** (Cyan/Yellow/Red)
- Cyan: > 50%
- Yellow: 25-50%
- Red: < 25%

---

## 🎮 **Gameplay Mechanics**

### **Fuel Management**
1. **Drive carefully** - Fuel depletes while moving
2. **Avoid boosting** - Uses 3x more fuel
3. **Idle to refuel** - If regeneration is enabled

### **Health Management**
1. **Avoid high-speed crashes** - Damage increases with speed
2. **Slow down before impact** - Below threshold = no damage
3. **Wait for regen** - If health regeneration is enabled

### **Out of Fuel**
- Vehicle stops accepting throttle/reverse input
- Boost is disabled
- Must wait for regeneration or respawn

### **Vehicle Destroyed (0 Health)**
- `_on_vehicle_destroyed()` is called
- Currently shows a warning
- You can add:
  - Explosion effects
  - Respawn logic
  - Game over screen

---

## ⚙️ **Customization Examples**

### **Realistic Racing Game**
```
Max Health: 100
Damage Threshold: 15.0
Damage Multiplier: 3.0
Health Regeneration: 0.0

Max Fuel: 100
Fuel Consumption: 8.0
Fuel Boost Multiplier: 4.0
Fuel Regeneration: 0.0
```

### **Arcade Racing Game**
```
Max Health: 100
Damage Threshold: 20.0
Damage Multiplier: 1.0
Health Regeneration: 5.0

Max Fuel: 100
Fuel Consumption: 3.0
Fuel Boost Multiplier: 2.0
Fuel Regeneration: 10.0
```

### **Hardcore Survival**
```
Max Health: 50
Damage Threshold: 5.0
Damage Multiplier: 10.0
Health Regeneration: 0.0

Max Fuel: 50
Fuel Consumption: 10.0
Fuel Boost Multiplier: 5.0
Fuel Regeneration: 0.0
```

### **Invincible Mode**
```
Max Health: 999999
Damage Threshold: 999999
Health Regeneration: 999999

Max Fuel: 999999
Fuel Regeneration: 999999
```

---

## 🔧 **Advanced: Custom Destruction**

Edit the `_on_vehicle_destroyed()` function to add custom behavior:

```gdscript
func _on_vehicle_destroyed() -> void:
	# Add explosion particle effect
	var explosion = preload("res://explosion.tscn").instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	# Play sound
	$ExplosionSound.play()
	
	# Respawn after 3 seconds
	await get_tree().create_timer(3.0).timeout
	global_position = Vector3(0, 5, 0)  # Spawn position
	current_health = max_health
	current_fuel = max_fuel
```

---

## 📊 **Monitoring Values**

You can access these values from other scripts:

```gdscript
# Get current health
var health = $Vehicle.current_health

# Get current fuel
var fuel = $Vehicle.current_fuel

# Check if vehicle is destroyed
if $Vehicle.current_health <= 0:
	print("Vehicle destroyed!")

# Check if out of fuel
if $Vehicle.current_fuel <= 0:
	print("Out of fuel!")
```

---

## 🎯 **Tips**

1. **Balance fuel consumption** - Too high = frustrating, too low = no challenge
2. **Test damage threshold** - Adjust based on your game's speed
3. **Use regeneration wisely** - Good for arcade games, bad for realistic games
4. **Color coding helps** - Players instantly see critical levels
5. **Add audio cues** - Low fuel warning, damage sounds, etc.

---

## 🚗 **Complete Feature List**

Your vehicle now has:
- ✅ Realistic physics
- ✅ Boost system with fuel
- ✅ Health with collision damage
- ✅ Fuel consumption
- ✅ Vehicle lights (headlights, brake, reverse, turn signals)
- ✅ Complete HUD (speed, boost, health, fuel)
- ✅ Multi-camera system
- ✅ Drift mechanics
- ✅ Air control
- ✅ Multi-axle steering (for long vehicles)

You have a complete, production-ready vehicle system! 🎉
