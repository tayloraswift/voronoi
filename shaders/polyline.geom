#version 330 core

layout(lines_adjacency) in;

in Vertex
{
    vec3 color;
    vec3 normal;
} vertex[4];

layout(std140) uniform CameraDataBlock
{
    mat4  world;                // [  0 ..<  64]
    vec3  position;             // [ 64 ..<  76]
    float zFar;                 // [ 76 ..<  80]
    vec3  antinormal;           // [ 80 ..<  92]
    float zNear;                // [ 92 ..<  96]
    vec2  size;                 // [ 96 ..< 104]
    vec2  center;               // [104 ..< 112]

    vec2  viewportResolution;   // [112 ..< 120]
    vec2  viewportCenter;       // [120 ..< 128]
    vec2  viewportOffset;       // [128 ..< 136]
    float scale;                // [136 ..< 140] size = 140
} camera;

//uniform float thickness;

layout(triangle_strip, max_vertices = 7) out;

out Vertex
{
    noperspective vec3 color;
} geometry;


vec2 screen(vec4 clip)
{
    return vec2(clip.xy / clip.w * camera.viewportResolution);
}

vec4 clip(vec2 screen)
{
    return vec4(screen / camera.viewportResolution, 0, 1);
}

void polyline(const vec2 nodes[4])
{
    //                   . nodes[i + 1]
    //  normals[i] ↖   ↗ vectors[i]
    //               ·
    //              nodes[i]

    const vec2 vectors[3] = vec2[]
    (
        normalize(nodes[1] - nodes[0]),
        normalize(nodes[2] - nodes[1]),
        normalize(nodes[3] - nodes[2])
    );

    const vec2 normals[3] = vec2[]
    (
        vec2(-vectors[0].y, vectors[0].x),
        vec2(-vectors[1].y, vectors[1].x),
        vec2(-vectors[2].y, vectors[2].x)
    );

    //             vector
    //               ↑
    //            2 ——— 3
    //            | \   |
    //   normal ← |  \  |
    //            |   \ |
    //            0 ——— ­1

    geometry.color = vertex[1].color;
    gl_Position = clip(nodes[1] + 3 * normals[1]);
    EmitVertex();
    gl_Position = clip(nodes[1] - 3 * normals[1]);
    EmitVertex();

    geometry.color = vertex[2].color;
    gl_Position = clip(nodes[2] + 3 * normals[1]);
    EmitVertex();
    gl_Position = clip(nodes[2] - 3 * normals[1]);
    EmitVertex();
    EndPrimitive();
}

void main()
{
    vec2 nodes[4];
    nodes[0] = screen(gl_in[0].gl_Position);
    nodes[1] = screen(gl_in[1].gl_Position);
    nodes[2] = screen(gl_in[2].gl_Position);
    nodes[3] = screen(gl_in[3].gl_Position);

    polyline(nodes);
}
