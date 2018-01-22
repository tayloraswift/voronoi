#version 330 core

in Vertex
{
    noperspective vec3 color;
} vertex;

out vec4 color;

void main()
{
    color = vec4(1, 1, 1, 1);
}
