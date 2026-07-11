import unittest

from vfcommit_lib.nameid_allocator import (
    AxisValueDef,
    PSHYPHEN_TOKEN,
    compose_postscript_instance_name,
    compose_postscript_style_from_order,
    ensure_postscript_hyphen,
)


class PostScriptHyphenTests(unittest.TestCase):
    def test_default_hyphen_first_concatenates_style(self) -> None:
        order = ensure_postscript_hyphen(["opsz", "wdth", "wght"])
        self.assertEqual(order[0], PSHYPHEN_TOKEN)
        combo = {
            "opsz": AxisValueDef(5, "Micro", False),
            "wdth": AxisValueDef(88, "SemiCondensed", False),
            "wght": AxisValueDef(360, "Semilight", False),
        }
        style = compose_postscript_style_from_order(order, combo, {})
        self.assertEqual(style, "MicroSemiCondensedSemilight")
        self.assertEqual(
            compose_postscript_instance_name("Playfair", style),
            "Playfair-MicroSemiCondensedSemilight",
        )

    def test_hyphen_after_opsz_splits_style(self) -> None:
        order = ensure_postscript_hyphen(["opsz", PSHYPHEN_TOKEN, "wdth", "wght"])
        combo = {
            "opsz": AxisValueDef(5, "Micro", False),
            "wdth": AxisValueDef(88, "SemiCondensed", False),
            "wght": AxisValueDef(360, "Semilight", False),
        }
        style = compose_postscript_style_from_order(order, combo, {})
        self.assertEqual(style, "Micro-SemiCondensedSemilight")
        self.assertEqual(
            compose_postscript_instance_name("Playfair", style),
            "PlayfairMicro-SemiCondensedSemilight",
        )


if __name__ == "__main__":
    unittest.main()
