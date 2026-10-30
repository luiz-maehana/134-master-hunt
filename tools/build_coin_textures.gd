extends SceneTree
## Gera as texturas das seis moedas a partir da arte-fonte (frente e verso lado a lado,
## fundo transparente).
##   godot --headless --path . --script res://tools/build_coin_textures.gd
##
## Saída: atlas com uma linha por valor (de cima para baixo: 1, 5, 10, 25, 50 centavos e
## R$ 1); em cada linha, frente à esquerda e verso à direita.
##   assets/textures/coin/coin_albedo.jpg  — cor (JPG: sem alfa, fundo = cor da borda)
##   assets/textures/coin/coin_normal.png  — relevo derivado da luminância (meia resolução)
## A pasta assets/source/ tem .gdignore: os originais não são importados nem exportados.
##
## As faces podem ter tamanhos diferentes e até se encostar (uma cobrindo a borda da outra):
## cada disco é achado pela altura e pela borda externa, e o que fica fora dele (ou embaixo
## da outra moeda) vira a cor da borda.

const SOURCES: Array[String] = [
	"res://assets/source/coin_1_centavo_source.png",
	"res://assets/source/coin_5_centavos_source.png",
	"res://assets/source/coin_10_centavos_source.png",
	"res://assets/source/coin_25_centavos_source.png",
	"res://assets/source/coin_50_centavos_source.png",
	"res://assets/source/coin_1_real_source.png",
]
const OUT_DIR := "res://assets/textures/coin/"
## Lado de cada face no atlas. A moeda ocupa poucos pixels na tela; 256 sobra.
const FACE_SIZE := 256
## Margem interna (fração do raio) para cortar o fio escuro da borda recortada.
const EDGE_INSET := 0.015
## Intensidade do relevo do normal map.
const BUMP_STRENGTH := 6.0


func _initialize() -> void:
	var atlas := Image.create(FACE_SIZE * 2, FACE_SIZE * SOURCES.size(), false, Image.FORMAT_RGBA8)
	for row in SOURCES.size():
		var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCES[row]))
		if source == null or source.is_empty():
			printerr("Não foi possível abrir ", SOURCES[row])
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var discs := _find_discs(source)
		var faces: Array[Image] = []
		for side in 2:
			var other: Vector3 = discs[1 - side]
			faces.append(_cut_face(source, discs[side], other))
		print("%s: %dx%d, frente %s, verso %s" % [SOURCES[row].get_file(), source.get_width(), source.get_height(), discs[0], discs[1]])
		var rim := _rim_color(faces[0])
		atlas.fill_rect(Rect2i(0, row * FACE_SIZE, FACE_SIZE * 2, FACE_SIZE), rim)
		for side in 2:
			_blend_over(atlas, faces[side], Vector2i(side * FACE_SIZE, row * FACE_SIZE))
	atlas.convert(Image.FORMAT_RGB8)

	var height := atlas.duplicate() as Image
	height.convert(Image.FORMAT_L8)
	# Relevo em meia resolução: suaviza arranhões finos (ruído) e o relevo sutil não
	# precisa de mais detalhe que isso no tamanho em que a moeda aparece.
	height.resize(atlas.get_width() / 2, atlas.get_height() / 2, Image.INTERPOLATE_CUBIC)
	height.convert(Image.FORMAT_RGBA8)
	height.bump_map_to_normal_map(BUMP_STRENGTH)
	height.convert(Image.FORMAT_RGB8)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var albedo_path := OUT_DIR + "coin_albedo.jpg"
	var normal_path := OUT_DIR + "coin_normal.png"
	atlas.save_jpg(albedo_path, 0.88)
	height.save_png(normal_path)
	print("Salvo: %s %dx%d (%d KB), %s (%d KB)" % [
		albedo_path, atlas.get_width(), atlas.get_height(), _kb(albedo_path), normal_path, _kb(normal_path)])
	quit()


## Os dois discos (x, y do centro, raio): frente à esquerda, verso à direita. Divide a imagem
## na coluna com menos pixels opacos perto do meio; em cada lado, a altura dá o raio e a
## borda externa (esquerda da frente, direita do verso) dá o centro.
static func _find_discs(image: Image) -> Array[Vector3]:
	var w := image.get_width()
	var h := image.get_height()
	var columns := PackedInt32Array()
	columns.resize(w)
	for x in w:
		var count := 0
		for y in range(0, h, 2):
			if image.get_pixel(x, y).a > 0.5:
				count += 1
		columns[x] = count
	var split := w / 2
	for x in range(int(w * 0.3), int(w * 0.7)):
		if columns[x] < columns[split]:
			split = x
	var discs: Array[Vector3] = []
	for side in 2:
		var x0 := 0 if side == 0 else split
		var x1 := split if side == 0 else w
		var top := h
		var bottom := -1
		var outer := x1 if side == 0 else x0
		for y in h:
			for x in range(x0, x1):
				if image.get_pixel(x, y).a > 0.5:
					top = mini(top, y)
					bottom = maxi(bottom, y)
					outer = mini(outer, x) if side == 0 else maxi(outer, x)
		var r := (bottom - top + 1) * 0.5
		var cx := outer + r if side == 0 else outer + 1 - r
		discs.append(Vector3(cx, (top + bottom + 1) * 0.5, r))
	return discs


## Recorta o disco num quadrado FACE_SIZE; fora do círculo (ou dentro da outra moeda, que
## cobre a borda desta) fica transparente.
static func _cut_face(image: Image, disc: Vector3, other: Vector3) -> Image:
	var r := disc.z * (1.0 - EDGE_INSET)
	var face := Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	var scale := 2.0 * r / FACE_SIZE
	# Amostra direto da fonte (com média 2×2) para não depender do recorte retangular.
	for y in FACE_SIZE:
		for x in FACE_SIZE:
			var local := (Vector2(x, y) + Vector2(0.5, 0.5)) * scale - Vector2(r, r)
			if local.length() > r:
				continue
			var p := Vector2(disc.x, disc.y) + local
			if p.distance_to(Vector2(other.x, other.y)) < other.z and _covers(disc, other):
				continue
			var color := _sample(image, p, scale)
			if color.a > 0.0:
				face.set_pixel(x, y, color)
	return face


## A outra moeda está por cima desta? (a de cima é a que tem o disco inteiro opaco)
static func _covers(disc: Vector3, other: Vector3) -> bool:
	return Vector2(disc.x, disc.y).distance_to(Vector2(other.x, other.y)) < disc.z + other.z and other.x < disc.x


static func _sample(image: Image, p: Vector2, footprint: float) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	var step := maxf(footprint * 0.5, 0.5)
	for oy in [-0.5, 0.5]:
		for ox in [-0.5, 0.5]:
			var q := Vector2i(p + Vector2(ox, oy) * step)
			if q.x >= 0 and q.y >= 0 and q.x < image.get_width() and q.y < image.get_height():
				var c := image.get_pixelv(q)
				if c.a > 0.5:
					sum += Color(c.r, c.g, c.b, 1.0)
					n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0) if n > 0 else Color(0, 0, 0, 0)


## Cor média de um anel perto da borda da moeda (usada para preencher o fundo).
static func _rim_color(face: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	var c := FACE_SIZE / 2.0
	for i in 64:
		var angle := TAU * i / 64.0
		var p := Vector2(c, c) + Vector2.from_angle(angle) * c * 0.94
		var pixel := face.get_pixelv(Vector2i(p))
		if pixel.a > 0.9:
			sum += pixel
			count += 1
	return Color(sum.r / count, sum.g / count, sum.b / count, 1.0) if count > 0 else Color(0.7, 0.4, 0.25)


static func _blend_over(target: Image, overlay: Image, offset: Vector2i) -> void:
	for y in overlay.get_height():
		for x in overlay.get_width():
			var top := overlay.get_pixel(x, y)
			if top.a <= 0.0:
				continue
			var bottom := target.get_pixel(x + offset.x, y + offset.y)
			target.set_pixel(x + offset.x, y + offset.y, bottom.lerp(Color(top.r, top.g, top.b, 1.0), top.a))


static func _kb(path: String) -> int:
	return FileAccess.get_file_as_bytes(path).size() / 1024
