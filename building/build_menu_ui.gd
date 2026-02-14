extends Control

const BuildBlueprint = preload("res://building/blueprint.gd")

signal blueprint_selected(blueprint: BuildBlueprint)

@onready var grid_container = %GridContainer
@onready var search_bar = %SearchBar
@onready var category_tabs = %CategoryTabs
@onready var sub_category_tabs = %SubCategoryTabs

var all_blueprints: Array[BuildBlueprint] = []

func _ready():
	_load_blueprints()
	category_tabs.tab_changed.connect(_on_category_tabs_tab_changed)
	sub_category_tabs.tab_changed.connect(_on_category_tabs_tab_changed) # Same for now
	search_bar.text_changed.connect(_on_search_bar_text_changed)
	_update_grid()

func _load_blueprints():
	all_blueprints.clear()
	var path = "res://building/blueprints/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name)
				if res is BuildBlueprint:
					all_blueprints.append(res)
			file_name = dir.get_next()
	
	print("Loaded blueprints: ", all_blueprints.size())

func _update_grid():
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()
	
	# Filter by category, sub-category and search
	var category = category_tabs.get_tab_title(category_tabs.current_tab)
	var sub_category = sub_category_tabs.get_tab_title(sub_category_tabs.current_tab)
	var search_text = search_bar.text.to_lower()
	
	for blueprint in all_blueprints:
		if blueprint.category == category and blueprint.sub_category == sub_category:
			if search_text == "" or search_text in blueprint.name.to_lower():
				_create_item_button(blueprint)

func _create_item_button(blueprint: BuildBlueprint):
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 80)
	btn.text = blueprint.name # Fallback if no icon
	btn.icon = blueprint.icon
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.tooltip_text = blueprint.name + "\n" + blueprint.description
	btn.pressed.connect(func(): blueprint_selected.emit(blueprint))
	grid_container.add_child(btn)

func open():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_category_tabs_tab_changed(_tab):
	_update_grid()

func _on_search_bar_text_changed(_new_text):
	_update_grid()
