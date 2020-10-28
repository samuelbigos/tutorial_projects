shader_type canvas_item;

uniform sampler2D u_GI_texture;

vec3 lin_to_srgb(vec4 color)
{
    vec3 x = color.rgb * 12.92;
    vec3 y = 1.055 * pow(clamp(color.rgb, 0.0, 1.0), vec3(0.4166667)) - 0.055;
    vec3 clr = color.rgb;
    clr.r = (color.r < 0.0031308) ? x.r : y.r;
    clr.g = (color.g < 0.0031308) ? x.g : y.g;
    clr.b = (color.b < 0.0031308) ? x.b : y.b;
	return clr.rgb;
}

void fragment() 
{
	vec4 GI = texture(u_GI_texture, UV);
	COLOR = vec4(lin_to_srgb(GI), 1.0);
}