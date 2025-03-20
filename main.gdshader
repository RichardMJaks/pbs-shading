shader_type spatial;
render_mode unshaded;

uniform sampler2D panorama_texture;  // Panoramic texture
uniform sampler2D roughness_texture; // Roughness map
uniform vec3 light_dir;              // Light direction vector in world space
uniform float ambient_intensity : hint_range(0.0, 1.0, 0.1) = 0.4;  // Ambient light intensity (0 - 1)
uniform vec4 ambient_color: source_color;
uniform float roughness_factor : hint_range(0.0, 1.0, 0.1) = 0.2;   // The higher, the stronger the blur
uniform float metallic : hint_range(0.04, 1, 0.01) = 0.04;           // 0.04 - dielectric, 1 - metal
uniform float n1: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float m: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float sigma: hint_range(0.0, 1.5, 0.01) = 0.5;

void fragment() {
    // Get the normal in world space
    vec3 normal = normalize((INV_VIEW_MATRIX * vec4(-NORMAL, 0.0)).xyz);

    // Get the camera direction in world space
    vec3 view_dir = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);

    // Reflected direction in world space
    vec3 reflected_dir = reflect(view_dir, normal);

    // **Invert the reflection direction only for texture mapping**
    vec3 corrected_reflection = -reflected_dir;

    // Convert to spherical coordinates
    float longitude = atan(corrected_reflection.z, corrected_reflection.x);
    float latitude = acos(corrected_reflection.y);

    // Convert to UV, shifting U by 90° (offset U)
    vec2 uv = vec2(longitude / (2.0 * PI) + 0.75, 1.0 - (latitude / PI));
    uv.x = mod(uv.x, 1.0);

    // Get the roughness value
    float roughness = texture(roughness_texture, uv).r * roughness_factor;

    // **Blurring using MIP-maps** (higher roughness results in a higher LOD level)
    float lod_level = roughness * 8.0;
    vec3 blurred_color = ambient_color.rgb * textureLod(panorama_texture, uv, lod_level).rgb;

    // **Phong lighting model**
    vec3 light = normalize(light_dir);             // Light direction in world space
    vec3 reflect_light = reflect(-light, normal);  // Reflected light vector

    float diffuse = max(dot(normal, light), 0.0);  // Diffuse lighting
    float specular = pow(max(dot(reflect_light, view_dir), 0.0), mix(32.0, 2.0, roughness));  // Specular highlight

    // **Fresnel-Schlick model**
    float NdotV = max(dot(normal, view_dir), 0.0);
	float r0 = pow((1.0 - n1) / (1.0 + n1), 2.0);
    float fresnel = r0 + (1.0 - r0) * pow(1.0 - NdotV, 5.0); // Using metallic instead of R0

	// Oren-Nayar diffuse
	float L = max(0, dot(normal, light_dir));
	float V = max(0, dot(normal, view_dir));
	float sigma_squared = pow(sigma, 2);
	float A = 1.0 - 0.5 * (sigma_squared / (sigma_squared + 0.33));
	float B = 0.45 * (sigma_squared / (sigma_squared + 0.09));
	vec3 v_proj = normalize(view_dir - normal * V);
	vec3 l_proj = normalize(light_dir - normal * L);
	vec3 l_brdf = COLOR.rgb / PI;
	float alpha = max(acos(dot(view_dir, normal)), acos(dot(light_dir, normal)));
	float beta = min(acos(dot(view_dir, normal)), acos(dot(light_dir, normal)));
	float proj_dot = max(0, dot(v_proj, l_proj));
	float calc = sqrt((1.0 - pow(L, 2) * (1.0 - pow(V, 2)))) / max(L, V);
	vec3 oren_nayar = l_brdf * (A + B * proj_dot * calc);

    // **Final color calculation**
    vec3 ambient_light = blurred_color * ambient_intensity;  // Ambient lighting
    vec3 specular_light = vec3(fresnel) * specular;         // Specular reflection
    vec3 diffuse_light = (1.0 - fresnel) * (1.0 - metallic) * oren_nayar * blurred_color;  // Diffuse reflection

    vec3 final_color = ambient_light + specular_light + diffuse_light;

    // Set pixel color
    ALBEDO = final_color;
}
