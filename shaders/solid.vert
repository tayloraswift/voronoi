#version 330 core

layout(location = 0) in vec3 position;

layout(std140) uniform CameraMatrixBlock
{
    mat4 proj;    // [0  ..< 64 ]
    mat4 view;    // [64 ..< 128] size = 128
} matrix;

uniform mat4 matrix_model;

void main()
{
    gl_Position  = matrix.proj * matrix.view * matrix_model * vec4(position, 1);
}
