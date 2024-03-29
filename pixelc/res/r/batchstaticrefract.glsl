#ifdef VERTEX

    layout(location = 0) in vec2 in_pos;
    layout(location = 1) in vec2 in_uv;
    layout(location = 2) in vec4 in_color;
    layout(location = 3) in vec2 in_sprite;

    out vec3 v_tex_coord;
    out vec4 v_color;

    uniform mat4 vp;
    uniform vec2 sprites;
    uniform float camera_scale_2;

    void main() {
        vec2 pos = in_pos;

        // floor into the camera grid (enable half positions for centering uneven sizes)
        pos[0] = floor(pos[0] * camera_scale_2) / camera_scale_2;
        pos[1] = floor(pos[1] * camera_scale_2) / camera_scale_2;

        gl_Position = vp * vec4(pos.x, pos.y, 0, 1);
        v_tex_coord.xy = in_uv;

        // glsl: actual_layer = max(0, min(d - 1, floor(layer + 0.5)) )
        vec2 s_pos = floor(mod(in_sprite+0.5, sprites));
        s_pos = clamp(s_pos, vec2(0), sprites-1.0);
        v_tex_coord.z = s_pos.y * sprites.x + s_pos.x;

        v_color = in_color;
    }

#endif


#ifdef FRAGMENT
    #ifdef OPTION_GLES
        precision mediump float;
        precision lowp sampler2DArray;
    #endif

    in vec3 v_tex_coord;
    in vec4 v_color;

    out vec4 out_frag_color;

    uniform float scale; // aka real_pixel_per_pixel
    // in texture space (origin is top left) [0:1]
    // as center_x, _y, radius_x, _y
    // example for fullscreen: 0.5, 0.5, 0.5, 0.5
    uniform vec4 view_aabb;


    uniform sampler2DArray tex_main;
    uniform sampler2DArray tex_refraction;
    uniform sampler2D tex_framebuffer;


    // returns the distance to the border of space
    // space as aabb in center_x, center_y, radius_x, radius_y
    float space_distance(vec2 pos, vec4 space) {
        vec2 center = space.xy;
        vec2 radius = space.zw;
        vec2 dist = max(vec2(0, 0), radius - abs(pos-center));
        return min(dist.x, dist.y);
    }


    void main() {
        vec2 tex_refraction_size = vec2(textureSize(tex_refraction, 0));
        vec2 tex_framebuffer_size = vec2(textureSize(tex_framebuffer, 0));

        vec4 refract = texture(tex_refraction, v_tex_coord);

        // refract.z = stretch_val_x + stretch_val_y*16
        // stretch_val == 12.0f -> normal (8+4)
        // stretch_val == 4.0f -> mirror  (8-4)
        vec2 stretch = vec2(
        mod(refract.z*255.0f,16.0f)-8.0f,
        floor(refract.z*255.0f/16.0f)-8.0f
        );
        stretch.x = stretch.x / 4.0f - 1.0f;
        stretch.y = 1.0f - stretch.y / 4.0f;

        // framebuffer offset in real pixel coords
        vec2 offset = (refract.xy - 0.5f) * 255.0f;
        offset = offset + stretch * (v_tex_coord.xy - 0.5f) * tex_refraction_size;
        offset = offset * scale;  // intern pixel -> real pixel


        // grab coords for framebuffer
        vec2 r_coord;
        r_coord.x = (gl_FragCoord.x + offset.x) / tex_framebuffer_size.x;
        r_coord.y = 1.0f - (gl_FragCoord.y + offset.y) / tex_framebuffer_size.y;

        // if the coords are near the view space, or out of it, mix alpha to 0
        float alpha = mix(refract.a, 0.0f,
        max(0.0f, 1.0f-5.0f*space_distance(r_coord, view_aabb)));

        // blend main and refraction
        vec4 color = texture(tex_main, v_tex_coord);
        color.rgb = mix(color.rgb,
        texture(tex_framebuffer, r_coord).rgb, alpha);

        // add global color
        out_frag_color = color * v_color;
    }

#endif
