"""tools/tuning_adopt.py (EQ-17) on the fixture override file tests/fixtures/tuning_override.cfg."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tuning_adopt  # noqa: E402

FIXTURE = os.path.join(tuning_adopt.ROOT, "tests", "fixtures", "tuning_override.cfg")


class TuningAdoptTest(unittest.TestCase):
    def setUp(self):
        with open(tuning_adopt.TUNING_GD) as f:
            self.source = f.read()
        self.table = tuning_adopt.parse_table(self.source)
        with open(FIXTURE) as f:
            self.overrides = tuning_adopt.parse_overrides(f.read())

    def test_reads_every_row_of_the_table(self):
        rows = sum(1 for line in self.source.split("\n") if line.startswith('\t"') and '": [' in line)
        self.assertEqual(len(self.table), rows)
        self.assertEqual(self.table["driving/steer_rate"]["default"], 2.2)
        self.assertTrue(self.table["scoring/near_miss"]["whole"])
        self.assertFalse(self.table["driving/gravity"]["whole"])

    def test_plans_the_fixture(self):
        changes, skipped = tuning_adopt.plan(self.table, self.overrides)
        self.assertEqual([k for k, _, _ in changes],
                         ["driving/steer_rate", "draft/speed_mult", "scoring/near_miss", "camera/shake_crash"])
        self.assertEqual(skipped, ["gone/old_value"])
        after = dict((k, a) for k, _, a in changes)
        self.assertEqual(after["camera/shake_crash"], 15.0, "clamped to its range as the game does")
        changes, _ = tuning_adopt.plan(self.table, self.overrides, {"draft/speed_mult"})
        self.assertEqual([k for k, _, _ in changes], ["draft/speed_mult"])

    def test_rewrites_only_the_defaults(self):
        changes, _ = tuning_adopt.plan(self.table, self.overrides)
        out = tuning_adopt.rewrite(self.source, self.table, changes)
        new = tuning_adopt.parse_table(out)
        self.assertEqual(new["driving/steer_rate"]["default"], 2.5)
        self.assertEqual(new["scoring/near_miss"]["default"], 2.0)
        self.assertTrue(new["scoring/near_miss"]["whole"], "points stay ints")
        self.assertEqual(new["driving/steer_rate"]["max"], self.table["driving/steer_rate"]["max"])
        self.assertIn('"driving/steer_rate": [2.5, 1.0, 4.0, 0.05,', out)
        self.assertEqual(len(out.split("\n")), len(self.source.split("\n")))
        self.assertEqual(new["driving/gravity"], self.table["driving/gravity"], "the rest untouched")

    def test_report(self):
        changes, _ = tuning_adopt.plan(self.table, self.overrides)
        lines = tuning_adopt.report(self.table, changes).split("\n")
        self.assertEqual(len(lines), 2 + len(changes))
        self.assertIn("| driving/steer_rate | 2.20 | 2.50 | +0.30 (+14%) |", lines)

    def test_nothing_to_adopt(self):
        same = {"driving/steer_rate": 2.2}
        self.assertEqual(tuning_adopt.plan(self.table, same), ([], []))


if __name__ == "__main__":
    unittest.main()
