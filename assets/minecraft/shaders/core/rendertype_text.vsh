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

struct Element {
    vec2 size;      // tamanho real renderizado — ver nota em calculate() (utils.glsl)
    vec2 location;  // convenção centrada no eixo Y: -50=topo, 0=meio, 50=fundo
    vec2 margin;    // afastamento da borda, em pixels
    int bar;        // em que linha de bossbar (0 = topo) este elemento vive
};

const int HUD_COUNT = 2;

const Element HUD[HUD_COUNT] = Element[HUD_COUNT](
    Element(vec2(10.0, 10.0), vec2(3.0, -3.0), vec2(10.0, 10.0), 0),
    Element(vec2(32.0, 32.0), vec2(50.0, 0.0), vec2(0.0, 0.0), 0)
);

// Altura de cada linha de bossbar empilhada, em pixels GUI-scaled.
// Confirmado em jogo — não é derivado de nenhuma fórmula.
const float BAR_ROW_HEIGHT = 4.0;

void main() {
    texCoord0 = UV0;

    vec3 position = Position;
    vec4 color = Color;

    vec2 screen = getScreenSize();

    int index;

    int n = HUD.length();
    bool isHud = isElement(color, n, index);

    if (isHud) {
        Element element = HUD[index];
        vec2 location = toCalculateLocation(element.location);

        vec4 original = ModelViewMat * vec4(position, 1.0);
        original.xy = calculate(original, screen, element.size, location, element.margin, float(element.bar) * BAR_ROW_HEIGHT);

        gl_Position = ProjMat * original;
        vertexColor = vec4(1.0, 1.0, 1.0, color.a);
    } else {
        gl_Position = ProjMat * ModelViewMat * vec4(position, 1.0);
        vertexColor = color;
    }
}