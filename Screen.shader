shader_type canvas_item;

uniform sampler2D u_input_tex;

void fragment() 
{
	vec4 output = texture(u_input_tex, UV);
	COLOR = output;
}