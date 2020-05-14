extends Node2D

onready var camera=$camera
onready var p2d=$P2DPerspectiveNode

var move={
	"left":false,
	"right":false,
	"up":false,
	"down":false
}

func _input(event):
	move["down"]=Input.is_action_pressed("ui_down")
	move["up"]=Input.is_action_pressed("ui_up")
	move["left"]=Input.is_action_pressed("ui_left")
	move["right"]=Input.is_action_pressed("ui_right")
	
	if event.is_class("InputEventKey"):
		if event.get_scancode()==KEY_PLUS || event.get_scancode()==KEY_KP_ADD && event.is_pressed():
			$P2DPerspectiveNode.ProjectionDistance=min(80,$P2DPerspectiveNode.ProjectionDistance+10)
		if event.get_scancode()==KEY_MINUS || event.get_scancode()==KEY_KP_SUBTRACT && event.is_pressed():
			$P2DPerspectiveNode.ProjectionDistance=max(20,$P2DPerspectiveNode.ProjectionDistance-10)
		if event.get_scancode()==KEY_KP_MULTIPLY && event.is_pressed():
			$P2DPerspectiveNode.FastRepeat=!$P2DPerspectiveNode.FastRepeat
	
func _process(delta):
	
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
	
	for n in get_tree().get_nodes_in_group("boundary_text"):
		var tpos=n.get_position()
		tpos.y=camera.position.y
		n.set_position(tpos)
	
	$CanvasLayer/Panel/fps.set_text(str(Engine.get_frames_per_second()," fps [p2d_draw_calls=",$P2DPerspectiveNode.get_meta("last_draw_calls"),"]"))
	$CanvasLayer/Panel/fast_repeat.set_text(str($P2DPerspectiveNode.FastRepeat))
	$CanvasLayer/Panel/pdistance.set_text(str($P2DPerspectiveNode.ProjectionDistance))
