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

// Schlick's approximation for Fresnel Effect
float fresnel(vec3 normal, vec3 v_x) {
	float r0 = pow((1.0 - n1) / (1.0 + n1), 2.0);
    float fresnel = r0 + (1.0 - r0) * pow(1.0 - max(dot(normal, v_x), 0), 5.0);

	return fresnel;
}

vec3 oren_nayar(vec3 normal,vec3 view_dir, vec3 light) {
	// Variables
	float L = max(0, dot(normal, light));
	float V = max(0, dot(normal, view_dir));
	float sigma_squared = pow(sigma, 2);
	float A = 1.0 - 0.5 * (sigma_squared / (sigma_squared + 0.33));
	float B = 0.45 * (sigma_squared / (sigma_squared + 0.09));

	// Angles
	float alpha = max(acos(dot(view_dir, normal)), acos(dot(light_dir, normal)));
	float beta = min(acos(dot(view_dir, normal)), acos(dot(light_dir, normal)));

	// Projections
	vec3 v_proj = normalize(view_dir - normal * V);
	vec3 l_proj = normalize(light_dir - normal * L);
	float proj_dot = max(0, dot(v_proj, l_proj));

	// Calculations
	float calc = sqrt((1.0 - pow(L, 2) * (1.0 - pow(V, 2)))) / max(L, V);
	vec3 oren_nayar = vec3(A + B * proj_dot * calc);

	return oren_nayar;
}

// Formula given by ChatGPT
float geometry_cook_torrance(vec3 normal, vec3 h, vec3 light, vec3 view_dir) {
	// Dot products
	float ndh = max(dot(normal, h), 0.0);
	float ndv = max(dot(normal, view_dir), 0.0);
	float ndl = max(dot(normal, light), 0.0);
	float vdh = max(dot(view_dir, h), 0.0);

	// Calculations (split up for easier reading)
	float G_1 = (2.0 * ndh * ndv) / (vdh);
	float G_2 = (2.0 * ndh * ndl) / vdh;
	float G = min(1, min(G_1, G_2));

	return G;
}

float cook_torrance(vec3 light, vec3 view_dir, vec3 normal, vec3 color) {
	// Distribution term
	vec3 h = normalize(light + view_dir);
	float ndh = max(dot(normal, h), 0);
	float D_1 = (1.0 / (pow(m, 2) * pow(ndh, 4)));
	float D_2 = -pow(sqrt(1.0 - pow(ndh, 2)) / (ndh * m), 2);
	float D = pow(D_1 * E, D_2);

	// Other terms
    float fresnel = fresnel(normal, h);
	float G = geometry_cook_torrance(normal, h, light, view_dir);

	// Cook-Torrance calculation
	float ct = (fresnel * D * G) / 4.0 * dot(normal, view_dir) * dot(normal, light);

	return ct;
}

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
	float fresnel = fresnel(normal, view_dir);

	// Oren-Nayar diffuse
	vec3 oren_nayar = oren_nayar(normal, view_dir, light);

	// Cook-Torrance microfacets
	float ct = cook_torrance(light, view_dir, normal, COLOR.rgb);

    // **Final color calculation**
    vec3 ambient_light = blurred_color * ambient_intensity;  // Ambient lighting
    vec3 specular_light = vec3(ct); // Specular reflection
    vec3 diffuse_light = (1.0 - fresnel) * (1.0 - metallic) * oren_nayar * blurred_color; // Diffuse reflection

    vec3 final_color = ambient_light + specular_light + diffuse_light;

    // Set pixel color
    ALBEDO = final_color;
}

