"""Genera el icono de la aplicación.

Se dibuja por código en lugar de guardar un binario en el repositorio: así el icono es
reproducible, se puede ajustar cambiando unas constantes y queda claro de dónde sale cada
forma.

El diseño busca legibilidad a tamaño pequeño, que es donde de verdad se ve un icono de app:
un símbolo de peso sobre tres barras ascendentes, en el verde azulado del tema. Sin degradados
sutiles ni detalles finos, que a 48 píxeles desaparecen.

Uso:
    python3 tools/generar_icono.py
    dart run flutter_launcher_icons
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

LADO = 1024

# El mismo verde azulado que la semilla del tema de la aplicación.
FONDO_CLARO = (0, 121, 107)
FONDO_OSCURO = (0, 77, 64)
BLANCO = (255, 255, 255)
BLANCO_TENUE = (255, 255, 255, 90)

DESTINO = Path(__file__).resolve().parent.parent / "assets" / "icono"

# Radio, en fracción del lado del lienzo, dentro del cual debe caber todo el dibujo de un icono
# adaptativo de Android. La zona visible es el 66% central del lienzo y el lanzador puede
# recortarla en círculo, así que lo que salga de ese radio se pierde; se deja algo de aire.
RADIO_SEGURO = 0.315


def degradado_vertical(lado: int) -> Image.Image:
    """Fondo con un degradado suave, más oscuro abajo para dar algo de profundidad."""
    imagen = Image.new("RGB", (lado, lado))
    dibujo = ImageDraw.Draw(imagen)
    for y in range(lado):
        t = y / lado
        color = tuple(
            round(FONDO_CLARO[i] + (FONDO_OSCURO[i] - FONDO_CLARO[i]) * t) for i in range(3)
        )
        dibujo.line([(0, y), (lado, y)], fill=color)
    return imagen


def dibujar_barras(dibujo: ImageDraw.ImageDraw, lado: int) -> None:
    """Tres barras ascendentes: la idea de seguir la evolución mes a mes."""
    ancho = round(lado * 0.10)
    separacion = round(lado * 0.055)
    base = round(lado * 0.790)
    alturas = [round(lado * a) for a in (0.105, 0.170, 0.235)]

    total = 3 * ancho + 2 * separacion
    x = (lado - total) / 2

    for i, altura in enumerate(alturas):
        izquierda = round(x + i * (ancho + separacion))
        dibujo.rounded_rectangle(
            [izquierda, base - altura, izquierda + ancho, base],
            radius=round(ancho * 0.30),
            # La barra más alta va en blanco pleno; las otras se atenúan para que la vista
            # siga la progresión sin que compitan entre sí.
            fill=BLANCO if i == 2 else BLANCO_TENUE,
        )


def cargar_fuente(tamano: int) -> ImageFont.FreeTypeFont:
    """Primera fuente disponible de la lista, en su corte más grueso.

    Trazar el signo de peso a mano con arcos daba una curva torpe; el glifo de una fuente de
    verdad se lee mucho mejor. Se prueban varias rutas porque no todas las máquinas tienen las
    mismas fuentes instaladas.
    """
    candidatas = [
        ("/System/Library/Fonts/HelveticaNeue.ttc", 1),
        ("/System/Library/Fonts/Helvetica.ttc", 1),
        ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 0),
        ("/Library/Fonts/Arial Bold.ttf", 0),
    ]
    for ruta, indice in candidatas:
        if Path(ruta).exists():
            return ImageFont.truetype(ruta, tamano, index=indice)
    raise SystemExit(
        "No se encontró ninguna fuente para dibujar el signo de peso.\n"
        "Añade la ruta de una fuente en negrita a la lista de 'cargar_fuente'."
    )


def dibujar_peso(dibujo: ImageDraw.ImageDraw, lado: int) -> None:
    """El signo de peso, centrado sobre las barras."""
    fuente = cargar_fuente(round(lado * 0.42))
    centro = (lado / 2, round(lado * 0.345))
    # 'anchor="mm"' centra por la caja real del glifo, no por la línea base: sin esto el signo
    # queda visiblemente descolgado hacia arriba.
    dibujo.text(centro, "$", font=fuente, fill=BLANCO, anchor="mm")


def radio_del_dibujo(capa: Image.Image) -> float:
    """Distancia del centro al punto pintado más lejano, en píxeles."""
    ancho, alto = capa.size
    centro_x, centro_y = ancho / 2, alto / 2
    alfa = capa.getchannel("A")

    mayor = 0.0
    for y in range(alto):
        fila = alfa.crop((0, y, ancho, y + 1)).tobytes()
        # De cada fila basta el píxel pintado más a la izquierda y el más a la derecha: el
        # resto queda por dentro.
        pintados = [x for x, valor in enumerate(fila) if valor > 0]
        if not pintados:
            continue
        for x in (pintados[0], pintados[-1]):
            distancia = ((x - centro_x) ** 2 + (y - centro_y) ** 2) ** 0.5
            mayor = max(mayor, distancia)
    return mayor


def generar() -> None:
    fondo = degradado_vertical(LADO).convert("RGBA")
    capa = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    dibujo = ImageDraw.Draw(capa)

    dibujar_peso(dibujo, LADO)
    dibujar_barras(dibujo, LADO)

    completo = Image.alpha_composite(fondo, capa)

    DESTINO.mkdir(parents=True, exist_ok=True)

    # Icono con fondo, para Android antiguo, macOS y la web.
    completo.convert("RGB").save(DESTINO / "icono.png")

    # Fondo de los iconos adaptativos de Android: el mismo degradado del icono completo, no un
    # color plano. Es lo que hace que en el teléfono se vea igual que en el Mac; con el fondo
    # liso, el degradado desaparecía y el icono quedaba mucho más pobre.
    fondo.convert("RGB").save(DESTINO / "icono_fondo.png")

    # Capa de primer plano para los iconos adaptativos de Android, que recortan la imagen con la
    # forma que elija el lanzador: círculo, cuadrado redondeado o gota.
    # El factor de escala sale del punto pintado más lejano al centro, no del recuadro que lo
    # encierra: encajar el recuadro entero en el círculo dejaría el dibujo mucho más pequeño de
    # lo necesario, porque sus esquinas van en transparente.
    escala = (LADO * RADIO_SEGURO) / radio_del_dibujo(capa)
    adaptativo = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    reducido = capa.resize((round(LADO * escala), round(LADO * escala)), Image.LANCZOS)
    desplazamiento = (LADO - reducido.width) // 2
    adaptativo.paste(reducido, (desplazamiento, desplazamiento), reducido)
    adaptativo.save(DESTINO / "icono_adaptativo.png")

    print(f"  icono.png y icono_adaptativo.png generados en {DESTINO}")


if __name__ == "__main__":
    generar()
