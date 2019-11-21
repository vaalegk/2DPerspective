tool

extends CanvasItem

#Vanishing Point, relative to camera/view center
#Punto de Fuga, relavito al centro de la camara/view 
export(Vector2) var VanishingPoint 
#Max Projection distance 0=Nothing 100=Toching VanishingPoint 
#Maxima distancia de proyeccion 0=Nada 100=Tocando Punto de fuga
export(int,100) var ProjectionDistance=20
#Used for "clone" projection (ProjectionDistanceStep) its a divider for ProjectionDistance and controls the clone number
#Usado para la proyeccion tipo "clone", es un divisor y controla la cantidad de clones
export(int,10) var ProjectionDistanceStep=2
#Projection mode 
#Modo de Proyeccion
export(String,"boxes","clone") var ProjectionMode="boxes" setget setProjectionMode

#self explanatory
export(Color) var ProjectionLineColor=Color(0,1,0,0.5)
export(bool) var ShowProjectionLines=false

#Amount to grow viewable area to detect if we draw something or not
export(int) var AreaBuffer=50

#List of elements within the projectable view
#Lista de elementos en el vista proyectable
var draw_elements=[]
var working_childs=[]

func setProjectionMode(mode):
	ProjectionMode=mode
	propagate_call("set_meta",["p2d_canvas_mode",ProjectionMode])

func _init():
	set_meta("p2d_canvas",true)#to play nice with editor addon

func _ready():
	propagate_call("add_to_group",["p2d_canvas_child"])
	propagate_call("set_meta",["p2d_canvas_mode",ProjectionMode])
	propagate_call("set_meta",["p2d_canvas_name",get_path()])
	find_working_childs()
	get_tree().connect("node_added",self,"scene_tree_listener",["add"])
	get_tree().connect("node_removed",self,"scene_tree_listener",["remove"])

func _process(delta):
	update()

func scene_tree_listener(node,action):
	var update_childs=false
	if action=="add" && node.is_class("Sprite"):
		propagate_call("add_to_group",["p2d_canvas_child"])
		propagate_call("set_meta",["p2d_canvas_mode",ProjectionMode])
		propagate_call("set_meta",["p2d_canvas_name",get_name()])
		update_childs=true
	if action=="remove" && node.is_in_group("p2d_canvas_child"):
		update_childs=true 
	if update_childs:
		find_working_childs()

func find_working_childs():
	working_childs.clear()
	if get_tree()==null: #play nice with deinitialization routines
		return
	for cc in get_tree().get_nodes_in_group("p2d_canvas_child"):
		if cc.is_class("Sprite"):
			working_childs.append(cc)
	print("Found ",working_childs.size()," children to work with :D")

func _draw():
	#clear list
	draw_elements.clear()
	
	#try to get the viewport information for projection
	var vtrans = get_global_transform_with_canvas()
	var top_left = -vtrans.get_origin() / vtrans.get_scale()
	var vsize = get_viewport_rect().size
	var cam_pos= top_left + 0.5*vsize/vtrans.get_scale()
	var crect=get_viewport_rect()
	var rect=Rect2(cam_pos-Vector2(vsize.x/2,vsize.y/2).abs(),cam_pos+Vector2(vsize.x/2,vsize.y/2).abs())
	var center=Vector2(rect.end.x/2,rect.end.y/2)+VanishingPoint

	#add some buffer for partially offview sprites
	crect=Rect2(top_left,vsize).grow(AreaBuffer)

	var final_group=""
	var in_view=[]
	for cc in working_childs:
		#print(cc," ->",cc.get_groups()) 
		var child_rect=cc.get_rect()
		
		child_rect.position=cc.position
		child_rect.size=child_rect.size*cc.scale
		if cc.is_centered():
			child_rect.position-=child_rect.size/2
		
		var rect_center=child_rect.position+(child_rect.size/2)
		
		final_group=str("mode_",ProjectionMode)
	
		if cc.has_meta("p2d_mode"):
			final_group=str("mode_",cc.get_meta("p2d_mode"))
			
		var child_rect_struct=get_child_rect(cc,child_rect,cc.get_rotation(),center)
		var child_top=Vector2(child_rect_struct["min_x"],child_rect_struct["min_y"])
		var child_bottom=Vector2(child_rect_struct["max_x"],child_rect_struct["max_y"])
		
		var child_rect_view=Rect2(child_top,child_bottom-child_top)
		#skip, not in view, not visible, in excluded group
		if crect.intersects(child_rect_view)==false || !cc.is_visible() || final_group=="mode_none":
			continue  #next 
				
		in_view.append({"sprite":cc,"center":rect_center,"rect":child_rect_struct,"group":final_group.to_lower(),"view_center":center})
	
	#kindda sort stuff to avoid see-though artifacts, if you need actual pixel perfect projections with zbuffers use 3d dude WTH haha! 
	in_view.sort_custom(self,"sort_drawables")
		
	for cc in in_view:
		if ShowProjectionLines:
			draw_elements.append({"func":"draw_projection_lines","params":[[cc["rect"]["p1"],cc["rect"]["p2"],cc["rect"]["p3"],cc["rect"]["p4"]],center,0.5]})
		self.call(cc["group"],cc["sprite"],cc["rect"],center)
	
	if draw_elements.size()>0:
		for d in draw_elements:
			callv(d["func"],d["params"])

#helper function to draw the projection lines... if needed
func draw_projection_lines(points,center,size):
	for p in points:
		draw_line(p,Vector2(center.x,center.y),ProjectionLineColor,size)

#helper function to sort stuff
func sort_drawables(A,B):	
	var ret=false
	if A["center"].x>A["view_center"].x:
		if A["center"].x>B["center"].x:
			ret=true
	else:
		if A["center"].x<B["center"].x:
			return true
	return ret

func get_child_rect(child,child_rect,rot,center):
	var rect_p1=child_rect.position
	var rect_p2=Vector2(child_rect.end.x,child_rect.position.y)
	var rect_p3=child_rect.end
	var rect_p4=Vector2(child_rect.position.x,child_rect.end.y)
	var rect_center=child_rect.position+(child_rect.size/2)
	
	if rot!=0:
		var transform=Transform2D(rot,get_transform().get_origin()+rect_center)
		var center_diff=rect_center
		rect_center=transform.xform(rect_center)
		center_diff=center_diff-rect_center
		rect_p1=transform.xform(rect_p1)+center_diff
		rect_p2=transform.xform(rect_p2)+center_diff
		rect_p3=transform.xform(rect_p3)+center_diff
		rect_p4=transform.xform(rect_p4)+center_diff
	
	#apply parent transforms too if any
	var relative_path=NodePath(str(child.get_path()).replace(child.get_meta("p2d_canvas_name"),""))	
	if relative_path.get_name_count()>1:
		var curr_parent=child.get_meta("p2d_canvas_name")
		var parent_offset=Vector2(0,0)
		for p in range(0,relative_path.get_name_count()-1):
			curr_parent=str(curr_parent,"/",relative_path.get_name(p))
			var parent=get_node(curr_parent)
			if parent.has_method("get_position"):
				parent_offset+=parent.get_position()
		rect_p1+=parent_offset
		rect_p2+=parent_offset
		rect_p3+=parent_offset
		rect_p4+=parent_offset
		rect_center+=parent_offset
	var result={
		"p1":rect_p1,
		"p2":rect_p2,
		"p3":rect_p3,
		"p4":rect_p4,
		"center":rect_center,
		"min_x":[rect_p1.x,rect_p2.x,rect_p3.x,rect_p4.x].min(),
		"max_x":[rect_p1.x,rect_p2.x,rect_p3.x,rect_p4.x].max(),
		"min_y":[rect_p1.y,rect_p2.y,rect_p3.y,rect_p4.y].min(),
		"max_y":[rect_p1.y,rect_p2.y,rect_p3.y,rect_p4.y].max()
	}
	for i in range(1,4):
		result["min_x"]=min(result["min_x"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).x)
		result["min_y"]=min(result["min_y"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).y)
		result["max_x"]=max(result["max_x"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).x)
		result["max_y"]=max(result["max_y"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).y)
		
	return result

#box drawing function used for "boxes" projection mode
func mode_boxes(sp,rect,center):	
	var pols=[]
	var to_draw=[]
#	var rect=get_child_rect(sp,child_rect,sp.get_rotation())

	if rect["p1"].y<center.y:
		if sp.__meta__.get("boxes_side_left",true):
			to_draw.append(2)
		if rect["p2"].x<center.x && sp.__meta__.get("boxes_side_right",true) :
			to_draw.append(3)		
		if rect["p3"].y<center.y && sp.__meta__.get("boxes_side_bottom",true) :
			to_draw.append(1)
	else:
		if rect["p2"].x<center.x && sp.__meta__.get("boxes_side_right",true) :
			to_draw.append(3)
		if rect["p1"].x>center.x && sp.__meta__.get("boxes_side_left",true) :
			to_draw.append(2)
		if sp.__meta__.get("boxes_side_top",true):
			to_draw.append(0)
	
	var proj_p1=rect["p1"].linear_interpolate(center,float(ProjectionDistance)/100)
	var proj_p2=rect["p2"].linear_interpolate(center,float(ProjectionDistance)/100)
	var proj_p3=rect["p3"].linear_interpolate(center,float(ProjectionDistance)/100)
	var proj_p4=rect["p4"].linear_interpolate(center,float(ProjectionDistance)/100)
	
	var textures=[sp.get_texture(),sp.get_texture(),sp.get_texture(),sp.get_texture()]
	
	if sp.has_meta("boxes_texture_top"):
		textures[0]=sp.get_meta("boxes_texture_top")
	if sp.has_meta("boxes_texture_bottom"):
		textures[1]=sp.get_meta("boxes_texture_bottom")
	
	#top
	pols.append([proj_p1,proj_p2,rect["p2"],rect["p1"]])
	#bottom
	pols.append([rect["p4"],rect["p3"],proj_p3,proj_p4])
	#left
	pols.append([proj_p1,rect["p1"],rect["p4"],proj_p4])
	#right
	pols.append([rect["p2"],proj_p2,proj_p3,rect["p3"]])

	for p in to_draw:
		draw_elements.append({"func":"draw_polygon","params":[pols[p],[],[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],textures[p],null,true]})
		

func mode_clone(sp,rect,center):	
	var rot=sp.get_rotation()
	#var rect=get_child_rect(sp,child_rect,rot)

	if rot!=0:
		for dc in range(0,ProjectionDistance,ProjectionDistanceStep):
			var dc_range=(float(ProjectionDistance)/100)-(float(dc)/100)
			draw_elements.append({"func":"draw_polygon","params":[[rect["p1"].linear_interpolate(center,dc_range),rect["p2"].linear_interpolate(center,dc_range),rect["p3"].linear_interpolate(center,dc_range),rect["p4"].linear_interpolate(center,dc_range)],[],[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],sp.get_texture(),null,true]})
	else:
		for dc in range(0,ProjectionDistance,ProjectionDistanceStep):
			var dc_range=(float(ProjectionDistance)/100)-(float(dc)/100)
			draw_elements.append({"func":"draw_texture_rect","params":[sp.get_texture(),Rect2(rect["p1"].linear_interpolate(center,dc_range),rect["p3"].linear_interpolate(center,dc_range)-rect["p1"].linear_interpolate(center,dc_range)),false]})
