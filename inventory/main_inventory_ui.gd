extends Control

@onready var tab_container = %TabContainer
@onready var grid_container = %GridContainer
@onready var item_name_label = %ItemName
@onready var item_description_label = %ItemDescription

var slot_scene = preload("res://inventory/inventory_slot_ui.tscn")
var inventory_data: InventoryData

func setup(data: InventoryData):
	inventory_data = data
	inventory_data.inventory_updated.connect(_on_inventory_updated)
	_on_inventory_updated()

func _on_inventory_updated():
	_update_category_view(tab_container.current_tab)

func _update_category_view(category_index):
	# Clear grid
	for child in grid_container.get_children():
		child.queue_free()
	
	# Mapping category index to Enum
	# TOOLS, CONSUMABLES, MATERIALS, SPECIAL, CONSTRUCTION, DEVIATIONS
	var category = category_index as ItemData.Category
	
	for slot in inventory_data.slots:
		if slot.item and slot.item.category == category:
			var slot_ui = slot_scene.instantiate()
			grid_container.add_child(slot_ui)
			_update_slot_ui(slot_ui, slot)

func _update_slot_ui(slot_ui, slot):
	var icon = slot_ui.get_node("%Icon")
	var quantity = slot_ui.get_node("%Quantity")
	var button = slot_ui.get_node("%Button")
	
	icon.texture = slot.item.icon
	quantity.text = str(slot.quantity) if slot.quantity > 1 else ""
	
	button.mouse_entered.connect(func():
		item_name_label.text = slot.item.item_name
		item_description_label.text = slot.item.description
	)

func _on_tab_container_tab_changed(tab):
	_update_category_view(tab)
