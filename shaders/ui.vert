#version 330 core

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 uv;

out Vertex
{
    vec2 uv;
} vertex;

void main()
{
    gl_Position = vec4(position.xy, -1.0, 1.0);
    vertex.uv = uv;
}
