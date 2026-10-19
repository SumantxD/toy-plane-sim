extends SceneTree
# Writes THIRD_PARTY_LICENSES.txt (Godot + bundled libraries). Run: godot --headless -s tools/make_licenses.gd
func _initialize() -> void:
	var out := "TOY PLANE SIM - THIRD-PARTY NOTICES\n\n"
	out += "Kenney assets (models, sounds, UI font): Creative Commons Zero (CC0), kenney.nl - no attribution required.\n"
	out += "libdatachannel and libjuice are MPL-2.0; source: https://github.com/paullouisageneau/libdatachannel and https://github.com/paullouisageneau/libjuice\n\n"
	out += "==== Godot Engine ====\n" + Engine.get_license_text() + "\n"
	for part in Engine.get_copyright_info():
		out += "\n---- %s ----\n" % part.name
		for p in part.parts:
			out += "Files: %s\nCopyright: %s\nLicense: %s\n" % [", ".join(p.files), "; ".join(p.copyright), p.license]
	out += "\n==== Third-party licenses used by Godot ====\n"
	var info := Engine.get_license_info()
	for k in info:
		out += "\n---- %s ----\n%s\n" % [k, info[k]]
	for f in ["res://addons/mqtt/LICENSE.md", "res://addons/webrtc_native/LICENSE.webrtc-native", "res://addons/webrtc_native/LICENSE.libdatachannel", "res://addons/webrtc_native/LICENSE.libjuice", "res://addons/webrtc_native/LICENSE.libsrtp", "res://addons/webrtc_native/LICENSE.usrsctp", "res://addons/webrtc_native/LICENSE.mbedtls", "res://addons/webrtc_native/LICENSE.plog"]:
		out += "\n==== %s ====\n%s\n" % [f.get_file(), FileAccess.get_file_as_string(f)]
	out += "\n==== Flexible Toon Shader (atzuk4451) - MIT ====\nhttps://github.com/atzuk4451/FlexibleToonShaderGD-4.0\n"
	var fa := FileAccess.open("res://THIRD_PARTY_LICENSES.txt", FileAccess.WRITE)
	fa.store_string(out)
	print("licenses: ", out.length(), " chars")
	quit()
