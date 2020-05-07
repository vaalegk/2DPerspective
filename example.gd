extends Node2D

onready var camera=get_node("camera")
onready var p2d=get_node("P2DPerspectiveNode")

var move={
	"left":false,
	"right":false,
	"up":false,
	"down":false
}

	
func _process(delta):
	move["down"]=Input.is_action_pressed("ui_down")
	move["up"]=Input.is_action_pressed("ui_up")
	move["left"]=Input.is_action_pressed("ui_left")
	move["right"]=Input.is_action_pressed("ui_right")
	
	var pos=Vector2(0,0)
	if Input.is_action_just_released("ui_accept"):
		p2d.ShowProjectionLines=!get_node("P2DPerspectiveNode").ShowProjectionLines
		
	if move["left"]:
		pos.x=-500
	if move["right"]:
		pos.x=500
	if move["up"]:
		pos.y=-500
	if move["down"]:
		pos.y=500
	
	if !Input.is_key_pressed(KEY_CONTROL):
		camera.position+=pos*delta
	else:
		p2d.VanishingPoint+=pos*delta
	
	get_node("CanvasLayer/Panel/fps").set_text(str(Engine.get_frames_per_second()," fps"))
