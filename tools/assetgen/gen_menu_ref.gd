extends SceneTree
## Builds the main-menu / loading-screen background from the user's reference picture
## (assets/backgrounds/menu_reference_src.png): crops it to 16:9 (removing the baked-in
## loading bar) and upscales it to 1280x720 for crisp display at the 640x360 logical size.
## Usage: ... --script res://gen_menu_ref.gd -- [crop_top]
const PX = preload("res://px.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := Image.load_from_file(PX.out_root().path_join("backgrounds/menu_reference_src.png"))
	src.convert(Image.FORMAT_RGBA8)
	var trim := 5  # the source has a thin dark frame on the left and right
	var w := src.get_width() - trim * 2
	var h := int(round(w * 9.0 / 16.0))
	var top := int(args[0]) if args.size() > 0 else 77
	top = clampi(top, 0, src.get_height() - h)
	var crop := src.get_region(Rect2i(trim, top, w, h))
	crop.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	crop.save_png(PX.out_root().path_join("backgrounds/menu_bg_ref.png"))
	print("menu bg: crop rows ", top, "..", top + h, " of ", src.get_height())
	quit()
