extends Node2D

var _voronoi_passes = []

func _ready():
	# parent our emissive and occluding sprites to the EmittersAndOccluders viewport at runtime.
	var emitter = $Emitter
	var occluder = $Occluder
	remove_child(emitter)
	remove_child(occluder)
	$EmittersAndOccluders.add_child(emitter)
	$EmittersAndOccluders.add_child(occluder)
	
	# setup our viewports and screen texture.
	# you can do this in the editor, but i prefer to do it in code since it's more visible and easier to update.
	$EmittersAndOccluders.transparent_bg = true
	$EmittersAndOccluders.render_target_update_mode = Viewport.UPDATE_ALWAYS
	$EmittersAndOccluders.render_target_v_flip = true
	$EmittersAndOccluders.size = get_viewport().size
	$Screen.rect_size = get_viewport().size

	# setup our voronoi seed render texture.
	$VoronoiSeed.render_target_update_mode = Viewport.UPDATE_ALWAYS
	$VoronoiSeed.render_target_v_flip = true
	$VoronoiSeed.size = get_viewport().size
	$VoronoiSeed/Tex.rect_size = get_viewport().size
	$VoronoiSeed/Tex.material.set_shader_param("u_input_tex", $EmittersAndOccluders.get_texture())
	
	# set the screen texture to use the voronoi seed output.
	$Screen.texture = $VoronoiSeed.get_texture()
	
	# setup our voronoi pass render texture.
	$JumpFloodPass.render_target_update_mode = Viewport.UPDATE_ALWAYS
	$JumpFloodPass.render_target_v_flip = true
	$JumpFloodPass.size = get_viewport().size
	$JumpFloodPass/Tex.rect_size = get_viewport().size

	# number of passes required is the log2 of the largest viewport dimension rounded up to the nearest power of 2.
	# i.e. 768x512 is log2(1024) == 10
	var passes = ceil(log(max(get_viewport().size.x, get_viewport().size.y)) / log(2.0))
	
	# iterate through each pass and set up the required render pass objects.
	for i in range(0, passes):
		
		# offset for each pass is half the previous one, starting at half the square resolution rounded up to nearest power 2.
		# i.e. for 768x512 we round up to 1024x1024 and the offset for the first pass is 512x512, then 256x256, etc. 
		var offset = pow(2, passes - i - 1)
		
		# on the first pass, use our existing render pass, on subsequent passes we duplicate the existing render pass.
		var render_pass
		if i == 0:
			render_pass = $JumpFloodPass
		else:
			render_pass = $JumpFloodPass.duplicate(0)
			add_child(render_pass)
			
		render_pass.get_child(0).material = render_pass.get_child(0).material.duplicate(0)
		_voronoi_passes.append(render_pass)
		
		# here we set the input texture for each pass, which is the previous pass, unless it's the first pass in which case it's
		# the seed texture.
		var input_texture = $VoronoiSeed.get_texture()
		if i > 0:
			input_texture = _voronoi_passes[i - 1].get_texture()
		
		# set size and shader uniforms for this pass.
		render_pass.set_size(get_viewport().size)
		render_pass.get_child(0).material.set_shader_param("u_level", i)
		render_pass.get_child(0).material.set_shader_param("u_max_steps", passes)
		render_pass.get_child(0).material.set_shader_param("u_offset", offset)
		render_pass.get_child(0).material.set_shader_param("u_input_tex", input_texture)
		
	# set the screen texture to use the final jump flooding pass output.
	$Screen.texture = _voronoi_passes[_voronoi_passes.size() - 1].get_texture()

	# setup our distance field render texture.
	$DistanceField.transparent_bg = true
	$DistanceField.render_target_update_mode = Viewport.UPDATE_ALWAYS
	$DistanceField.render_target_v_flip = true
	$DistanceField.size = get_viewport().size
	$DistanceField/Tex.rect_size = get_viewport().size
	$DistanceField/Tex.material.set_shader_param("u_input_tex", _voronoi_passes[_voronoi_passes.size() - 1].get_texture())
	$DistanceField/Tex.material.set_shader_param("u_dist_mod", 10.0)
	
	# set the screen texture to use the distance field output.
	$Screen.texture = $DistanceField.get_texture()
	
	# setup our distance field render texture.
	$GI.render_target_update_mode = Viewport.UPDATE_ALWAYS
	$GI.render_target_v_flip = true
	$GI.size = get_viewport().size
	$GI/Tex.rect_size = get_viewport().size
	$GI/Tex.material.set_shader_param("u_buffer_size", get_viewport().size)
	$GI/Tex.material.set_shader_param("u_rays_per_pixel", 32)
	$GI/Tex.material.set_shader_param("u_distance_data", $DistanceField.get_texture())
	$GI/Tex.material.set_shader_param("u_scene_data", $EmittersAndOccluders.get_texture())
	$GI/Tex.material.set_shader_param("u_noise_data", load("res://noise.png"))
	$GI/Tex.material.set_shader_param("u_dist_mod", 10.0)
	$GI/Tex.material.set_shader_param("u_emission_multi", 1.0)
	$GI/Tex.material.set_shader_param("u_emission_range", 2.0)
	$GI/Tex.material.set_shader_param("u_emission_dropoff", 2.0)
	$GI/Tex.material.set_shader_param("u_max_raymarch_steps", 128.0)
	
	# set the screen texture to use the GI output.
	$Screen.texture = $GI.get_texture()
	
	
	
	
	
	
	
	
	VisualServer.viewport_set_active($EmittersAndOccluders.get_viewport_rid(), false)
	VisualServer.viewport_set_active($EmittersAndOccluders.get_viewport_rid(), true)
	VisualServer.viewport_set_active($VoronoiSeed.get_viewport_rid(), false)
	VisualServer.viewport_set_active($VoronoiSeed.get_viewport_rid(), true)
	for i in _voronoi_passes:
		VisualServer.viewport_set_active(i.get_viewport_rid(), false)
		VisualServer.viewport_set_active(i.get_viewport_rid(), true)
	VisualServer.viewport_set_active($DistanceField.get_viewport_rid(), false)
	VisualServer.viewport_set_active($DistanceField.get_viewport_rid(), true)
	VisualServer.viewport_set_active($GI.get_viewport_rid(), false)
	VisualServer.viewport_set_active($GI.get_viewport_rid(), true)
