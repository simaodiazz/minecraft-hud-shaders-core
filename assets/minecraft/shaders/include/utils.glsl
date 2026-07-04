// Converte a cor do vértice (0.0-1.0 por canal) para um identificador
// inteiro (0-255). round() em vez de truncar porque a cor pode vir
// com pequenos erros de precisão de float.
ivec4 toIdentifier(vec4 color) {
    return ivec4(
        int(round(color.r * 255.0)),
        int(round(color.g * 255.0)),
        int(round(color.b * 255.0)),
        int(round(color.a * 255.0))
    );
}

// Valor fixo no canal B que marca este vértice como pertencente ao
// sistema de HUD.
const int HUD_MARKER_VALUE = 253;

const int LOCATION_STEP = 2;
const int LOCATION_CENTER = 256;

bool decode(vec4 color, out ivec2 outLocation) {
    ivec4 rgba = toIdentifier(color);

    if (rgba.b != HUD_MARKER_VALUE) {
        return false;
    }

    outLocation = ivec2(rgba.r, rgba.g) * LOCATION_STEP;
    return true;
}

// Tamanho do ecrã, em pixels GUI-scaled + Transformers
vec2 getScreenSize() {
    return ceil(2.0 / vec2(ProjMat[0][0], -ProjMat[1][1]));
}

// Ajuste fino, apurado em jogo manualmente.
const float Y_FINE_TUNE_PIXELS = 18.5;

vec2 calculate(vec4 original, vec2 screen, ivec2 location) {
    vec2 offset = original.xy;

    // Cancela o baseline vertical do bossbar (perto do topo do ecrã).
    offset.y += screen.y * 0.5;

    vec2 normalized = (vec2(location) - float(LOCATION_CENTER)) / float(LOCATION_CENTER);
    vec2 pos = (screen * 0.5) * normalized;

    pos.y -= Y_FINE_TUNE_PIXELS;

    return pos + offset;
}
