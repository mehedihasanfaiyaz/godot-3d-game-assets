extends Resource
class_name InventorySlot

@export var item: Resource
@export var quantity: int = 0:
	set(value):
		quantity = value
		if quantity <= 0:
			item = null
			quantity = 0
		emit_changed()
