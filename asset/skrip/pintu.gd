extends Node2D

@onready var sprite_pintu: Node2D = $Pintuup
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var area_interact: Area2D = $Area2D
@onready var suara_pintu: AudioStreamPlayer2D = $"Suara Pintu"

@export var perlu_skor: bool = false
@export var skor_minimum: int = 100
@export var tampilkan_pesan_kurang_skor: bool = true

var terbuka: bool = false
var sedang_bergerak: bool = false
var player_dekat: bool = false
var player_ref: Node = null

# ini penting:
# kalau true, berarti syarat skor sudah pernah berhasil dipenuhi
# jadi sesudah itu pintu bebas dipakai buka-tutup
var syarat_sudah_terpakai: bool = false


func _process(_delta: float) -> void:
	if player_dekat and Input.is_action_just_pressed("interact"):
		coba_buka_pintu()


func coba_buka_pintu() -> void:
	if sedang_bergerak:
		return

	if terbuka:
		open_or_close()
		return

	if perlu_skor:
		var skor_player := get_skor_player()

		if skor_player < skor_minimum:
			if tampilkan_pesan_kurang_skor:
				tampilkan_info_skor_kurang(skor_player)
			print("Pintu terkunci | skor sekarang: ", skor_player, " | butuh: ", skor_minimum)
			return
	open_or_close()


func get_skor_player() -> int:
	if player_ref == null:
		return 0

	if player_ref.has_method("get_score"):
		return int(player_ref.get_score())

	# cadangan kalau kamu lupa tambah get_score() di player
	if "total_score" in player_ref:
		return int(player_ref.total_score)

	return 0


func tampilkan_info_skor_kurang(skor_player: int) -> void:
	var kurang := skor_minimum - skor_player
	var pesan := "Skor kurang! -" + str(kurang)

	if player_ref != null and player_ref.has_method("show_floating_text"):
		player_ref.show_floating_text(pesan, Color.RED)
	else:
		print(pesan)


func open_or_close() -> void:
	if sedang_bergerak:
		return

	sedang_bergerak = true

	if suara_pintu != null:
		suara_pintu.play()

	var target_rotation := 0.0

	if !terbuka:
		target_rotation = deg_to_rad(90)
		if body_collision != null:
			body_collision.disabled = true
	else:
		target_rotation = deg_to_rad(0)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_pintu, "rotation", target_rotation, 0.5)

	await tween.finished

	terbuka = !terbuka

	if !terbuka:
		if body_collision != null:
			body_collision.disabled = false

	sedang_bergerak = false


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_dekat = true
		player_ref = body

		# opsional, kalau kamu punya tanda interact
		if body.get_child_count() > 5 and body.get_child(5).has_method("show_tanda"):
			body.get_child(5).show_tanda()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_dekat = false

		if player_ref == body:
			player_ref = null

		# opsional, kalau kamu punya tanda interact
		if body.get_child_count() > 5 and body.get_child(5).has_method("hide_tanda"):
			body.get_child(5).hide_tanda()
