# 2DPerspective
Godot 2D Perspective addon, it's basically a node that makes all it's sprite children have [One Point Perspective Projection](https://en.wikipedia.org/wiki/Perspective_(graphical)#One-point_perspective) creating a 3d looking effect 

It has 2 projection modes:
- **Boxes**: Creates a projected box to the Vanishing point using the sprite at all sides, also offering the option to change the top and bottom ones
- **Clone**: While experimenting with the concept Godot released the pseudo3d videos and this mode is inspired by that one, looks a lot better for irregular sprites.

## Components
This addon registers 2 components: 

###### P2DPerspectiveNode
New Node and core of the projection functionality, it setups the [Vanishing Point](https://en.wikipedia.org/wiki/Vanishing_point), projection mode, projection distance and other 
parameters to customize the node output.

###### Inspector Plugin
It adds new functionality in the Sprite inspector to change options individually that affect the Sprite projection
