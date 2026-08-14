import unittest

from vfcommit_lib.nameid_allocator import (
    AxisValueDef,
    CompoundStatValueDef,
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

    def test_hyphen_after_opsz_splits_format4_compound(self) -> None:
        order = ensure_postscript_hyphen(["opsz", PSHYPHEN_TOKEN, "wght"])
        combo = {
            "opsz": AxisValueDef(5, "Micro", False),
            "wght": AxisValueDef(1, "1", False),
        }
        compounds = [
            CompoundStatValueDef(
                id="micro-extrathin",
                axis_indices=[0, 1],
                axis_values=[5.0, 1.0],
                name="Micro Extrathin",
                elidable=False,
                coords={"opsz": 5.0, "wght": 1.0},
            )
        ]
        style = compose_postscript_style_from_order(order, combo, {}, compounds=compounds)
        self.assertEqual(style, "Micro-Extrathin")
        self.assertEqual(
            compose_postscript_instance_name("Interchange", style),
            "InterchangeMicro-Extrathin",
        )


if __name__ == "__main__":
    unittest.main()
