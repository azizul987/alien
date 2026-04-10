extends Control

@onready var pause_menu = $CanvasLayer/Control
@onready var point: Label = $CanvasLayer2/Point

@onready var dokumen_panel = $CanvasLayer3/DokumenPanel
@onready var isi_teks_dokumen: RichTextLabel = $"CanvasLayer3/DokumenPanel/Isi Teks Dokuemen"

var score: int = 0
var dokumen_terbuka: bool = false

var dokumen := {
	1: "[center][font_size=22][b]BRIEFING OPERATIF[/b][/font_size][/center]\n\n" +
	   "[b]Klasifikasi:[/b] Terbatas\n" +
	   "[b]Operatif:[/b] Rael\n\n" +
	   "Investigasi awal mengindikasikan keberadaan [color=red][b]entitas non-manusia[/b][/color] " +
	   "yang mampu menyamar di antara populasi sipil.\n\n" +
	   "[color=yellow][b]Tidak semua orang bisa dipercaya.[/b][/color]\n" +
	   "Jangan beri tahu siapa pun metode identifikasi yang kamu gunakan.\n" +
	   "Jika mereka tahu kamu bisa mengenali mereka, [color=red][b]kamu akan diburu.[/b][/color]\n\n" +
	   "Gunakan [color=lime][b]sinyal UV[/b][/color] untuk memeriksa area.\n" +
	   "Subjek akan meninggalkan [color=green][b]jejak kaki hijau[/b][/color] saat terkena paparan UV.\n\n" +
	   "Laporan awal menunjukkan jejak mengarah ke [b]jalan desa lama[/b].\n" +
	   "[i]Tujuan berikutnya: Desa.[/i]",

	2: "[center][font_size=22][b]LAPORAN LAPANGAN[/b][/font_size][/center]\n\n" +
	   "Unit pengawas menemukan pola jejak hijau di luar perimeter fasilitas.\n" +
	   "Jejak bergerak melewati pagar timur dan terus turun ke jalur sempit menuju desa.\n\n" +
	   "Beberapa warga terlihat tetap beraktivitas normal di siang hari, " +
	   "namun laporan malam menunjukkan perilaku diam, berdiri lama, dan pergerakan berkelompok.\n\n" +
	   "[color=yellow]Jangan dekati siapa pun terlalu cepat. Amati. Periksa dengan UV. Ikuti jejak.[/color]",

	3: "[center][font_size=22][b]CATATAN WARGA[/b][/font_size][/center]\n\n" +
	   "Lampu rumah padam hampir bersamaan tadi malam.\n" +
	   "Aku lihat beberapa orang berdiri di jalan tanpa bicara sedikit pun.\n" +
	   "Saat kusorot dengan lampu biasa, tidak ada yang aneh.\n" +
	   "Tapi di tanah dekat sumur ada bekas langkah berwarna aneh...\n\n" +
	   "[color=green][b]Hijau.[/b][/color]\n\n" +
	   "Mereka menuju balai desa.",

	4: "[center][font_size=22][b]FILE ANOMALI[/b][/font_size][/center]\n\n" +
	   "Seluruh jejak yang terlacak di desa berujung pada pusat aktivitas biologis di bawah area pemukiman.\n" +
	   "Kemungkinan terdapat inti jaringan atau pusat sinkronisasi di bawah tanah.\n\n" +
	   "Jika jejak menghilang di permukaan, cari akses bawah tanah terdekat.\n" +
	   "[color=red][b]Sumber utama harus ditemukan dan dihentikan.[/b][/color]"
}

func _ready() -> void:
	pause_menu.visible = false
	dokumen_panel.visible = false
	isi_teks_dokumen.bbcode_enabled = true
	update_point_label()

func _process(_delta: float) -> void:
	# Pause menu tidak boleh dibuka saat dokumen terbuka
	if Input.is_action_just_pressed("pause") and !dokumen_terbuka:
		toggle_pause()

	# Tutup dokumen pakai tombol lain agar tidak bentrok dengan tombol interact
	# Pastikan action "ui_cancel" ada di Input Map
	if Input.is_action_just_pressed("ui_cancel") and dokumen_terbuka:
		tutup_dokumen()

func toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		pause_menu.visible = false
	else:
		get_tree().paused = true
		pause_menu.visible = true

func on_press_lanjut() -> void:
	toggle_pause()

func on_press_keluar() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://asset/scene/main_menu.tscn")

func add_score(amount: int) -> void:
	score += amount
	update_point_label()

func update_point_label() -> void:
	point.text = "POINT: " + str(score)

func set_score(value: int) -> void:
	score = value
	update_point_label()

func buka_dokumen(id: int) -> void:
	print("buka_dokumen dipanggil, id =", id)

	if dokumen_terbuka:
		print("Dokumen sudah terbuka")
		return

	if !dokumen.has(id):
		print("ID dokumen tidak ada:", id)
		return

	dokumen_terbuka = true
	dokumen_panel.visible = true
	isi_teks_dokumen.clear()
	isi_teks_dokumen.text = dokumen[id]

	print("Dokumen berhasil dibuka")

func tutup_dokumen() -> void:
	if !dokumen_terbuka:
		return

	dokumen_terbuka = false
	dokumen_panel.visible = false
	isi_teks_dokumen.clear()

	print("Dokumen ditutup")

func is_dokumen_open() -> bool:
	return dokumen_terbuka

func close_dokumen() -> void:
	dokumen_terbuka = false
	$CanvasLayer3/DokumenPanel.hide()
	get_tree().paused = false
