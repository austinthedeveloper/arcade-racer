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


func test_windows_macos_web_and_linux_presets() -> void:
	var cfg := presets()
	var want := {"Windows": "Windows Desktop", "macOS": "macOS", "Web": "Web", "Linux": "Linux"}
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
	# Linux: one x86_64 binary, no loose .pck.
	var lin := section(cfg, "Linux") + ".options"
	check(cfg.get_value(lin, "binary_format/embed_pck") == true, "Linux embeds the pck")
	check(cfg.get_value(lin, "binary_format/architecture") == "x86_64", "Linux x86_64")
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


func test_every_build_has_the_game_icon() -> void:
	# tools/make_icon.py writes all three; the window and the Web build use the project's.
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	eq(icon, "res://icon.png", "project icon")
	check(load(icon) is Texture2D, "the project icon loads")
	var cfg := presets()
	var win := section(cfg, "Windows") + ".options"
	eq(cfg.get_value(win, "application/icon", ""), "res://icon.ico", "Windows icon")
	# Off, the .exe keeps Godot's icon and has no version strings.
	check(cfg.get_value(win, "application/modify_resources") == true, "Windows writes its resources")
	eq(cfg.get_value(section(cfg, "macOS") + ".options", "application/icon", ""), "res://icon.icns", "macOS icon")
	check(cfg.get_value(section(cfg, "Web") + ".options", "html/export_icon") == true, "Web favicon")
	for f in ["res://icon.png", "res://icon.ico", "res://icon.icns"]:
		check(FileAccess.file_exists(f), f + " exists")


## The release workflow takes its notes from CHANGELOG.md (tools/changelog.py) and refuses a
## tag without them, so the version being released must already have its section.
func test_changelog_describes_this_version() -> void:
	var text := FileAccess.get_file_as_string("res://CHANGELOG.md")
	check(text != "", "CHANGELOG.md is readable")
	var headings: Array[String] = []
	for line in text.split("\n"):
		if line.begins_with("## ["):
			headings.append(line.get_slice("[", 1).get_slice("]", 0))
	check(not headings.is_empty() and headings[0] == "Unreleased", "Unreleased is the first section")
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	check(version in headings, "CHANGELOG.md has a section for config/version " + version)
	for i in range(1, headings.size()):
		var line := "## [%s] - " % headings[i]
		check(text.contains(line), headings[i] + " has a date")


## What's new (PR-17): the export bundles this version's section for the title, where the
## game reads it (WhatsNew.BUNDLED), and takes it away again after.
func test_export_bundles_whats_new() -> void:
	var export_sh := FileAccess.get_file_as_string("res://tools/export.sh")
	check(export_sh.contains("tools/changelog.py --json \"$version\" >" + WhatsNew.BUNDLED.trim_prefix("res://")),
		"export.sh writes the notes where WhatsNew reads them")
	check(export_sh.contains("rm -f " + WhatsNew.BUNDLED.trim_prefix("res://")), "and removes them after")
	check(FileAccess.get_file_as_string("res://.gitignore").contains(WhatsNew.BUNDLED.trim_prefix("res://")),
		"never committed")
	for preset in ["Windows", "macOS", "Web", "Linux"]:
		var filter: String = presets().get_value(section(presets(), preset), "exclude_filter", "")
		check(not filter.contains("assets"), preset + " exports assets/")


## A tag's Web build goes to Azure (tools/deploy_web.sh, the release workflow's web job). The
## job may only run for a tag, in the "web" environment its Azure sign-in trusts, and must
## deploy the zip tools/export.sh names.
func test_tag_deploys_the_web_build() -> void:
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	var web := workflow.get_slice("\n  web:\n", 1)
	check(web != "", "release.yml has a web job")
	check(web.contains("needs: build") and web.contains("if: github.ref_type == 'tag'"),
		"after the build, for a tag only")
	check(web.contains("name: web") and web.contains("id-token: write"),
		"in the web environment, signing in with OIDC")
	check(web.contains("tools/deploy_web.sh \"build/release/SundownRun-${{ needs.build.outputs.version }}-web.zip\""),
		"deploys export.sh's web zip")
	var export_sh := FileAccess.get_file_as_string("res://tools/export.sh")
	check(export_sh.contains("SundownRun-$version-web.zip"), "export.sh writes that zip")
	check(FileAccess.file_exists("res://tools/deploy_web.sh"), "tools/deploy_web.sh exists")
