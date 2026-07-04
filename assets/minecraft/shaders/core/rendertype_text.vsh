#version 330

#moj_import <dynamictransforms.glsl>
#moj_import <projection.glsl>
#moj_import <globals.glsl>
#moj_import <utils.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;

out vec4 vertexColor;
out vec2 texCoord0;

void main() {
    texCoord0 = UV0;

    vec3 position = Position;
    vec4 color = Color;

    ivec2 location;
    bool result = decode(color, location);

    if (isHud) {
        vec2 screen = getScreenSize();

        vec4 original = ModelViewMat * vec4(position, 1.0);
        original.xy = calculate(original, screen, location);

        gl_Position = ProjMat * original;
        vertexColor = vec4(1.0, 1.0, 1.0, color.a);
    } else {
        gl_Position = ProjMat * ModelViewMat * vec4(position, 1.0);
        vertexColor = color;
    }
}
