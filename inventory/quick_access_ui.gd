extends HBoxContainer



var slot_scene = preload("res://inventory/inventory_slot_ui.tscn")
var inventory_data: InventoryData

func setup(data: InventoryData):
	inventory_data = data
	inventory_data.inventory_updated.connect(_on_inventory_updated)
	_on_inventory_updated()

func _on_inventory_updated():
	for child in get_children():
		child.queue_free()
	
	# Show first 8 slots as quick access (or implement a specific 'hotbar' property)
	for i in range(min(8, inventory_data.slots.size())):
		var slot_ui = slot_scene.instantiate()
		add_child(slot_ui)
		_update_slot_ui(slot_ui, inventory_data.slots[i])

func _update_slot_ui(slot_ui, slot):
	var icon = slot_ui.get_node("%Icon")
	var quantity = slot_ui.get_node("%Quantity")
	
	if slot.item:
		icon.texture = slot.item.icon
		quantity.text = str(slot.quantity) if slot.quantity > 1 else ""
	else:
		icon.texture = null
		quantity.text = ""
