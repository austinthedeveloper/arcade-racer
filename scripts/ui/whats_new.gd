class_name WhatsNew
extends RefCounted
## What's new (PR-17): after an update, the title screen shows the running version's
## CHANGELOG.md section once, as a list of what was added, changed and fixed (TitleScreen
## draws it). tools/export.sh bundles the section as BUNDLED (tools/changelog.py --json); a
## run from the editor or a checkout reads CHANGELOG.md itself. Settings.whats_new_seen keeps
## the last version shown, so each one shows once; a fresh install (no options or save file
## yet) has nothing to catch up on and only marks it seen.

const BUNDLED := "res://assets/whats_new.json"  # {"version", "notes"}, written at export
const CHANGELOG := "res://CHANGELOG.md"
const SHORT_MAX := 42  # characters an entry is cut to
const ROWS := 15  # the panel's rows in each column
const COLUMNS := 2

## Where the bundled notes are read from. Tests point it at a scratch file.
static var bundled := BUNDLED


## Whether the notes for `version` are due: not shown yet (`seen` is the last version that
## was) on an install that ran before (`existing`).
static func due(seen: String, version: String, existing: bool) -> bool:
	return version != "" and seen != version and existing


## The section for `version` in a CHANGELOG.md `text`, without its heading; a pre-release
## (0.5.0-beta) falls back to its base version's. "" when there is none. (tools/changelog.py's
## `notes`, for a run without the bundled file.)
static func section(text: String, version: String) -> String:
	var found := {}
	var name := ""
	var lines: PackedStringArray = []
	var named := false
	for line in text.split("\n"):
		if line.begins_with("## ["):
			if named:
				found[name] = "\n".join(lines).strip_edges()
			name = line.get_slice("[", 1).get_slice("]", 0)
			lines = []
			named = true
		elif named:
			lines.append(line)
	if named:
		found[name] = "\n".join(lines).strip_edges()
	for v in [version, version.get_slice("-", 0)]:
		if str(found.get(v, "")) != "":
			return found[v]
	return ""


## The notes for `version`: the bundled section when it is that version's, else CHANGELOG.md's.
static func notes(version: String) -> String:
	if FileAccess.file_exists(bundled):
		var data = JSON.parse_string(FileAccess.get_file_as_string(bundled))
		if data is Dictionary and str(data.get("version", "")) == version:
			return str(data.get("notes", ""))
	if FileAccess.file_exists(CHANGELOG):
		return section(FileAccess.get_file_as_string(CHANGELOG), version)
	return ""


## A changelog bullet cut to its name: the words before its first ": ", without the roadmap
## IDs in brackets ("Oncoming traffic (RC-11): on Palm Coast..." is "Oncoming traffic"), or
## its first sentence; at most SHORT_MAX characters.
static func short(bullet: String) -> String:
	var s := bullet.strip_edges()
	var colon := s.find(": ")
	if colon > 0:
		s = s.substr(0, colon)
	else:
		var stop := s.find(". ")
		if stop > 0:
			s = s.substr(0, stop)
		s = s.trim_suffix(".")
	var re := RegEx.create_from_string("\\s*\\([^)]*\\)")
	s = re.sub(s, "", true).strip_edges()
	if s.length() > SHORT_MAX:
		s = s.substr(0, SHORT_MAX - 3).strip_edges() + "..."
	return s


## A section's notes as the panel lists them: [true, "ADDED"] for a heading, [false, name]
## for each entry (short), in order.
static func items(section_notes: String) -> Array:
	var out: Array = []
	var bullet := ""
	for raw in section_notes.split("\n") + PackedStringArray([""]):
		var line := raw.strip_edges()
		var ends := line == "" or line.begins_with("#") or line.begins_with("- ") or line.begins_with("* ")
		if ends and bullet != "":
			out.append([false, short(bullet)])
			bullet = ""
		if line.begins_with("#"):
			out.append([true, line.lstrip("#").strip_edges().to_upper()])
		elif line.begins_with("- ") or line.begins_with("* "):
			bullet = line.substr(2)
		elif line != "" and bullet != "":
			bullet += " " + line
	return out


## Where each item goes on the panel: [column, row, item], down the first column then the
## next, ROWS to a column. What doesn't fit is left off, and the last slot says how many
## more there are ([column, row, [false, "...AND N MORE"]]).
static func layout(list: Array, rows := ROWS, columns := COLUMNS) -> Array:
	var slots := rows * columns
	var out: Array = []
	var shown := list.size() if list.size() <= slots else slots - 1
	for i in shown:
		out.append([i / rows, i % rows, list[i]])
	if shown < list.size():
		var more := 0
		for i in range(shown, list.size()):
			more += 0 if list[i][0] else 1
		out.append([shown / rows, shown % rows, [false, "...AND %d MORE" % more]])
	return out


## On the title: the running version's notes when they are due (items), marking them seen
## and saving the options. Empty when not due, or when there are none to show.
static func take() -> Array:
	var version := Updater.version()
	if Settings.whats_new_seen == version:
		return []
	var existing := Settings.had_file or FileAccess.file_exists(SaveData.path)
	var show := due(Settings.whats_new_seen, version, existing)
	Settings.whats_new_seen = version
	Settings.save()
	return items(notes(version)) if show else []
