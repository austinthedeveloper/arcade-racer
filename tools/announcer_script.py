#!/usr/bin/env python3
"""The announcer's script for the voiceover: every line, grouped by when the race says it.
Writes docs/announcer/SCRIPT.md (to read and record from) and docs/announcer/lines.csv (one
row per file, for batching in the voiceover tool). The voice itself is docs/announcer/VOICE.md.

The lines the game says today are Announcer.LINES (scripts/audio/announcer.gd): they keep
their ids and words here, so their recordings drop straight in (tools/prep_announcer.py).
The rest are marked "to wire": recorded now, said once the race has a reason to say them.

Run: python3 tools/announcer_script.py [--check]   (--check: fail if the files are stale)
"""
import csv
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "announcer")

# Delivery shorthands: how each line is said (VOICE.md has the voice they are all in).
HYPE = "Big and bright, a grin in it. Arcade cabinet energy."
PUNCH = "Quick and punchy, one breath, under a second."
WARM = "Warm and easy, like a friend in the passenger seat."
COOL = "Cool and smooth, late-night radio."
TENSE = "Urgent, leaning in. The clock is the enemy."
WRY = "Dry and playful; let the joke land, don't push it."
KIND = "Sympathetic, kind, a 'next time' feel. Never mocking."
CALL = "Clear and even, like the starter calling it."

G = []  # (group, when, [(id, text, delivery, max_seconds)])


def group(name, when, lines):
    G.append((name, when, lines))


group("Title and attract", "On the title screen as the logo lands, and now and then over the demo.", [
    ("title_1", "Sundown Run!", HYPE, 1.5),
    ("title_2", "This is Sundown Run!", HYPE, 2),
    ("title_press_start", "Press start, and hit the road.", WARM, 2.5),
    ("demo_1", "The sun's going down, and the road is wide open.", COOL, 3.5),
    ("demo_2", "Eight stages, one clock, and nobody's stopping.", COOL, 3.5),
    ("demo_3", "Your turn. Grab the wheel.", WARM, 2),
])

group("The start", "On the grid before the countdown, the countdown itself, GO, and a launch off the line.", [
    ("ready", "Engines ready. Here we go!", HYPE, 2.5),
    ("ready_2", "Start your engines!", HYPE, 2),
    ("ready_3", "Hands on the wheel. Eyes on the road.", COOL, 2.5),
    ("count_3", "Three!", CALL, 0.8),
    ("count_2", "Two!", CALL, 0.8),
    ("count_1", "One!", CALL, 0.8),
    ("go", "Go, go, go!", HYPE, 1.5),
    ("go_2", "Go!", PUNCH, 0.8),
    ("go_3", "Floor it!", PUNCH, 1),
    ("launch", "What a launch!", HYPE, 1.5),
    ("launch_2", "Perfect start!", HYPE, 1.2),
    ("launch_3", "Out of the gate like a rocket!", HYPE, 2),
])

group("Stages", "As a stage begins, once, after the countdown's first beat (one of the two).", [
    ("stage_palm_coast_1", "Welcome to Palm Coast Boulevard! Sun, surf, and six lanes through town.", HYPE, 4.5),
    ("stage_palm_coast_2", "Palm Coast. Windows down, radio up.", COOL, 3),
    ("stage_redrock_1", "Redrock Canyon! Open desert, big air, and a canyon that bites.", HYPE, 4.5),
    ("stage_redrock_2", "Out in the desert now. Watch the road pinch in the canyon.", WARM, 4),
    ("stage_neon_1", "The Neon Strip! The brightest, busiest road in the game.", HYPE, 4),
    ("stage_neon_2", "Midnight on the Strip. Every light in town is on.", COOL, 3.5),
    ("stage_timberline_1", "Timberline Pass! Up into the pines, and over the summit.", HYPE, 4),
    ("stage_timberline_2", "Snow on the summit today. Easy on the grip.", WARM, 3.5),
    ("stage_bayou_1", "Bayou Causeway! Long roads over open water.", HYPE, 3.5),
    ("stage_bayou_2", "Dawn on the bayou. Mind the fog, and mind the gators.", WRY, 4),
    ("stage_harvest_1", "Harvest Valley! Rolling hills and golden fields.", HYPE, 3.5),
    ("stage_harvest_2", "Out in the farm country. Hold on over those crests.", WARM, 3.5),
    ("stage_thunder_1", "Thunderhead Highway! There's a storm on the way.", HYPE, 3.5),
    ("stage_thunder_2", "Rain on the road and lightning in the sky. Stay sharp.", TENSE, 3.5),
    ("stage_skyline_1", "The Skyline Finale! The last road, and the longest.", HYPE, 4),
    ("stage_skyline_2", "Downtown, top of the world. This is it.", COOL, 3),
    ("stage_mirror", "Mirror mode! Everything's the other way round.", WRY, 3),
])

group("Checkpoints and the clock", "At a checkpoint, as time is added, the last checkpoint, and when the clock runs low or out.", [
    ("checkpoint", "Checkpoint!", PUNCH, 1),
    ("checkpoint_2", "Checkpoint! Keep it going!", HYPE, 1.8),
    ("checkpoint_3", "Made it!", PUNCH, 0.8),
    ("time_extended", "Time extended!", HYPE, 1.5),
    ("time_extended_2", "More time on the clock!", HYPE, 1.8),
    ("last_checkpoint", "Last checkpoint! The finish is up ahead!", HYPE, 2.5),
    ("hurry", "Hurry up!", TENSE, 1),
    ("hurry_2", "The clock's running out!", TENSE, 1.8),
    ("hurry_3", "Come on, come on, come on!", TENSE, 1.5),
    ("ten_seconds", "Ten seconds!", TENSE, 1),
    ("time_up", "Out of time!", KIND, 1.5),
    ("time_up_2", "Time's up. So close.", KIND, 2),
])

group("Driving", "During the race, for the moment it calls; never two within a second or two.", [
    ("near_miss", "Whoa, close one!", HYPE, 1.5),
    ("near_miss_2", "Too close!", PUNCH, 1),
    ("near_miss_3", "Threaded the needle!", HYPE, 1.5),
    ("near_miss_chain", "Another one! You're on fire!", HYPE, 2),
    ("big_air", "Big air!", PUNCH, 1),
    ("big_air_2", "Look at that hang time!", HYPE, 1.8),
    ("big_air_3", "Airborne!", PUNCH, 1),
    ("final_stretch", "Final stretch! Bring it home!", HYPE, 2),
    ("final_stretch_2", "Home stretch! Everything you've got!", HYPE, 2.2),
    ("slipstream", "In the slipstream!", PUNCH, 1.2),
    ("slingshot", "Slingshot!", PUNCH, 1),
    ("nitro", "Nitro!", PUNCH, 0.8),
    ("power_slide", "Power slide!", PUNCH, 1),
    ("crash_1", "Ooh. That one's going to leave a mark.", WRY, 2.2),
    ("crash_2", "Shake it off! Get back out there!", WARM, 2),
    ("crash_3", "Back on your wheels!", WARM, 1.2),
    ("off_road", "Back on the road!", WARM, 1.2),
])

group("Position", "When the player takes the lead, loses it, or passes a rival.", [
    ("first_place", "You have the lead!", HYPE, 1.5),
    ("first_place_2", "Out in front!", HYPE, 1.2),
    ("first_place_3", "Number one, and pulling away!", HYPE, 2),
    ("lost_lead", "They've taken the lead! Get it back!", TENSE, 2),
    ("passed_rival", "Got 'em!", PUNCH, 0.8),
    ("passed_rival_2", "One more down!", PUNCH, 1.2),
    ("rival_behind", "Somebody's right on your bumper!", TENSE, 1.8),
])

group("Power-ups", "As the player picks one up (the mystery box says the one it gave).", [
    ("pickup_nitro", "Nitro on board!", HYPE, 1.2),
    ("pickup_clock", "Extra time!", HYPE, 1),
    ("pickup_ram", "Battering ram! Clear the road!", HYPE, 2),
    ("pickup_ghost", "Ghost mode! Drive right through them!", WRY, 2.2),
])

group("The finish", "Over the line, by place (no rivals: just finished), then a best time or a medal.", [
    ("finish_1", "You win! What a drive!", HYPE, 2),
    ("finish_1_2", "Checkered flag! You win!", HYPE, 2),
    ("finish_1_3", "First place! Nobody could touch you!", HYPE, 2.2),
    ("finish_2", "Second place! So close!", WARM, 1.8),
    ("finish_2_2", "Second! Just a little more next time.", WARM, 2.2),
    ("finish_3", "Third! You made the podium!", WARM, 1.8),
    ("finish_3_2", "Third place, and up on the podium!", WARM, 2),
    ("finish", "Finished! Go again for the podium.", KIND, 2.2),
    ("finish_off_podium", "Off the podium this time. You'll get them next run.", KIND, 3),
    ("photo_finish", "Photo finish!", HYPE, 1.2),
    ("new_record", "A new best time!", HYPE, 1.5),
    ("medal_gold", "That's gold!", HYPE, 1),
    ("medal_silver", "Silver!", HYPE, 0.8),
    ("medal_bronze", "Bronze!", WARM, 0.8),
])

group("The Grand Tour", "At the tour's start, between stages, and at its end.", [
    ("tour_start", "The Grand Tour starts here. Eight stages, one champion.", HYPE, 4),
    ("tour_next", "On to the next stage!", HYPE, 1.5),
    ("tour_leading", "You're leading the Grand Tour!", HYPE, 2),
    ("tour_final_stage", "The last stage. The whole tour comes down to this.", TENSE, 3.5),
    ("tour_champion", "Champion of the Grand Tour! What a drive!", HYPE, 3),
    ("tour_runner_up", "Second overall. A tour to be proud of.", WARM, 3),
])

group("Modes and menus", "As a mode starts, and at the pause menu.", [
    ("mode_time_attack", "Time Attack. Just you and the clock.", COOL, 2.5),
    ("mode_free_drive", "Free Drive. No clock, no rush. Enjoy the view.", COOL, 3),
    ("mode_online", "Online race! Let's see who's fastest.", HYPE, 2.5),
    ("rematch", "Rematch!", HYPE, 1),
    ("pause", "Taking a breather.", WARM, 1.5),
    ("resume", "Back to it!", WARM, 1),
])


def game_lines():
    """{id: words} from Announcer.LINES, the lines the game says today."""
    src = open(os.path.join(ROOT, "scripts", "audio", "announcer.gd")).read()
    block = src[src.index("const LINES := {"):]
    block = block[:block.index("}")]
    return dict(re.findall(r'"(\w+)": "([^"]*)"', block))


def rows():
    said = game_lines()
    out = []
    for name, when, lines in G:
        for line_id, text, delivery, seconds in lines:
            out.append({"id": line_id, "file": "vo_%s.wav" % line_id, "text": text, "delivery": delivery,
                        "max_seconds": seconds, "group": name, "status": "said" if line_id in said else "to wire"})
    return out


def problems():
    """What is wrong with the script: an id twice, or a line the game says that is missing or reworded."""
    out = []
    seen = set()
    for r in rows():
        if r["id"] in seen:
            out.append("%s is in the script twice" % r["id"])
        seen.add(r["id"])
        if not re.fullmatch(r"[a-z0-9_]+", r["id"]):
            out.append("%s: ids are lowercase letters, digits and _" % r["id"])
    by_id = {r["id"]: r for r in rows()}
    for line_id, words in game_lines().items():
        if line_id not in by_id:
            out.append("Announcer.LINES has %s, which the script doesn't" % line_id)
        elif by_id[line_id]["text"] != words:
            out.append("%s: the game says %r, the script %r" % (line_id, words, by_id[line_id]["text"]))
    return out


def script_md():
    all_rows = rows()
    said = sum(1 for r in all_rows if r["status"] == "said")
    s = io.StringIO()
    s.write("# The announcer: script for the voiceover\n\n")
    s.write("Written by `tools/announcer_script.py`; edit that, not this. The voice, and the instructions\n"
            "to give the voiceover tool, are [VOICE.md](VOICE.md). **%d lines**; the same list is\n"
            "[lines.csv](lines.csv), one row per file, for batching.\n\n" % len(all_rows))
    s.write("**Said** lines (%d) are the ones the race says today: record them first, they drop straight\n"
            "in. **To wire** lines (%d) are recorded now and said once the race has a reason to\n"
            "(variants it picks between, the stage intros, the countdown, and the rest).\n\n" % (said, len(all_rows) - said))
    s.write("## For the recording\n\n")
    s.write("- **One file per line**, named by its file column: `vo_go.wav`. All in one folder.\n"
            "- **WAV, 24 kHz or 48 kHz, 16-bit, mono.** No music or effects; the game adds its own.\n"
            "- **Trim the silence** to within 50 ms before the first sound and 100 ms after the last:\n"
            "  the game times the lines and ducks the music for exactly as long as one lasts.\n"
            "- **Even loudness**, about -16 LUFS each, peaks under -1 dBFS.\n"
            "  `tools/prep_announcer.py` evens them out anyway, but a steady take sounds better.\n"
            "- **One voice and one setting for every line** (VOICE.md). The countdown numbers above all\n"
            "  must sound like one call.\n"
            "- **Mind the length**: each line has a most-seconds. The driving lines have to land between\n"
            "  one moment and the next, so the short ones matter most.\n"
            "- The words are written as they should be said. If one comes out wrong, respell it in the\n"
            "  tool and keep the id; the game shows the words as written here as the subtitle.\n"
            "- Variants (`_2`, `_3`) are alternatives the game picks between, so give each a slightly\n"
            "  different read too.\n\n")
    s.write("Then: `python3 tools/prep_announcer.py <folder>` levels them and puts the said lines in the\n"
            "game (`assets/audio/sfx/`).\n\n")
    for name, when, lines in G:
        s.write("## %s\n\n*%s*\n\n" % (name, when))
        s.write("| id | line | delivery | max s | |\n|---|---|---|---|---|\n")
        for line_id, text, delivery, seconds in lines:
            status = "said" if line_id in game_lines() else "to wire"
            s.write("| `%s` | %s | %s | %g | %s |\n" % (line_id, text, delivery, seconds, status))
        s.write("\n")
    return s.getvalue()


def lines_csv():
    s = io.StringIO()
    w = csv.DictWriter(s, ["id", "file", "text", "delivery", "max_seconds", "group", "status"], lineterminator="\n")
    w.writeheader()
    for r in rows():
        w.writerow(dict(r, max_seconds="%g" % r["max_seconds"]))
    return s.getvalue()


def main():
    bad = problems()
    if bad:
        sys.exit("\n".join(bad))
    files = {"SCRIPT.md": script_md(), "lines.csv": lines_csv()}
    if "--check" in sys.argv:
        stale = [n for n, text in files.items()
                 if not os.path.exists(os.path.join(OUT, n)) or open(os.path.join(OUT, n)).read() != text]
        if stale:
            sys.exit("stale: %s (python3 tools/announcer_script.py)" % ", ".join(stale))
        print("the announcer's script is up to date")
        return
    os.makedirs(OUT, exist_ok=True)
    for n, text in files.items():
        open(os.path.join(OUT, n), "w").write(text)
    r = rows()
    print("%d lines (%d said today, %d to wire) -> docs/announcer/" % (
        len(r), sum(1 for x in r if x["status"] == "said"), sum(1 for x in r if x["status"] != "said")))


if __name__ == "__main__":
    main()
