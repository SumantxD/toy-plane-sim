extends SceneTree
# Writes THIRD_PARTY_LICENSES.txt (Godot + bundled libraries and assets); every export preset ships it via include_filter.
# Run: godot --headless -s tools/make_licenses.gd
const TOON_MIT := """MIT License

Copyright (c) 2021 John Wigg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""


func _initialize() -> void:
	var out := "TOY PLANE ARCADE - THIRD-PARTY NOTICES\n\n"
	out += "Assets, Creative Commons Zero (CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/), no attribution required:\n"
	out += "- Kenney (www.kenney.nl): Nature Kit, Holiday Kit, City Kit Industrial, City Kit Suburban, Sci-Fi Sounds,\n  Impact Sounds, Interface Sounds, UI Pack (Kenney Future fonts).\n"
	out += "- \"Park Ambiences\" by Thimras, OpenGameArt (https://opengameart.org/content/park-ambiences): river and bird loops.\n\n"
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
	for f in [["godot-mqtt (goatchurchprime)", "res://addons/mqtt/LICENSE.md"],
			["webrtc-native", "res://addons/webrtc_native/LICENSE.webrtc-native"],
			["libdatachannel", "res://addons/webrtc_native/LICENSE.libdatachannel"],
			["libjuice", "res://addons/webrtc_native/LICENSE.libjuice"],
			["libsrtp", "res://addons/webrtc_native/LICENSE.libsrtp"],
			["usrsctp", "res://addons/webrtc_native/LICENSE.usrsctp"],
			["Mbed TLS", "res://addons/webrtc_native/LICENSE.mbedtls"],
			["plog", "res://addons/webrtc_native/LICENSE.plog"],
			["godot-storekit (araid80)", "res://tools/storekit/src/LICENSE"]]:
		var text := FileAccess.get_file_as_string(f[1])
		assert(not text.is_empty(), "missing " + f[1])
		out += "\n==== %s ====\n%s\n" % [f[0], text]
	out += "\n==== Flexible Toon Shader by John Wigg (CaptainProton42), Godot 4 port by atzuk4451 ====\n"
	out += "https://github.com/CaptainProton42/FlexibleToonShaderGD, https://github.com/atzuk4451/FlexibleToonShaderGD-4.0\n" + TOON_MIT
	var fa := FileAccess.open("res://THIRD_PARTY_LICENSES.txt", FileAccess.WRITE)
	fa.store_string(out)
	print("licenses: ", out.length(), " chars")
	quit()
