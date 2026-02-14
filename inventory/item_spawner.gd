extends Node3D

var pickable_item_scene = preload("res://inventory/pickable_item.tscn")

func _ready():
	# Spawn a few items around the start
	spawn_item("Steel Pickaxe", ItemData.Category.TOOLS, "A heavy duty tool.", Vector3(2, 0.5, 2))
	spawn_item("Apple", ItemData.Category.CONSUMABLES, "Tasty!", Vector3(-2, 0.5, 2))
	spawn_item("Wood", ItemData.Category.MATERIALS, "Basic material.", Vector3(2, 0.5, -2))
	spawn_item("Health Potion", ItemData.Category.CONSUMABLES, "Heals you.", Vector3(-2, 0.5, -2))
	spawn_item("Iron Ore", ItemData.Category.MATERIALS, "Raw ore.", Vector3(0, 0.5, 4))

func spawn_item(item_name: String, category: ItemData.Category, description: String, pos: Vector3):
	var item = pickable_item_scene.instantiate()
	add_child(item)
	item.global_position = pos
	
	# Create data for this specific item
	var data = ItemData.new()
	data.item_name = item_name
	data.category = category
	data.description = description
	
	item.item_data = data
	print("Spawned item: ", item_name, " at ", pos)
