// Cada canal (R, G, B) da cor do vértice funciona como um "dígito"
// em base HUD_CHANNEL_BASE, para identificar qual elemento de HUD
// este vértice representa. Com HUD_CHANNEL_MAX=3 (4 valores por
// canal), R/G/B combinados dão 4*4*4 = 64 índices possíveis
// (000000 até 030303 em notação RRGGBB, hudIndex 0 a 63).
const int HUD_CHANNEL_MAX = 3;
const int HUD_CHANNEL_BASE = HUD_CHANNEL_MAX + 1;

// Converte a cor do vértice (0.0-1.0 por canal) para um identificador
// inteiro (0-255). Usamos round() em vez de truncar porque a cor
// pode chegar com pequenos erros de precisão de float.
ivec4 toIdentifier(vec4 color) {
    return ivec4(
        int(round(color.r * 255.0)),
        int(round(color.g * 255.0)),
        int(round(color.b * 255.0)),
        int(round(color.a * 255.0))
    );
}

// Testa se um identificador de cor está dentro do range reservado
// para vértices de HUD (cada canal entre 0 e HUD_CHANNEL_MAX). Cores
// de texto/UI legítimas fora deste range nunca são apanhadas à toa.
bool isElement(ivec4 rgba) {
    return rgba.r <= HUD_CHANNEL_MAX
        && rgba.g <= HUD_CHANNEL_MAX
        && rgba.b <= HUD_CHANNEL_MAX;
}

// Combina os 3 canais num único índice em base HUD_CHANNEL_BASE
// (R = dígito mais significativo, B = menos significativo).
int getIndexFromColor(ivec4 rgba) {
    return rgba.r * HUD_CHANNEL_BASE * HUD_CHANNEL_BASE
        + rgba.g * HUD_CHANNEL_BASE
        + rgba.b;
}

// Tenta resolver a cor de um vértice para um índice de HUD válido.
// Devolve false (sem escrever em outIndex) se a cor estiver fora do
// range reservado ou se o índice exceder hudCount — nesses casos o
// vértice deve ser tratado como texto/UI normal. Agrupa aqui
// toIdentifier + isElement + getIndexFromColor + bounds check para
// o vertex shader não repetir esta lógica.
bool isElement(vec4 color, int hudCount, out int outIndex) {
    ivec4 rgba = toIdentifier(color);
    if (!isElement(rgba)) {
        return false;
    }
    int index = getIndexFromColor(rgba);
    if (index >= hudCount) {
        return false;
    }
    outIndex = index;
    return true;
}

// Tamanho do ecrã, em pixels GUI-scaled, derivado da matriz de
// projeção ortográfica: ProjMat[0][0] = 2/largura,
// ProjMat[1][1] = -2/altura (negativo — daí o sinal trocado aqui).
vec2 getScreenSize() {
    return ceil(2.0 / vec2(ProjMat[0][0], -ProjMat[1][1]));
}

// No eixo Y, a config usa a convenção centrada (-50=topo, 0=meio,
// 50=fundo) porque foi assim que a orientação correta foi confirmada
// empiricamente em jogo. calculate() trabalha internamente na
// convenção 0-100 (0 = início do espaço disponível), por isso esta
// função faz essa conversão num único sítio. O eixo X não precisa
// disto: usa 0-100 diretamente, sem alteração.
const float LOCATION_Y_CENTER_OFFSET = 50.0;

vec2 toCalculateLocation(vec2 configuration) {
    return vec2(configuration.x, configuration.y + LOCATION_Y_CENTER_OFFSET);
}

// Ajuste fino, apurado empiricamente em jogo (não deduzido pela
// matemática da projeção) — compensa um desvio residual para baixo,
// provavelmente causado pelo baseline/padding do glyph ou pelo
// arredondamento em getScreenSize(). Reajustar aqui se a calibração
// mudar.
const float Y_FINE_TUNE_PIXELS = 1.0;

vec2 calculate(
    vec4 original,
    vec2 screen,
    vec2 size,
    vec2 location,
    vec2 margin,
    float barOffset
) {
    vec2 offset = original.xy;

    // available é o espaço que sobra para mover o CENTRO do
    // elemento sem ele sair do ecrã. Usar "screen" diretamente faria
    // location=100 encostar o CENTRO à borda
    vec2 available = screen - size;

    // Quantos pixels correspondem a 1% do espaço disponível.
    vec2 step = available / 100.0;

    // Ponto de partida (location=0): o extremo esquerdo/topo do
    // intervalo disponível.
    vec2 left = -available * 0.5;

    // location é usado diretamente, sem inverter o eixo Y: o ProjMat
    // já inverte esse eixo (ProjMat[1][1] é negativo), por isso
    // location.y=0 já corresponde ao topo do ecrã sem flip manual.
    vec2 pos = left + step * location;

    // O margin empurra sempre para DENTRO do ecrã: no lado
    // esquerdo/topo (location < 50) empurra no sentido positivo, no
    // lado direito/fundo (location >= 50) empurra no sentido negativo.
    vec2 sign = vec2(
        location.x >= 50.0 ? -1.0 : 1.0,
        location.y >= 50.0 ? -1.0 : 1.0
    );
    pos += sign * margin;

    // Bossbars mais fundas (bar > 0) sobem o elemento para não ficar
    // por baixo de bossbars já ocupadas acima.
    pos.y -= barOffset;

    pos.y -= Y_FINE_TUNE_PIXELS;

    return pos + offset;
}