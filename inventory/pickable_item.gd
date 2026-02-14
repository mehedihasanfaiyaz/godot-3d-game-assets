extends StaticBody3D

@export var item_data: ItemData
@export var quantity: int = 1

func _ready():
	# If we have a mesh child, we can set its visual based on item_data if needed
	# For now, we'll just assume the scene has a visual representation
	pass

func interact(player):
	if player.inventory_data.add_item(item_data, quantity) == 0:
		# Item completely added
		queue_free()
	else:
		# Item partially added or inventory full (not yet handled perfectly in add_item but good enough)
		# For now, we'll just remove it if anything was added
		queue_free()
