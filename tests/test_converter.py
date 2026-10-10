import pathlib
import tempfile
import unittest

from tools import convert_recipes


def row(
    recipe_id=1,
    desynth=0,
    key_item=0,
    wood=0,
    smith=10,
    gold=0,
    cloth=0,
    leather=0,
    bone=0,
    alchemy=0,
    cooking=0,
    crystal=4096,
    ingredients=(649, 649, 0, 0, 0, 0, 0, 0),
    result=660,
    name="Bronze Sheet",
    tag=None,
):
    values = [
        recipe_id, desynth, key_item, wood, smith, gold, cloth, leather, bone,
        alchemy, cooking, crystal, 4238, *ingredients, result, result, result,
        result, 1, 1, 1, 1, f"'{name}'", "NULL" if tag is None else f"'{tag}'",
    ]
    return "INSERT INTO `synth_recipes` VALUES (" + ",".join(map(str, values)) + ");"


class ConverterTests(unittest.TestCase):
    def test_parser_ignores_commented_rows(self):
        sql = row() + "\n-- " + row(recipe_id=2)
        recipes = convert_recipes.parse_recipes(sql)
        self.assertEqual([recipe.values["id"] for recipe in recipes], [1])

    def test_primary_craft_prefers_declared_order_on_tie(self):
        recipe = convert_recipes.parse_recipes(row(wood=10, smith=10))[0]
        self.assertEqual(recipe.primary_craft, "woodworking")

    def test_repeated_ingredients_are_aggregated(self):
        recipe = convert_recipes.parse_recipes(row())[0]
        lua = convert_recipes.render_lua("smithing", [recipe])
        self.assertIn("{ id = 649, count = 2 }", lua)
        self.assertEqual(lua.count("id = 649, count = 2"), 1)

    def test_subcrafts_are_emitted_in_declared_order(self):
        recipe = convert_recipes.parse_recipes(
            row(smith=10, wood=3, leather=2)
        )[0]
        lua = convert_recipes.render_lua("smithing", [recipe])
        self.assertIn(
            "subcrafts = { { craft = 'woodworking', cap = 3 }, "
            "{ craft = 'leathercraft', cap = 2 } },",
            lua,
        )
        self.assertNotIn("craft = 'smithing'", lua)

    def test_tied_recipes_are_emitted_in_each_matching_craft_book(self):
        recipe = convert_recipes.parse_recipes(
            row(wood=49, smith=0, cloth=49, name="Oak Bed")
        )[0]
        woodworking = convert_recipes.select_recipes(
            [recipe], "woodworking", 0, 110
        )
        clothcraft = convert_recipes.select_recipes(
            [recipe], "clothcraft", 0, 110
        )
        self.assertEqual(woodworking, [recipe])
        self.assertEqual(clothcraft, [recipe])

        cloth_lua = convert_recipes.render_lua("clothcraft", clothcraft)
        self.assertIn("cap = 49", cloth_lua)
        self.assertIn("subcrafts = { { craft = 'woodworking', cap = 49 } },", cloth_lua)
        self.assertNotIn("craft = 'clothcraft'", cloth_lua)

    def test_level_75_filter_rejects_desynth_later_content_and_high_caps(self):
        valid = convert_recipes.parse_recipes(row())[0]
        rotz = convert_recipes.parse_recipes(row(tag="ROTZ"))[0]
        desynth = convert_recipes.parse_recipes(row(desynth=1))[0]
        wotg = convert_recipes.parse_recipes(row(tag="WOTG"))[0]
        later = convert_recipes.parse_recipes(row(tag="SOA"))[0]
        expert = convert_recipes.parse_recipes(row(smith=110))[0]
        high = convert_recipes.parse_recipes(row(smith=111))[0]
        self.assertTrue(convert_recipes.level_75_recipe(valid))
        self.assertTrue(convert_recipes.level_75_recipe(rotz))
        self.assertFalse(convert_recipes.level_75_recipe(desynth))
        self.assertFalse(convert_recipes.level_75_recipe(wotg))
        self.assertFalse(convert_recipes.level_75_recipe(later))
        self.assertTrue(convert_recipes.level_75_recipe(expert))
        self.assertFalse(convert_recipes.level_75_recipe(high))

    def test_pinned_hash_guard(self):
        with self.assertRaisesRegex(ValueError, "does not match"):
            convert_recipes.verify_source(b"changed", allow_unpinned=False)
        convert_recipes.verify_source(b"changed", allow_unpinned=True)

    def test_output_is_deterministic(self):
        recipes = convert_recipes.parse_recipes(row(recipe_id=2) + "\n" + row(recipe_id=1))
        selected = convert_recipes.select_recipes(recipes, "smithing", 0, 20)
        first = convert_recipes.render_lua("smithing", selected)
        second = convert_recipes.render_lua("smithing", selected)
        self.assertEqual(first, second)
        self.assertLess(first.index("id = 1,"), first.index("id = 2,"))


if __name__ == "__main__":
    unittest.main()
