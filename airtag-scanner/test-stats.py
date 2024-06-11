import unittest

import stats


class TestStats(unittest.TestCase):
    def test_sliding_time_window(self):
        rows = [("0", "A"), ("0", "B"), ("1", "C"), ("2", "D"), ("4", "E"), ("7", "F")]

        stw = stats.sliding_time_window(rows, 3)

        aw = list(stw)

        assert rows[:4] == aw[0]
        assert rows[1:4] == aw[1]
        assert rows[2:5] == aw[2]
        assert rows[3:5] == aw[3]
        assert rows[4:] == aw[4]
        assert rows[5:] == aw[5]

        assert len(aw) == 6

    def test_is_airtag(self):
        cases = [("90", True), ("d0", True), ("00", False)]

        for case in cases:
            assert stats.is_airtag(case[0]) == case[1]
