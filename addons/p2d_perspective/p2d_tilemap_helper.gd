tool
extends TileMap

signal CELL_NEW
signal CELL_CHANGE
signal CELL_DELETE

func set_cell (  x,  y,  tile,  flip_x=false,  flip_y=false,  transpose=false,  autotile_coord=Vector2( 0, 0 ) ):
	var curr_tile=get_cell(x,y)
	
	if curr_tile!=INVALID_CELL && tile!=INVALID_CELL:
		var changed=tile!=curr_tile
		if  ( tile==curr_tile && (
				flip_x!=is_cell_x_flipped(x,y) 	|| 
				flip_y!=is_cell_y_flipped(x,y) ||
				transpose!=is_cell_transposed(x,y) ||
				autotile_coord!=get_cell_autotile_coord(x,y)
				)
			):
				changed=true
		if changed:
			emit_signal("CELL_CHANGE",{"old":curr_tile,"tile":tile,"x":x,"y":y,"flip_x":flip_x,"flip_y":flip_y,"transpose":transpose,"auto":autotile_coord})
		
	if curr_tile==INVALID_CELL && tile!=INVALID_CELL:
		emit_signal("CELL_NEW",{"tile":tile,"x":x,"y":y,"flip_x":flip_x,"flip_y":flip_y,"transpose":transpose,"auto":autotile_coord})
	if curr_tile!=INVALID_CELL && tile==INVALID_CELL:
		emit_signal("CELL_DELETE",{"tile":curr_tile,"x":x,"y":y})
		
	.set_cell(  x,  y,  tile,  flip_x,  flip_y,  transpose,  autotile_coord)
