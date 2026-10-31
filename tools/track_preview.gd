## Plots every stage (or one) top-down and in side elevation to PNG, for authoring (TrackPlot).
##
##   godot --headless --path . -s res://tools/track_preview.gd -- --out=/tmp/plots [--stage=3]
##
## Writes <out>/stage_<n>_<postcard name>.png, one per stage.
extends SceneTree


func _init() -> void:
	var out := "user://track_preview"
	var only := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--stage="):
			only = int(arg.get_slice("=", 1)) - 1
	DirAccess.make_dir_recursive_absolute(out)
	var status := 0
	for i in Stages.count():
		if only >= 0 and i != only:
			continue
		var track := Stages.build(i)
		var path := "%s/stage_%d_%s.png" % [out, i + 1, Stages.POSTCARDS[i]]
		var err := TrackPlot.render(track, "%d. %s" % [i + 1, track.name]).save_png(path)
		print(("wrote " if err == OK else "FAILED ") + path)
		if err != OK:
			status = 1
	quit(status)
