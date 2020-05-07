#Inspector controller script
tool
extends VBoxContainer
var edit_target:Sprite=null

var p2d_mode_trans={"boxes":0,"clone":1,"none":2}
var p2d_modes=["boxes","clone","none"]
onready var file_diag=get_node("file_diag")


func set_edit_target(object:Sprite):
	edit_target=object
	
	#setup target sfuff
	#react to texture changes
	edit_target.connect("texture_changed",self,"reset_texture")
	
	#initialize UI controls
	if edit_target.has_meta("p2d_mode"):
		get_node("gc/op_mode").select(p2d_mode_trans[edit_target.get_meta("p2d_mode")])
	else:
		get_node("gc/op_mode").select(p2d_mode_trans[edit_target.get_meta("p2d_canvas_mode")])
	
	get_node("gc/op_projection_start").value=edit_target.__meta__.get("p2d_start_projection",0)
	
	change_mode(get_node("gc/op_mode").get_selected_id())
	get_node("gc/op_mode").connect("item_selected",self,"change_mode")
	get_node("gc/op_projection_start").connect("value_changed",self,"projection_change")

	for boxchild in get_node("gc2").get_children():
		var draw=true
		if edit_target.has_meta(boxchild.get_name()):
			draw=edit_target.get_meta(boxchild.get_name())
		
		boxchild.set_pressed(draw)
		boxchild.connect("pressed",self,"control_change",[boxchild,"boxes"])
	
	for boxchild in get_node("gc3").get_children():
		if boxchild.is_class("MenuButton"):
			boxchild.get_popup().connect("id_pressed",self,"tex_option",[boxchild])
	
	for tex_control in ["boxes_texture_top","boxes_texture_bottom"]:
		if edit_target.has_meta(tex_control):
			tex_update(get_node("gc3/"+tex_control),edit_target.get_meta(str(tex_control,"_file")),edit_target.get_meta(tex_control))

func reset_texture():
	if (edit_target):  
		edit_target.set_meta("side_texture",null)
	
func change_mode(item_id):
	edit_target.set_meta("p2d_mode",p2d_modes[item_id])
	for boxchild in get_node("gc2").get_children():
		boxchild.set_disabled(p2d_modes[item_id]!="boxes")
	for boxchild in get_node("gc3").get_children():
		if boxchild.has_method("set_disabled"):
			boxchild.set_disabled(p2d_modes[item_id]!="boxes")

func projection_change(value):
	edit_target.set_meta("p2d_start_projection",value)
	#if start projection is set, change original sprite to invisible (not touching the visibility flag of course)
	#hacky but gets the job done LOL
	if value>0:
		edit_target.self_modulate.a=0
	else:
		edit_target.self_modulate.a=1

func control_change(caller,type):
	if type=="boxes":
		edit_target.set_meta(caller.get_name(),caller.is_pressed())

func tex_option(id,target):
	match id:
		0: #load
			file_diag.popup(Rect2((get_viewport_rect().size/2)-(file_diag.get_size()/2),file_diag.get_size()))
			if(!file_diag.is_connected("file_selected",self,"tex_selected")):
				file_diag.connect("file_selected",self,"tex_selected",[target])
		1: #clear			
			edit_target.set_meta(target.get_name(),null)
			target.set_button_icon(null)
			target.set_text("[assign]")
			get_node(str("gc3/",target.get_name(),"_val")).set_text("")
			

func tex_update(target,text,icon):
	target.set_text("")
	var val_name=str("gc3/",target.get_name(),"_val")
	var val_node=get_node(val_name)
	if val_node:
		val_node.set_text(text)
	target.set_button_icon(icon)
	
func tex_selected(file,target):
	var texture=ResourceLoader.load(file)
	tex_update(target,file,texture)
	edit_target.set_meta(target.get_name(),texture)
	edit_target.set_meta(str(target.get_name(),"_file"),file)

func _draw(): #bleh styling
	var rect=get_rect()
	rect.position-=Vector2(margin_left,margin_top)
	draw_rect(rect,Color(0,0,0,0.5),true)
	
	
