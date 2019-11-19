tool

extends EditorPlugin

var p2d_inspector_class=load(str(self.get_script().get_path().get_base_dir(),"/p2d_perspective_inspector.gd"))
var p2d_inspector=p2d_inspector_class.new()

func _enter_tree():
	add_custom_type("P2DPerspectiveNode", "Node2D", preload("p2d_perspective_node.gd"), preload("p2d_icon.png"))
	add_inspector_plugin(p2d_inspector)	
	
func _exit_tree():
	remove_custom_type("P2DPerspectiveNode")
	remove_inspector_plugin(p2d_inspector)
