extends Node2D


onready var camera=get_node("camera")
onready var p2d=get_node("P2DPerspectiveNode")

func _process(delta):
	var pos=Vector2(0,0)
	if Input.is_action_just_released("ui_accept"):
		p2d.ShowProjectionLines=!get_node("P2DPerspectiveNode").ShowProjectionLines
		
	if Input.is_action_pressed("ui_left"):
		pos.x=-500
	if Input.is_action_pressed("ui_right"):
		pos.x=500
	if Input.is_action_pressed("ui_up"):
		pos.y=-500		
	if Input.is_action_pressed("ui_down"):
		pos.y=500
	
	if !Input.is_key_pressed(KEY_CONTROL):
		camera.position+=pos*delta
	else:
		p2d.VanishingPoint+=pos*delta
