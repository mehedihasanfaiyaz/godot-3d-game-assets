extends Resource
class_name InventoryData

@export var slots: Array[Resource] = [] # Use base Resource for Array to avoid type issues

signal inventory_updated

func add_item(item: ItemData, quantity: int = 1) -> int:
	var remaining = quantity
	
	# Try stacking in existing slots first
	if item.stackable:
		for slot in slots:
			if slot.item == item and slot.quantity < item.max_stack:
				var add_amount = min(remaining, item.max_stack - slot.quantity)
				slot.quantity += add_amount
				remaining -= add_amount
				if remaining <= 0:
					inventory_updated.emit()
					return 0
	
	# Try finding empty slots
	for i in range(slots.size()):
		if slots[i].item == null:
			var slot = InventorySlot.new()
			slot.item = item
			var add_amount = min(remaining, item.max_stack)
			slot.quantity = add_amount
			slots[i] = slot
			remaining -= add_amount
			if remaining <= 0:
				inventory_updated.emit()
				return 0
				
	inventory_updated.emit()
	return remaining
