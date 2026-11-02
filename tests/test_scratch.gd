## The per-run scratch folder (EQ-18) and the guard on deleting it.
extends TestSuite


func test_only_paths_inside_the_test_runs_folder_may_be_deleted() -> void:
	for bad in ["", "res://", "user://", TEST_RUNS, "user://test_runs", "user://save.cfg",
			"/Users", TEST_RUNS + "../", TEST_RUNS + "1/../../x"]:
		check(not is_test_run_path(bad), "refuses '%s'" % bad)
	check(is_test_run_path(run_dir), "this run's folder")
	check(is_test_run_path(scratch("ghosts")), "a scratch path")


func test_remove_tree_deletes_a_scratch_folder() -> void:
	var dir := scratch("tree/inner")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir.path_join("a.txt"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	remove_tree(scratch("tree"))
	check(not DirAccess.dir_exists_absolute(scratch("tree")), "gone")
	check(DirAccess.dir_exists_absolute(run_dir), "the run's folder stays")
