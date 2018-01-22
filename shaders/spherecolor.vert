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
    vec3 color;
    vec3 normal;
} vertex;

void main()
{
    gl_Position   = matrix.proj * matrix.view * matrix_model * vec4(position, 1);
    vertex.color  = color;
    vertex.normal = matrix_normal * position;
}
