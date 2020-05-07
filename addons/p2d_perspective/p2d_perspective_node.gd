tool

extends CanvasItem

#Vanishing Point (VP), relative to camera/view center
#Punto de Fuga (PF), relavito al centro de la camara/view 
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

#Used to control texture repeat on box projections
#Usado para controlar si se repite la textura en la projeccion de "boxes"
export(bool) var ProjectionRepeat=true

#Essentialy if ProjectionRepeat=true then ProjectionDistancce/ProjectionRepeatDivider=Number of time Texture sill repeat
#Esencialmente si ProjectionRepeat=true entonces ProjectionDistancce/ProjectionRepeatDivider=Numero de veces se repite la textura
export(int) var ProjectionRepeatDivider=10

#self explanatory
export(Color) var ProjectionLineColor=Color(0,1,0,0.5)

export(bool) var ShowProjectionLines=false

#Amount to grow viewable area to detect if we draw something or not
export(int) var AreaBuffer=50

export(Color) var VPColorFade=Color(1,1,1,1)
export(int) var colorDepth=50

#List of elements within the projectable view
#Lista de elementos en el vista proyectable
var draw_elements=[]
var working_childs=[]

#propagate changes to projection mode
#propaga cambios a modo de proyeccion
func setProjectionMode(mode):
	ProjectionMode=mode
	propagate_call("set_meta",["p2d_canvas_mode",ProjectionMode])

func _ready():
	#register metadata in child nodes
	#registra metadatos en hijos
	propagate_call("add_to_group",["p2d_canvas_child"])
	propagate_call("set_meta",["p2d_canvas_mode",ProjectionMode])
	propagate_call("set_meta",["p2d_canvas_name",get_path()])
	
	#initialize working childs list
	#inicializa lista de hijos valida
	find_working_childs()
	
	#register signal listener
	#registra "escuchador" de señal
	get_tree().connect("node_added",self,"scene_tree_listener",["add"])

#update view 
#actualiza vista 
func _process(delta):
	#@TODO
	#I think this could be changed.. idk, 
	#probably signals to update only when relevant changes occur
	#Creo que esto se puede cambiar.. no se
	#probablemente una señal cuando cambios relevantes pasan
	update()

#listen to scene_tree changes, adds necesary information
#escucha a cambios del scene_tree, agrega informacion adicional
func scene_tree_listener(node,action):
	var update_childs=false
	#adding a sprite node?
	#agregando un nodo tipo sprite?
	if action=="add" && node.is_class("Sprite"):
		var parent=node.get_parent()
		#has parent
		#tiene un padre
		if parent!=null: 
			#is parent in p2d_canvas_child group?
			#el padre esta en el grupo de p2d_canvas_child
			if parent.is_in_group("p2d_canvas_child"):
				#register as a valid child, add metadada
				#registrar como hijo valido, agrega metadatos
				node.add_to_group("p2d_canvas_child")
				node.set_meta("p2d_canvas_mode",ProjectionMode)
				node.set_meta("p2d_canvas_name",get_name())
				node.set_meta("boxes_repeat",ProjectionRepeat)
				working_childs.append(node)

#find valid childs
#encuentra hijos validos
func find_working_childs():
	working_childs.clear()
	#play nice with deinitialization routines
	#toma en cuenta rutinas de deinicializacion
	if get_tree()==null: 
		return
	#get child list
	#obtiene lista de hijos
	for cc in get_tree().get_nodes_in_group("p2d_canvas_child"):
		if cc.is_class("Sprite"):
			working_childs.append(cc)

func _draw():
	#clear list
	#limpia lista
	draw_elements.clear()
	
	#try to get the viewport information for projection
	#tratar de obtener informacion del viewport
	var vtrans = get_global_transform_with_canvas()
	var top_left = -vtrans.get_origin() / vtrans.get_scale()
	var vsize = get_viewport_rect().size
	var cam_pos= top_left + 0.5*vsize/vtrans.get_scale()
	var crect=get_viewport_rect()
	var rect=Rect2(cam_pos-Vector2(vsize.x/2,vsize.y/2).abs(),cam_pos+Vector2(vsize.x/2,vsize.y/2).abs())
	var center=Vector2(rect.end.x/2,rect.end.y/2)+VanishingPoint

	#add some buffer for partially offview sprites
	#agrega un valor para sprites parcialmente fuera de vista
	crect=Rect2(top_left,vsize).grow(AreaBuffer)

	var final_group=""
	var in_view=[]
	
	#traverse valid child list
	#recorre lista de hijos (validos)
	for widx in range(0,working_childs.size()):
		var cc=working_childs[widx]
		#still valid?
		#aun valido? 
		if cc!=null: 
			if !cc.is_inside_tree():
				#deleted child, remove from working group 
				#hijo fue borrado, remover de hijos validos
				working_childs.remove(widx)
				return
		else:
			#invalid child, remove from working group 
			#hijo invalido, remover de hijos validos
			working_childs.remove(widx)
			return
				
		#get sprite area
		#obtener area de sprite
		var child_rect=cc.get_rect()
		child_rect.position=cc.position
		#fix for scale
		#corregir por escala
		child_rect.size=child_rect.size*cc.scale
		
		#correct for centered sprited
		#corregir para sprites centrados
		if cc.is_centered():
			child_rect.position-=child_rect.size/2
		
		#get drawing mode
		#obtener modo de dibujo
		final_group=str("mode_",ProjectionMode)
	
		#get sprite drawing mode overwrite
		#obtener modo de dibujo del sprite 
		if cc.has_meta("p2d_mode"):
			final_group=str("mode_",cc.get_meta("p2d_mode"))
		
		#calculate sprite area and other data
		#calcula area de sprite y otros datos
		var child_rect_struct=get_child_rect(cc,child_rect,cc.get_rotation(),center)
		var child_top=Vector2(child_rect_struct["min_x"],child_rect_struct["min_y"])
		var child_bottom=Vector2(child_rect_struct["max_x"],child_rect_struct["max_y"])
		var child_rect_view=Rect2(child_top,child_bottom-child_top)

		#skip, not in view, not visible, in excluded group
		#descarta, no en vista, no visible y excluidos
		if crect.intersects(child_rect_view)==false || !cc.is_visible() || final_group=="mode_none":
			continue  #next 
		
		#add to visible/valid sprites to process
		#agrega a la lista de sprites validos/visibles
		in_view.append({"sprite":cc,"center":child_rect_struct["center"],"rect":child_rect_struct,"group":final_group.to_lower(),"view_center":center})
	
	#kinda sort stuff to avoid see-though artifacts, if you need actual pixel perfect projections with zbuffers use 3d dude WTH haha! 
	#ordena mas o menos los sprites a dibujar para evitar traslape de poligonos, etc si se necesita visibilidad pixel perfect and zbuffers utilizar 3d de verdad Vamos Hombre!
	in_view.sort_custom(self,"sort_drawables")

	#show projection lines?
	#mostrar lineas de projeccion?
	if ShowProjectionLines:
		for cc in in_view:
			draw_elements.append({"func":"draw_projection_lines","params":[[cc["rect"]["p1"],cc["rect"]["p2"],cc["rect"]["p3"],cc["rect"]["p4"]],center,0.5]})
	
	#call drawing functions for each sprite
	#llama funciones de dibujo para cada sprite
	for cc in in_view:
		self.call(cc["group"],cc["sprite"],cc["rect"],center)
	
	#is there something to draw?
	#hay algo que dibujar?
	if draw_elements.size()>0:
		for d in draw_elements:
			callv(d["func"],d["params"])


#helper function to draw the projection lines... if needed
#funcion de ayuda para dibujar lineas de projeccion, si es necesario
func draw_projection_lines(points,center,size):
	for p in points:
		draw_primitive([p.linear_interpolate(center,float(ProjectionDistance)/100),Vector2(center.x,center.y)],[ProjectionLineColor.linear_interpolate(VPColorFade,float(ProjectionDistance)/colorDepth),VPColorFade],[],null,size)

#helper function to sort sprites
#funcion de ayuda para ordenar sprites
func sort_drawables(A,B):
	#sort based on distance to VP
	#ordena en base a distancia a PF
	if A["center"].distance_to(A["view_center"])>B["center"].distance_to(B["view_center"]):
		return true
	return false

#calculate actual sprite rect
#calcula rectangulo final de sprite
func get_child_rect(child,child_rect,rot,center):
	var rect_p1=child_rect.position
	var rect_p2=Vector2(child_rect.end.x,child_rect.position.y)
	var rect_p3=child_rect.end
	var rect_p4=Vector2(child_rect.position.x,child_rect.end.y)
	var rect_center=child_rect.position+(child_rect.size/2)
	
	#rotation, apply it
	#hay rotacion, aplicarla
	if rot!=0: 
		var transform=Transform2D(rot,get_transform().get_origin()+rect_center)
		var center_diff=rect_center
		rect_center=transform.xform(rect_center)
		center_diff=center_diff-rect_center
		rect_p1=transform.xform(rect_p1)+center_diff
		rect_p2=transform.xform(rect_p2)+center_diff
		rect_p3=transform.xform(rect_p3)+center_diff
		rect_p4=transform.xform(rect_p4)+center_diff
		rect_center+=center_diff
		
	
	#apply parent transforms too if any
	#applicar transformaciones de padre si tiene
	var relative_path=NodePath(str(child.get_path()).replace(child.get_meta("p2d_canvas_name"),""))	
	if relative_path.get_name_count()>1:
		var curr_parent=child.get_meta("p2d_canvas_name")
		var parent_offset=Vector2(0,0)
		for p in range(0,relative_path.get_name_count()-1):
			curr_parent=str(curr_parent,"/",relative_path.get_name(p))
			var parent=get_node_or_null(curr_parent)
			if parent!=null:
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
	
	#calculate mins, maxs, used to check if its viewable area
	#calcular minimos y maximos, usado para ver si esta dentro de la vista
	for i in range(1,4):
		result["min_x"]=min(result["min_x"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).x)
		result["min_y"]=min(result["min_y"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).y)
		result["max_x"]=max(result["max_x"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).x)
		result["max_y"]=max(result["max_y"],result[str("p",i)].linear_interpolate(center,float(ProjectionDistance)/100).y)
		
	return result

#box drawing function used for "boxes" projection mode
#dibujado de "cajas", usado para projeccion "boxes"
func mode_boxes(sp,rect,center):
	#polyton list
	#lista de poligonos
	var pols=[]
	
	#what to draw list
	#lista de elementos a dibujar
	var to_draw=[]

	#decide what to draw, only faces facing the VP
	#decidir que dibujar, solo caras mirando el PF
	if (rect["p1"]-rect["p2"]).cross(center-rect["p1"])>0 && sp.__meta__.get("boxes_side_top",true):
		to_draw.append(0)
	if (rect["p2"]-rect["p3"]).cross(center-rect["p2"])>0 && sp.__meta__.get("boxes_side_right",true) :
		to_draw.append(3)
	if (rect["p3"]-rect["p4"]).cross(center-rect["p3"])>0 && sp.__meta__.get("boxes_side_bottom",true):
		to_draw.append(1)
	if (rect["p4"]-rect["p1"]).cross(center-rect["p4"])>0 && sp.__meta__.get("boxes_side_left",true) :
		to_draw.append(2)
	
	#calculate projected points
	#calcular puntos de proyectados 
	var proj_p1=rect["p1"].linear_interpolate(center,float(ProjectionDistance)/100)
	var proj_p2=rect["p2"].linear_interpolate(center,float(ProjectionDistance)/100)
	var proj_p3=rect["p3"].linear_interpolate(center,float(ProjectionDistance)/100)
	var proj_p4=rect["p4"].linear_interpolate(center,float(ProjectionDistance)/100)
	var side_textures=sp.__meta__.get("side_texture",sp.get_texture().duplicate())
	sp.set_meta("side_texture",side_textures)
	
	#default max uv value
	#maximo uv por defecto
	var tex_uv_w=1
	
	#texture list, default all thh same [top,bottom,left,right]
	#listado de textureas, por defecto la misma en todas las caras [arriba,abajo,izquierda,derecha]
	var textures=[side_textures,side_textures,side_textures,side_textures]
	
	########################
	##check sprite level changes
	##verifica cambios de por sprite
	
	##top texture
	##textura de arriba
	if sp.has_meta("boxes_texture_top"):  
		textures[0]=sp.get_meta("boxes_texture_top")
	
	##bottom texture
	##textura de abajo	
	if sp.has_meta("boxes_texture_bottom"): 
		textures[1]=sp.get_meta("boxes_texture_bottom")
	
	#box repeat
	#repetir caja
	if sp.__meta__.get("boxes_repeat",ProjectionRepeat): 
		##See ProjectionRepeatDivider comments
		##Ver comencatios de ProjectionRepeatDivider
		tex_uv_w=(ProjectionDistance-sp.__meta__.get("p2d_start_projection",0))/ProjectionRepeatDivider
		for ti in range(0,textures.size()):
			if !textures[ti].get_flags()&Texture.FLAG_REPEAT:
				textures[ti].set_flags(textures[ti].get_flags()|Texture.FLAG_REPEAT)
	################
	
	#UVs [top,bottom,left,right]
	#UVs [arriba,abajo,izquierda,derecha]
	var uvs=[
		[Vector2(0,0),Vector2(1,0),Vector2(1,tex_uv_w),Vector2(0,tex_uv_w)],#top
		[Vector2(0,0),Vector2(1,0),Vector2(1,tex_uv_w),Vector2(0,tex_uv_w)],#bottom
		[Vector2(0,0),Vector2(tex_uv_w,0),Vector2(tex_uv_w,1),Vector2(0,1)],#left
		[Vector2(0,0),Vector2(tex_uv_w,0),Vector2(tex_uv_w,1),Vector2(0,1)] #right
	]
		
	#Setup polygons points
	#Configura puntos de los poligonos 
	var rec_p1=rect["p1"]
	var rec_p2=rect["p2"]
	var rec_p3=rect["p3"]
	var rec_p4=rect["p4"]
	var col_start=sp.modulate
	
	
	#start projection overwrite?, change initial points
	#principio de projeccion fue cambiado, cambia poligonos iniciales
	if sp.__meta__.get("p2d_start_projection",0)>0:
		col_start=col_start.linear_interpolate(VPColorFade,float(sp.get_meta("p2d_start_projection"))/colorDepth)
		rec_p1=rec_p1.linear_interpolate(center,float(sp.get_meta("p2d_start_projection"))/100)
		rec_p2=rec_p2.linear_interpolate(center,float(sp.get_meta("p2d_start_projection"))/100)
		rec_p3=rec_p3.linear_interpolate(center,float(sp.get_meta("p2d_start_projection"))/100)
		rec_p4=rec_p4.linear_interpolate(center,float(sp.get_meta("p2d_start_projection"))/100)
	
	#top/arriba
	pols.append([proj_p1,proj_p2,rec_p2,rec_p1])
	#bottom/abajo
	pols.append([rec_p4,rec_p3,proj_p3,proj_p4])
	#left/izquierda
	pols.append([proj_p1,rec_p1,rec_p4,proj_p4])
	#right/derecha
	pols.append([rec_p2,proj_p2,proj_p3,rec_p3])
		
	
	#setup colors
	#configura colores
	var cols=[]
	var col_end=col_start.linear_interpolate(VPColorFade,float(ProjectionDistance)/colorDepth)
	
	cols.append([col_end,col_end,col_start,col_start])
	cols.append([col_start,col_start,col_end,col_end])
	cols.append([col_end,col_start,col_start,col_end])
	cols.append([col_start,col_end,col_end,col_start])
	
	#start projection overwrite?, add front sprite
	#principio de projeccion fue cambiado, agrega sprite frontal
	if sp.__meta__.get("p2d_start_projection",0)>0:#add cap 
		pols.append([rec_p1,rec_p2,rec_p3,rec_p4])
		uvs.append([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		cols.append([col_start,col_start,col_start,col_start])
		textures.append(sp.get_texture())
		to_draw.append(4)
		if Engine.editor_hint:#draw helper on original sprite location
			pols.append([rect["p1"],rect["p2"],rect["p3"],rect["p4"]])
			cols.append([Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3)])
			uvs.append(uvs[4])
			textures.append(sp.get_texture())
			to_draw.append(5)
	
	#register draw calls
	#registra llamados de dibujo
	for p in to_draw:
		draw_elements.append({"func":"draw_polygon","params":[pols[p],cols[p],uvs[p],textures[p],sp.get_normal_map(),false]})
	
	#editor mode?, register visual aid
	#modo edicion, registra ayuda visual
	if sp.__meta__.get("p2d_start_projection",0)>0 && Engine.editor_hint:
		draw_elements.append({"func":"draw_polyline","params":[
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"],rect["p1"]],Color(1,1,0),1]})

#clone (copy) projection
#projeccion de clon (copia)
func mode_clone(sp,rect,center):
	var rot=sp.get_rotation()
	#apply rotation if any, use draw_polygon
	#aplica rotacion si hay, usa draw_polygon
	if rot!=0:
		for dc in range(0,ProjectionDistance-sp.__meta__.get("p2d_start_projection",0),ProjectionDistanceStep):
			var dc_range=(float(ProjectionDistance)/100)-(float(dc)/100)
			var dcol_range=(float(ProjectionDistance)/colorDepth)-(float(dc)/colorDepth)
			#register draw calls
			#registra llamados de dibujo
			draw_elements.append({"func":"draw_polygon","params":[
				[rect["p1"].linear_interpolate(center,dc_range),rect["p2"].linear_interpolate(center,dc_range),rect["p3"].linear_interpolate(center,dc_range),rect["p4"].linear_interpolate(center,dc_range)],
				[sp.modulate.linear_interpolate(VPColorFade,dcol_range),sp.modulate.linear_interpolate(VPColorFade,dcol_range),sp.modulate.linear_interpolate(VPColorFade,dcol_range),sp.modulate.linear_interpolate(VPColorFade,dcol_range)],
				[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],
				sp.get_texture(),
				sp.get_normal_map(),false
				]})
		#editor mode?, register visual aid
		#modo edicion, registra ayuda visual
		if sp.__meta__.get("p2d_start_projection",0)>0 && Engine.editor_hint:
			draw_elements.append({"func":"draw_polygon","params":[
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"]],
				[Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3)],
				[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],
				sp.get_texture(),
				null,false
				]})
	#no rotation, use draw_texture_rect
	#no hay rotacion, usa draw_texture_rect
	else:
		for dc in range(0,ProjectionDistance-sp.__meta__.get("p2d_start_projection",0),ProjectionDistanceStep):
			var dc_range=(float(ProjectionDistance)/100)-(float(dc)/100)
			var dcol_range=(float(ProjectionDistance)/colorDepth)-(float(dc)/colorDepth)
			#register draw calls
			#registra llamados de dibujo
			draw_elements.append({"func":"draw_texture_rect","params":[sp.get_texture(),Rect2(rect["p1"].linear_interpolate(center,dc_range),rect["p3"].linear_interpolate(center,dc_range)-rect["p1"].linear_interpolate(center,dc_range)),false,sp.modulate.linear_interpolate(VPColorFade,dcol_range),false,sp.get_normal_map()]})
		#editor mode?, register visual aid
		#modo edicion, registra ayuda visual
		if sp.__meta__.get("p2d_start_projection",0)>0 && Engine.editor_hint:
			draw_elements.append({"func":"draw_texture_rect","params":[
				sp.get_texture(),Rect2(rect["p1"],rect["p3"]-rect["p1"]),false,Color(1,1,1,0.3),false,null]})
			draw_elements.append({"func":"draw_polyline","params":[
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"],rect["p1"]],Color(1,1,0),1]})

