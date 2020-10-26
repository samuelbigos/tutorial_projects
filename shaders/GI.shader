shader_type canvas_item;

// constants
uniform float PI = 3.141596;

// uniforms
uniform vec2 u_buffer_size;
uniform float u_rays_per_pixel = 32;
uniform sampler2D u_distance_data;
uniform sampler2D u_scene_data;
uniform sampler2D u_noise_data;
uniform float u_dist_mod = 1.0;
uniform float u_emission_multi = 1.0;
uniform float u_emission_range = 2.0;
uniform float u_emission_dropoff = 2.0;
uniform int u_max_raymarch_steps = 32;

// ================================================================================
// return the surface data at a given location. 'uv' contains the hit location, while
// hit_data contains the distance data at that location which we already sampled from 
// the map() func.
void get_material(vec2 uv, vec4 hit_data, out float emissive, out vec3 colour)
{	
	// convert uvs back to 0-1 range.
	float inv_aspect = u_buffer_size.y / u_buffer_size.x;
	uv.x *= inv_aspect;
	// read the surface data from emissive/colour maps. 
	// TODO: could probably be optimised by combining into one texture sample.
	vec4 emissive_data = texture(u_scene_data, uv);
	emissive = emissive_data.r * u_emission_multi;
	colour = vec3(1.0);
}

// ================================================================================
// get distance data (to nearest surface) from given UV location.
float map(vec2 uv, out vec4 hit_data)
{
	float inv_aspect = u_buffer_size.y / u_buffer_size.x;
	uv.x *= inv_aspect;
	hit_data = texture(u_distance_data, uv);
	float d = hit_data.x / u_dist_mod;
    return d;
}

// ================================================================================
// march a ray from a pixel in a given direction, until it hits a surface or runs out of
// steps. will return if a surface is hit, the hit location, hit data, and total length
// of the ray.
bool raymarch(vec2 origin, vec2 ray, out vec2 hit_pos, out vec4 hit_data, out float ray_dist)
{
	float t = 0.0;
	float prev_dist = 1.0;
	float step_dist = 1.0;
	vec2 sample_point;
	for(int i = 0; i < u_max_raymarch_steps; i++)
	{
		sample_point = origin + ray * t;
		step_dist = map(sample_point, hit_data);
		
		// consider a hit if distance to surface is < epsilon (half pixel).
		if(step_dist == 0.0)
		{
			hit_pos = sample_point;
  			return true;
		}
		// if we didn't find a hit, step forward by the distance found in distance texture (min 1px).
		// since this distance is the distance to nearest surface, it guarantees we won't 'overstep'
		// and go past a surface. worst case is we are parallel and close to the surface, so we can't step
		// far but also won't reach the surface. this is where we have to make a trade-off in u_max_raymarch_steps.
		step_dist = max(step_dist, min(1.0 / u_buffer_size.x, 1.0 / u_buffer_size.y));
		t += step_dist;
		ray_dist = t;
	}
	return false;
}

// ================================================================================
// do the thing!
void fragment() 
{
	// since UVs are in 0-1 space, and our viewport could be non-square, we need to convert
	// UVs so our rays aren't skewed. i.e. if we're 1024x512 viewport, this will convert 0-1
	// x/y to 0-2 on x and 0-1 on y.
	// we will need to convert back when doing texture samples, which need 0-1 UV space.
	vec2 uv = UV;
	float aspect = u_buffer_size.x / u_buffer_size.y;
	float inv_aspect = u_buffer_size.y / u_buffer_size.x;
	uv.x *= aspect;
		
	vec3 col = vec3(0.0);
	float emis = 0.0;
	
	// get a random angle by sampling the noise texture and offsetting it by time (so we don't always sample
	// the same noise).
	vec2 time = vec2(TIME, -TIME);
	float rand02pi = texture(u_noise_data, fract((uv + time) * 0.4)).r * 2.0 * PI; // noise sample
	float golden_angle = PI * 0.7639320225;
	
	for(float i = 0.0; i < u_rays_per_pixel; i++)
	{
		vec2 hit_pos;
		vec4 hit_data;
		float ray_dist;
		
		// get our ray dir by taking the random angle and adding golden_angle * ray number.
		float cur_angle = rand02pi + golden_angle * i;
		vec2 rand_direction = vec2(cos(cur_angle), sin(cur_angle));
		bool hit = raymarch(uv, rand_direction, hit_pos, hit_data, ray_dist);
		if(hit)
		{
			float mat_emissive;
			vec3 mat_colour;
			get_material(hit_pos, hit_data, mat_emissive, mat_colour);
			
			// convert UVs back to 0-1 space.
			vec2 st = hit_pos;
			st.x *= inv_aspect;
			
			float last_emission = 0.0;
			vec3 last_colour = vec3(0.0);
			
			// calculate total emissive/colour values from direct and bounced (last frame) lighting.
			float emission = mat_emissive + last_emission;
			float r = u_emission_range;
			float drop = u_emission_dropoff;
			// attenuation calculation - very tweakable to get the correct sort of light range/dropoff.
			float att = pow(max(1.0 - (ray_dist * ray_dist) / (r * r), 0.0), u_emission_dropoff);
			emis += emission * att;
			col += (mat_emissive + last_emission) * (mat_colour + last_colour) * att;
		}
	}
	
	// right now, emis and col store the sum of contribution of all rays to this pixel, we need
	// to normalise it.
	emis *= (1.0 / u_rays_per_pixel);
	col *= (1.0 / u_rays_per_pixel);
	
	COLOR = vec4(col * emis, 1.0);
}