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

#Used to control texture repeat details on box projections Fast=single polygon for side projections
#Usado para controlar el detalle, si se repite la textura en la projeccion de "boxes" Fast=un solo polygono para los lados
export(bool) var FastRepeat=true


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

enum {SIDE_TOP,SIDE_BOTTOM,SIDE_LEFT,SIDE_RIGHT}

#List of elements within the projectable view
#Lista de elementos en el vista proyectable
var draw_elements=[]
var working_childs=[]
onready var view_center=Vector2(0,0)
onready var view_rect=Rect2()

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

#listen to scene_tree changes, adds necesary information
#escucha a cambios del scene_tree, agrega informacion adicional
func scene_tree_listener(node,action):
	var update_childs=false
	#adding a sprite node?
	#agregando un nodo tipo sprite?
	if action=="add" && (node.is_class("Sprite") || node.is_class("TileMap")):
		var parent=node.get_parent()
		#has parent
		#tiene un padre
		if parent!=null: 
			#is parent in p2d_canvas_child group?
			#el padre esta en el grupo de p2d_canvas_child
			if parent.is_in_group("p2d_canvas_child"):
				#register as a valid child, add metadada
				#registrar como hijo valido, agrega metadatos
				add_working_child(node)
				return

func tilemap_change(params,event,node):
	var tile_set=node.get_tileset()
	if event=="new":
		var pos=Vector2(params["x"],params["y"])
		var tile_id=params["tile"]
		var tile_tex=tile_set.tile_get_texture(tile_id).duplicate()
		var tile_rect=Rect2(Vector2(0,0),node.get_cell_size())
		tile_tex.set_meta("_p2d_tile_id",tile_id)
		tile_tex.set_meta("_p2d_tile_pos",pos)
		tile_tex.set_meta("_p2d_parent",node)
		tile_tex.set_meta("_p2d_position",pos*node.cell_size)
		tile_tex.set_meta("_p2d_global_position",pos*node.cell_size+node.get_global_position())
		tile_tex.set_meta("_p2d_rect",tile_rect)
		tile_tex.set_meta("_p2d_normal_map",tile_set.tile_get_normal_map(tile_id))
		tile_tex.set_meta("_p2d_modulate",tile_set.tile_get_modulate(tile_id))
		tile_tex.set_meta("_p2d_flip_h",params["flip_x"])
		tile_tex.set_meta("_p2d_flip_v",params["flip_y"])
		tile_tex.set_meta("_p2d_transposed",params["transpose"])
		tile_tex.set_meta("_p2d_scale",Vector2(1,1))
		tile_tex.set_meta("_p2d_global_scale",node.get_global_scale())
		tile_tex.set_meta("_p2d_global_rotation",node.get_global_rotation())
		tile_tex.set_meta("_p2d_visible",node.is_visible())
		tile_tex.set_meta("p2d_canvas_name",get_name())
		node.set_meta(str("p2d_child_ref_",pos.x,"_",pos.y),working_childs.size())
		working_childs.append(tile_tex)
		return
	if event=="update":
		var pos=Vector2(params["x"],params["y"])
		var tile_id=params["tile"]
		var curr_tile=working_childs[node.get_meta(str("p2d_child_ref_",pos.x,"_",pos.y))]
		var tile_tex=curr_tile
		if params["tile"]!=params["old"]:
			tile_tex=curr_tile.duplicate()
			curr_tile.free()
		#update stuff
		tile_tex.set_meta("_p2d_tile_id",tile_id)
		tile_tex.set_meta("_p2d_normal_map",tile_set.tile_get_normal_map(tile_id))
		tile_tex.set_meta("_p2d_modulate",tile_set.tile_get_modulate(tile_id))
		tile_tex.set_meta("_p2d_flip_h",params["flip_x"])
		tile_tex.set_meta("_p2d_flip_v",params["flip_y"])
		tile_tex.set_meta("_p2d_transposed",params["transpose"])
		update()
		return

#	print(event," TILE BRUH!",params["tile"]," at ",params["x"],",",params["y"])
		
	
func add_working_child(node):
	if !node.is_in_group("p2d_canvas_child"):
		node.add_to_group("p2d_canvas_child")
		node.set_meta("p2d_canvas_mode",ProjectionMode)
		node.set_meta("p2d_canvas_name",get_name())
		node.set_meta("boxes_repeat",ProjectionRepeat)
	
	if node.is_class("Sprite"):
		working_childs.append(node)
		return
	if node.is_class("TileMap"):
		var cells=node.get_used_cells()
		
		if Engine.editor_hint:
			node.set_script(load(str(self.get_script().get_path().get_base_dir(),"/p2d_tilemap_helper.gd")))
			node.connect("CELL_NEW",self,"tilemap_change",["new",node])
			node.connect("CELL_CHANGE",self,"tilemap_change",["update",node])
		
		var tile_set=node.get_tileset()
		for pos in cells:
			var tile_id=node.get_cell(pos.x,pos.y)
			var tile_tex=tile_set.tile_get_texture(tile_id).duplicate()
			var tile_rect=Rect2(Vector2(0,0),node.get_cell_size())
			tile_tex.set_meta("_p2d_tile_id",tile_id)
			tile_tex.set_meta("_p2d_tile_pos",pos)
			tile_tex.set_meta("_p2d_parent",node)
			tile_tex.set_meta("_p2d_position",pos*node.cell_size)
			tile_tex.set_meta("_p2d_global_position",pos*node.cell_size+node.get_global_position())
			tile_tex.set_meta("_p2d_rect",tile_rect)
			tile_tex.set_meta("_p2d_normal_map",tile_set.tile_get_normal_map(tile_id))
			tile_tex.set_meta("_p2d_modulate",tile_set.tile_get_modulate(tile_id))
			tile_tex.set_meta("_p2d_flip_h",node.is_cell_x_flipped ( pos.x, pos.y ))
			tile_tex.set_meta("_p2d_flip_v",node.is_cell_y_flipped ( pos.x, pos.y ))
			tile_tex.set_meta("_p2d_transposed",node.is_cell_transposed ( pos.x, pos.y ))
			tile_tex.set_meta("_p2d_scale",Vector2(1,1))
			tile_tex.set_meta("_p2d_global_scale",node.get_global_scale())
			tile_tex.set_meta("_p2d_global_rotation",node.get_global_rotation())
			tile_tex.set_meta("_p2d_visible",node.is_visible())
			tile_tex.set_meta("p2d_canvas_name",get_name())
			
			node.set_meta(str("p2d_child_ref_",pos.x,"_",pos.y),working_childs.size())

			working_childs.append(tile_tex)
	

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
		add_working_child(cc)

#update view 
#actualiza vista 
func _process(delta):
	#try to get the viewport information for projection
	#tratar de obtener informacion del viewport
	var vtrans = get_global_transform_with_canvas()
	var top_left = -vtrans.get_origin() / vtrans.get_scale()
	var vsize = get_viewport_rect().size
	var cam_pos= top_left + 0.5*vsize/vtrans.get_scale()
	var rect=Rect2(cam_pos-Vector2(vsize.x/2,vsize.y/2).abs(),cam_pos+Vector2(vsize.x/2,vsize.y/2).abs())
	
	#update view center
	#actualiza centro de vista
	view_center=Vector2(rect.end.x/2,rect.end.y/2)+VanishingPoint

	#add some buffer for partially offview sprites
	#agrega un valor para sprites parcialmente fuera de vista
	view_rect=Rect2(top_left,vsize).grow(AreaBuffer)
	
	update()

func _draw():
	#clear list
	#limpia lista
	draw_elements.clear()
		
	var final_group=""
	var in_view=[]
	
	#traverse valid child list
	#recorre lista de hijos (validos)
	for widx in range(0,working_childs.size()):
		var cc=working_childs[widx]
		#still valid?
		#aun valido? 
		if !is_valid_child(cc): 
			working_childs.remove(widx)
			#skip this cycle
			#salta este ciclo
			return
				
		#get drawing mode
		#obtener modo de dibujo
		final_group=str("mode_",ProjectionMode)
	
		#get sprite drawing mode overwrite
		#obtener modo de dibujo del sprite 
		if cc.has_meta("p2d_mode"):
			final_group=str("mode_",cc.get_meta("p2d_mode"))
		
		#calculate sprite area and other data
		#calcula area de sprite y otros datos
		var child_rect_struct=get_child_rect(cc)

		#skip, not in view, not visible, in excluded group
		#descarta, no en vista, no visible y excluidos
		if !child_rect_struct["visible"] || final_group=="mode_none":
			continue  #next 
		
		#add to visible/valid sprites to process
		#agrega a la lista de sprites validos/visibles
		in_view.append({"sprite":cc,"center":child_rect_struct["center"],"rect":child_rect_struct,"group":final_group.to_lower(),"view_center":view_center})
	
	#kinda sort stuff to avoid see-though artifacts, if you need actual pixel perfect projections with zbuffers use 3d dude WTH haha! 
	#ordena mas o menos los sprites a dibujar para evitar traslape de poligonos, etc si se necesita visibilidad pixel perfect and zbuffers utilizar 3d de verdad Vamos Hombre!
	in_view.sort_custom(self,"sort_drawables")

	#show projection lines?
	#mostrar lineas de projeccion?
	if ShowProjectionLines:
		for cc in in_view:
			draw_elements.append({"func":"draw_projection_lines","params":[[cc["rect"]["p1"],cc["rect"]["p2"],cc["rect"]["p3"],cc["rect"]["p4"]],0.5]})
	
	#call drawing functions for each sprite
	#llama funciones de dibujo para cada sprite
	for cc in in_view:
		self.call(cc["group"],cc["sprite"],cc["rect"])
	
	#is there something to draw?
	#hay algo que dibujar?
	set_meta("last_draw_calls",draw_elements.size())
	if draw_elements.size()>0:
		for d in draw_elements:
			if typeof(d["func"])==TYPE_STRING:
				callv(d["func"],d["params"])
			else:
				d["func"].call_funcv(d["params"])

#helper function to draw the projection lines... if needed
#funcion de ayuda para dibujar lineas de projeccion, si es necesario
func draw_projection_lines(points,size):
	for p in points:
		draw_primitive([
			p.linear_interpolate(view_center,float(ProjectionDistance)/100),
			view_center],
			[
				ProjectionLineColor.linear_interpolate(VPColorFade,float(ProjectionDistance)/colorDepth),
				VPColorFade
			],[],null,size)

#helper function to sort sprites
#funcion de ayuda para ordenar sprites
func sort_drawables(A,B):
	#sort based on distance to VP
	#ordena en base a distancia a PF
	return A["center"].distance_to(A["view_center"])>B["center"].distance_to(B["view_center"])

#calculate actual sprite rect
#calcula rectangulo final de sprite
func get_child_rect(child):
	
	var child_rect=get_child_property(child,"rect")
	#get sprite area
	#obtener area de sprite
	child_rect.position=get_child_property(child,"global_position",get_child_property(child,"position"))
	#fix for scale
	#corregir por escala
	
	child_rect.size=child_rect.size* get_child_property(child,"global_scale").abs()
	
	
	#correct for centered sprited
	#corregir para sprites centrados
	if get_child_property(child,"centered"):
		child_rect.position-=child_rect.size/2
	
	var rect_p1=child_rect.position
	var rect_p2=Vector2(child_rect.end.x,child_rect.position.y)
	var rect_p3=child_rect.end
	var rect_p4=Vector2(child_rect.position.x,child_rect.end.y)
	var rect_center=child_rect.position+(child_rect.size/2)
	
	var rot=get_child_property(child,"global_rotation",0)
	
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
	
	var result={
		"p1":rect_p1,
		"p2":rect_p2,
		"p3":rect_p3,
		"p4":rect_p4,
		"rot":rot,
		"center":rect_center
	}
		
	var child_top=Vector2(
		[rect_p1.x,rect_p2.x,rect_p3.x,rect_p4.x].min(),
		[rect_p1.y,rect_p2.y,rect_p3.y,rect_p4.y].min()
		)
	var child_bottom=Vector2(
		[rect_p1.x,rect_p2.x,rect_p3.x,rect_p4.x].max(),
		[rect_p1.y,rect_p2.y,rect_p3.y,rect_p4.y].max()
		)
		
	#calculate mins, maxs, used to check if its viewable area
	#calcular minimos y maximos, usado para ver si esta dentro de la vista
	for i in range(1,4):
		child_top.x=min(child_top.x,result[str("p",i)].linear_interpolate(view_center,float(ProjectionDistance)/100).x)
		child_top.y=min(child_top.y,result[str("p",i)].linear_interpolate(view_center,float(ProjectionDistance)/100).y)
		child_bottom.x=max(child_bottom.x,result[str("p",i)].linear_interpolate(view_center,float(ProjectionDistance)/100).x)
		child_bottom.y=max(child_bottom.y,result[str("p",i)].linear_interpolate(view_center,float(ProjectionDistance)/100).y)
	
	var child_rect_view=Rect2(child_top,child_bottom-child_top)
	
	result['visible']=view_rect.intersects(child_rect_view)!=false && get_child_property(child,"visible")
	
	return result

#box drawing function used for "boxes" projection mode
#dibujado de "cajas", usado para projeccion "boxes"
func mode_boxes(sp,rect):
	#what to draw list
	#lista de elementos a dibujar
	var to_draw={}
	
	#Setup polygons points
	#Configura puntos de los poligonos 
	var rec_p1=rect["p1"]
	var rec_p2=rect["p2"]
	var rec_p3=rect["p3"]
	var rec_p4=rect["p4"]
	
	#default max uv value
	#maximo uv por defecto
	var tex_uv_w=1
	var num_projections=1
	
	#texture list, default all thh same [top,bottom,left,right]
	#listado de textureas, por defecto la misma en todas las caras [arriba,abajo,izquierda,derecha]
	var textures={}
	var normal_maps={}
	
	var side_textures=get_child_texture(sp)
	var side_normal_map=get_child_texture(sp,"normal_map")
	
	#setup colors
	#configura colores
	var col_start=get_child_property(sp,"modulate")
	var col_end=col_start.linear_interpolate(VPColorFade,float(ProjectionDistance)/colorDepth)
	
	#calculate projected points
	#calcular puntos de proyectados 
	var proj_p1=rec_p1.linear_interpolate(view_center,float(ProjectionDistance)/100)
	var proj_p2=rec_p2.linear_interpolate(view_center,float(ProjectionDistance)/100)
	var proj_p3=rec_p3.linear_interpolate(view_center,float(ProjectionDistance)/100)
	var proj_p4=rec_p4.linear_interpolate(view_center,float(ProjectionDistance)/100)
		
	#decide what to draw, only faces facing the VP
	#decidir que dibujar, solo caras mirando el PF
	if (rect["p1"]-rect["p2"]).cross(view_center-rect["p1"])>0 && get_child_property(sp,"boxes_side_top",true):
		to_draw["TOP"]=[]
	if (rect["p2"]-rect["p3"]).cross(view_center-rect["p2"])>0 && get_child_property(sp,"boxes_side_right",true):
		to_draw["RIGHT"]=[]
	if (rect["p3"]-rect["p4"]).cross(view_center-rect["p3"])>0 && get_child_property(sp,"boxes_side_bottom",true):
		to_draw["BOTTOM"]=[]
	if (rect["p4"]-rect["p1"]).cross(view_center-rect["p4"])>0 && get_child_property(sp,"boxes_side_left",true):
		to_draw["LEFT"]=[]

	##set textures
	##configura texturas
	for side in to_draw:
		textures[side]=get_child_property(sp,str("boxes_texture_",side.to_lower()),side_textures)
		normal_maps[side]=side_normal_map
		
	#box repeat
	#repetir caja
	if get_child_property(sp,"boxes_repeat",ProjectionRepeat):
		num_projections=float(ProjectionDistance-get_child_property(sp,"p2d_start_projection",0))/float(ProjectionRepeatDivider)
		if FastRepeat:
			tex_uv_w=num_projections
		for ti in textures:
			if !textures[ti].get_flags()&Texture.FLAG_REPEAT:
				textures[ti].set_flags(textures[ti].get_flags()|Texture.FLAG_REPEAT)
			if normal_maps[ti]!=null && !normal_maps[ti].get_flags()&Texture.FLAG_REPEAT:
				normal_maps[ti].set_flags(normal_maps[ti].get_flags()|Texture.FLAG_REPEAT)

	#UVs [top,bottom,left,right]
	#UVs [arriba,abajo,izquierda,derecha]
	var uvs={}
	if to_draw.has("TOP"):
		uvs["TOP"]=[Vector2(0,1),Vector2(1,1),Vector2(1,1-tex_uv_w),Vector2(0,1-tex_uv_w)]
	if to_draw.has("BOTTOM"):
		uvs["BOTTOM"]=[Vector2(0,0),Vector2(1,0),Vector2(1,tex_uv_w),Vector2(0,tex_uv_w)]
	if to_draw.has("LEFT"):
		uvs["LEFT"]=[Vector2(1,0),Vector2(1,1),Vector2(1-tex_uv_w,1),Vector2(1-tex_uv_w,0)]
	if to_draw.has("RIGHT"):
		uvs["RIGHT"]=[Vector2(0,1),Vector2(0,0),Vector2(tex_uv_w,0),Vector2(tex_uv_w,1)]

	#start projection overwrite?, change initial points
	#principio de projeccion fue cambiado, cambia poligonos iniciales
	if get_child_property(sp,"p2d_start_projection",0)>0:
		var child_proj=float(get_child_property(sp,"p2d_start_projection"))
		col_start=col_start.linear_interpolate(VPColorFade,child_proj/colorDepth)
		rec_p1=rec_p1.linear_interpolate(view_center,child_proj/100)
		rec_p2=rec_p2.linear_interpolate(view_center,child_proj/100)
		rec_p3=rec_p3.linear_interpolate(view_center,child_proj/100)
		rec_p4=rec_p4.linear_interpolate(view_center,child_proj/100)

	if (!sp.is_class("Sprite") && (
			get_child_property(sp,"flip_h") ||  
			get_child_property(sp,"flip_v") || 
			get_child_property(sp,"transposed")
			)
		):
		var uv_fix=Vector2(1,1)
		if get_child_property(sp,"flip_h"):
			uv_fix.x=-1
		if get_child_property(sp,"flip_v"):
			uv_fix.y=-1
		for side in uvs:
			for uv_coord in range(0,uvs[side].size()):
				uvs[side][uv_coord]*=uv_fix
				if get_child_property(sp,"transposed"):
					var tm=uvs[side][uv_coord].x
					uvs[side][uv_coord].x=uvs[side][uv_coord].y
					uvs[side][uv_coord].y=tm
	
	if FastRepeat || !get_child_property(sp,"boxes_repeat",ProjectionRepeat):
		#if !sp.is_class("Sprite"):
		#	print(sp.get_class()," brepeat=",get_child_property(sp,"boxes_repeat",ProjectionRepeat))
		#top/arriba
		if to_draw.has("TOP"):
			to_draw["TOP"].append([
				[rec_p1,rec_p2,proj_p2,proj_p1],
				[col_start,col_start,col_end,col_end],
				uvs["TOP"],textures["TOP"],normal_maps["TOP"]]
			)
		
		#bottom/abajo
		if to_draw.has("BOTTOM"):
			to_draw["BOTTOM"].append([
				[rec_p4,rec_p3,proj_p3,proj_p4],
				[col_start,col_start,col_end,col_end],
				uvs["BOTTOM"],textures["BOTTOM"],normal_maps["BOTTOM"]]
			)
	
		#left/izquierda
		if to_draw.has("LEFT"):
			to_draw["LEFT"].append([
				[rec_p1,rec_p4,proj_p4,proj_p1],
				[col_start,col_start,col_end,col_end],
				uvs["LEFT"],textures["LEFT"],normal_maps["LEFT"]]
			)
		
		#right/derecha
		if to_draw.has("RIGHT"):
			to_draw["RIGHT"].append([
				[rec_p3,rec_p2,proj_p2,proj_p3],
				[col_start,col_start,col_end,col_end],
				uvs["RIGHT"],textures["RIGHT"],normal_maps["RIGHT"]]
			)
	else:
		#detailed drawing... generate more quads
		for rep in range(0,ceil(num_projections)):
			var pro_start=float(get_child_property(sp,"p2d_start_projection",0))
			var child_proj1=float(rep*ProjectionRepeatDivider)
			var child_proj2=float((rep+1)*ProjectionRepeatDivider)
			
			var new_cols=[
						col_start.linear_interpolate(VPColorFade,(child_proj1+pro_start)/colorDepth),
						col_start.linear_interpolate(VPColorFade,(child_proj1+pro_start)/colorDepth),
						col_start.linear_interpolate(VPColorFade,(child_proj2+pro_start)/colorDepth),
						col_start.linear_interpolate(VPColorFade,(child_proj2+pro_start)/colorDepth)
					]
			if to_draw.has("TOP"):
				to_draw["TOP"].append([
					[
						rec_p1.linear_interpolate(view_center,child_proj1/100),
						rec_p2.linear_interpolate(view_center,child_proj1/100),
						rec_p2.linear_interpolate(view_center,child_proj2/100),
						rec_p1.linear_interpolate(view_center,child_proj2/100)
					],
					new_cols,
					uvs["TOP"],
					textures["TOP"],normal_maps["TOP"]]
				)
			#bottom/abajo
			if to_draw.has("BOTTOM"):
				to_draw["BOTTOM"].append([
					[
						rec_p4.linear_interpolate(view_center,child_proj1/100),
						rec_p3.linear_interpolate(view_center,child_proj1/100),
						rec_p3.linear_interpolate(view_center,child_proj2/100),
						rec_p4.linear_interpolate(view_center,child_proj2/100)
						],
					new_cols,
					uvs["BOTTOM"],
					textures["BOTTOM"],normal_maps["BOTTOM"]]
				)
	
			#left/izquierda
			if to_draw.has("LEFT"):
				to_draw["LEFT"].append([
					[
						rec_p1.linear_interpolate(view_center,child_proj1/100),
						rec_p4.linear_interpolate(view_center,child_proj1/100),
						rec_p4.linear_interpolate(view_center,child_proj2/100),
						rec_p1.linear_interpolate(view_center,child_proj2/100)
						],
					new_cols,
					uvs["LEFT"],
					textures["LEFT"],normal_maps["LEFT"]]
				)
		
			#right/derecha
			if to_draw.has("RIGHT"):
				to_draw["RIGHT"].append([
					[
						rec_p3.linear_interpolate(view_center,child_proj1/100),
						rec_p2.linear_interpolate(view_center,child_proj1/100),
						rec_p2.linear_interpolate(view_center,child_proj2/100),
						rec_p3.linear_interpolate(view_center,child_proj2/100)
					],
					new_cols,
					uvs["RIGHT"],
					textures["RIGHT"],normal_maps["RIGHT"]]
				)
		
	#start projection overwrite?, add front sprite
	#principio de projeccion fue cambiado, agrega sprite frontal
	if get_child_property(sp,"p2d_start_projection",0)>0:#add cap 		
		to_draw["FRONT"]=[]
		to_draw["FRONT"].append([
				[rec_p1,rec_p2,rec_p3,rec_p4],
				[col_start,col_start,col_start,col_start],
				[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],
				side_textures,
				side_normal_map
			]
		)
		if Engine.editor_hint:#draw helper on original sprite location
			to_draw["FRONT"].append([
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"]],
				[Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3)],
				[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],
				side_textures,
				null
				]
			)
	
	#register draw calls
	#registra llamados de dibujo
	for face in to_draw:
		for elem in to_draw[face]:
			draw_elements.append({"func":"draw_polygon","params":elem})
	
	#editor mode?, register visual aid
	#modo edicion, registra ayuda visual
	if get_child_property(sp,"p2d_start_projection",0)>0 && Engine.editor_hint:
		draw_elements.append({"func":"draw_polyline","params":[
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"],rect["p1"]],Color(1,1,0,1),1]})

#clone (copy) projection
#projeccion de clon (copia)
func mode_clone(sp,rect):
	var child_proj=get_child_property(sp,"p2d_start_projection",0)
	#apply rotation if any, use draw_polygon
	#aplica rotacion si hay, usa draw_polygon
	if rect["rot"]!=0:
		for dc in range(0,ProjectionDistance-child_proj,ProjectionDistanceStep):
			var dc_range=(float(ProjectionDistance)/100)-(float(dc)/100)
			var dcol_range=(float(ProjectionDistance)/colorDepth)-(float(dc)/colorDepth)
			#register draw calls
			#registra llamados de dibujo
			draw_elements.append({"func":"draw_polygon","params":[
				[
					rect["p1"].linear_interpolate(view_center,dc_range),
					rect["p2"].linear_interpolate(view_center,dc_range),
					rect["p3"].linear_interpolate(view_center,dc_range),
					rect["p4"].linear_interpolate(view_center,dc_range)
				],[sp.modulate.linear_interpolate(VPColorFade,dcol_range),sp.modulate.linear_interpolate(VPColorFade,dcol_range),sp.modulate.linear_interpolate(VPColorFade,dcol_range),sp.modulate.linear_interpolate(VPColorFade,dcol_range)],
				[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],
				get_child_texture(sp),
				get_child_texture(sp,"normal_map"),false
				]})
		#editor mode?, register visual aid
		#modo edicion, registra ayuda visual
		if child_proj>0 && Engine.editor_hint:
			draw_elements.append({"func":"draw_polygon","params":[
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"]],
				[Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3),Color(1,1,1,0.3)],
				[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],
				get_child_texture(sp),
				null,false
				]})
	#no rotation, use draw_texture_rect
	#no hay rotacion, usa draw_texture_rect
	else:
		for dc in range(0,ProjectionDistance-child_proj,ProjectionDistanceStep):
			var dc_range=(float(ProjectionDistance)/100)-(float(dc)/100)
			var dcol_range=(float(ProjectionDistance)/colorDepth)-(float(dc)/colorDepth)
			#register draw calls
			#registra llamados de dibujo
			draw_elements.append({"func":"draw_texture_rect","params":[
				get_child_texture(sp),Rect2(
					rect["p1"].linear_interpolate(view_center,dc_range),
					rect["p3"].linear_interpolate(view_center,dc_range)-rect["p1"].linear_interpolate(view_center,dc_range)
				),false,sp.modulate.linear_interpolate(VPColorFade,dcol_range),false,get_child_texture(sp,"normal_map")]})
		#editor mode?, register visual aid
		#modo edicion, registra ayuda visual
		if child_proj>0 && Engine.editor_hint:
			draw_elements.append({"func":"draw_texture_rect","params":[
				get_child_texture(sp),Rect2(rect["p1"],rect["p3"]-rect["p1"]),false,Color(1,1,1,0.3),false,null]})
			draw_elements.append({"func":"draw_polyline","params":[
				[rect["p1"],rect["p2"],rect["p3"],rect["p4"],rect["p1"]],Color(1,1,0),1]})

###########################################################
##### multinode compatibility functions
func is_valid_child(child):
	if !child:
		return false
	var qtarget=child
	if child.is_class("Texture"):
		qtarget=child.get_meta("_p2d_parent")
		var used=qtarget.get_used_cells()
		var valid=used.has(child.get_meta("_p2d_tile_pos"))
		if !valid:
			var pos=child.get_meta("_p2d_tile_pos")
			qtarget.set_meta(str("p2d_child_ref_",pos.x,"_",pos.y),null)
		return valid
				
	if !qtarget.is_inside_tree():
		#deleted child
		#hijo fue borrado
		return false
	
	#moved outside of p2dnode
	#movido fuera del nodo p2dnode
	if !qtarget.get_parent().is_in_group("p2d_canvas_child"):
		qtarget.remove_from_group("p2d_canvas_child")
		qtarget.set_meta("p2d_canvas_mode",null)
		qtarget.set_meta("p2d_canvas_name",null)
		qtarget.set_meta("boxes_repeat",null)
		return false
	
	return true
	
func get_child_texture(child,type="texture"):
	if child.is_class("Sprite"):
		var method=str("get_",type)
		if child.has_method(method):
			return child.call(method)
	if child.is_class("Texture"):
		if type=="texture":
			return child
		else:
			return child.get_meta(str("_p2d_",type))
	return null

func get_child_property(child,property,default=null):
	if child.has_method(str("get_",property)):
		return child.call(str("get_",property))
	if child.has_meta(str("_p2d_",property)):
		return child.__meta__.get(str("_p2d_",property),default)
	#if nothing specific try genral stuff
	var res=child.get(property)
	if res==null:
		res=child.__meta__.get(property,default)
	return res
	
func set_child_property(child,property,value):
	return child.set_meta(property,value)

func get_child_path(child):
	if child.is_class("Sprite"):
		return child.get_path()
	var target=child.get_meta("_p2d_parent")
	if !target:
		push_error(str("Invalid child setup ",child))
	
	return target.get_path()
