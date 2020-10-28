shader_type canvas_item;

uniform sampler2D u_input_tex;

void fragment() 
{
	// translate uvs from rectangular input texture to square voronoi texture.
	ivec2 tex_size = textureSize(u_input_tex, 0);
	vec2 uv = UV;
	if(tex_size.x > tex_size.y)
		uv.y = ((uv.y - 0.5) * (float(tex_size.x) / float(tex_size.y))) + 0.5;
	else
		uv.x = ((uv.x - 0.5) * (float(tex_size.y) / float(tex_size.x))) + 0.5;
		
	// for the voronoi seed texture we just store the UV of the pixel if the pixel is part
	// of an object (emissive or occluding), or black otherwise.
	vec4 scene_col = texture(u_input_tex, uv);
	COLOR = vec4(UV.x * scene_col.a, UV.y * scene_col.a, 0.0, 1.0);
}