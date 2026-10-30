## Release builds: the export presets tools/export.sh and the release workflow use.
extends TestSuite


func presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	return cfg


## The preset section (e.g. "preset.1") with this name, or "".
func section(cfg: ConfigFile, preset_name: String) -> String:
	for s in cfg.get_sections():
		if not s.ends_with(".options") and cfg.get_value(s, "name", "") == preset_name:
			return s
	return ""


func test_windows_macos_and_web_presets() -> void:
	var cfg := presets()
	var want := {"Windows": "Windows Desktop", "macOS": "macOS", "Web": "Web"}
	for preset_name: String in want:
		var s := section(cfg, preset_name)
		check(s != "", "preset " + preset_name)
		if s == "":
			continue
		check(cfg.get_value(s, "platform") == want[preset_name], preset_name + " platform")
		var path: String = cfg.get_value(s, "export_path", "")
		check(path.begins_with("build/"), preset_name + " exports under build/ (gitignored)")
		var exclude: String = cfg.get_value(s, "exclude_filter", "")
		check(exclude.contains("tests/*"), preset_name + " leaves the tests out")


func test_builds_run_without_extra_setup() -> void:
	var cfg := presets()
	# One .exe, no loose .pck next to it.
	check(cfg.get_value(section(cfg, "Windows") + ".options", "binary_format/embed_pck") == true,
		"Windows embeds the pck")
	# No threads: plays from any static host (no COOP/COEP headers needed).
	check(cfg.get_value(section(cfg, "Web") + ".options", "variant/thread_support") == false,
		"Web build is single-threaded")
	# Ad-hoc signed, so Apple Silicon Macs will launch it.
	var mac := section(cfg, "macOS") + ".options"
	check(cfg.get_value(mac, "binary_format/architecture") == "universal", "macOS universal")
	check(cfg.get_value(mac, "codesign/codesign") == 1, "macOS ad-hoc signed")
	check(cfg.get_value(mac, "application/bundle_identifier", "") != "", "macOS bundle id")


func test_project_settings_the_exports_need() -> void:
	# The macOS exporter refuses universal/arm64 builds without it.
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc") == true,
		"ETC2/ASTC import on")
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	check(version.split(".").size() == 3, "config/version is x.y.z: " + version)
