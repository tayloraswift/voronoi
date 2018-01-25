#version 330 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;

layout(std140) uniform CameraMatrixBlock
{
    mat4 proj;    // [0  ..< 64 ]
    mat4 view;    // [64 ..< 128] size = 128
} matrix;

uniform mat4 matrix_model;
uniform mat3 matrix_normal;

out Vertex
{
    vec3 viewPosition;
    vec3 viewNormal;
    vec3 color;
} vertex;

void main()
{
    vec4 viewPosition   = matrix.view * matrix_model * vec4(position, 1);
    gl_Position         = matrix.proj * viewPosition;
    vertex.viewPosition = viewPosition.xyz;
    vertex.viewNormal   = matrix_normal * position;
    vertex.color        = color;
}
