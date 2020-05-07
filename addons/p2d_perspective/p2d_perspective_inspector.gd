extends EditorInspectorPlugin
func can_handle(object):
	if object!=null:
		if object.is_class("Sprite") && object.is_in_group("p2d_canvas_child"):
			var p2d_inspector_control=load(str(self.get_script().get_path().get_base_dir(),"/p2d_inspector_control.tscn"))			
			var inspector_instance=p2d_inspector_control.instance()
			add_custom_control(inspector_instance)
			inspector_instance.set_edit_target(object)
			return true
		
	return false
