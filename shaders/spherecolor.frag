#version 330 core

in V_OUT
{
    vec3 color;
    vec3 normal;
} vertex;

uniform vec3 sun;

out vec4 color;

void main()
{
    color = vec4(vertex.color * (max(-dot(vertex.normal, sun), 0) + 0.1), 1);
}
