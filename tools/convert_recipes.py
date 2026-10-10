#!/usr/bin/env python3
"""Convert Phoenix synth_recipes.sql rows into deterministic Lua recipe data."""

from __future__ import annotations

import argparse
import collections
import hashlib
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Iterable, Sequence

SOURCE_COMMIT = "6976f063d36f9e5b17072df4922c2ae0c13c024a"
SOURCE_SHA256 = "65569737190cdb86ea6e1834e7edfc4a9fa49d966668a97550122612285bfea3"
SOURCE_URL = (
    "https://raw.githubusercontent.com/phoenixffxi/Phoenix/"
    f"{SOURCE_COMMIT}/sql/synth_recipes.sql"
)

COLUMNS = (
    "id", "desynth", "key_item", "woodworking", "smithing", "goldsmithing",
    "clothcraft", "leathercraft", "bonecraft", "alchemy", "cooking", "crystal",
    "hq_crystal", "ingredient1", "ingredient2", "ingredient3", "ingredient4",
    "ingredient5", "ingredient6", "ingredient7", "ingredient8", "result",
    "result_hq1", "result_hq2", "result_hq3", "result_qty", "result_hq1_qty",
    "result_hq2_qty", "result_hq3_qty", "result_name", "content_tag",
)
CRAFTS = (
    "woodworking", "smithing", "goldsmithing", "clothcraft",
    "leathercraft", "bonecraft", "alchemy", "cooking",
)
LEVEL_75_TAGS = frozenset((None, "ROTZ", "COP", "TOAU"))
INSERT_RE = re.compile(
    r"^INSERT INTO `synth_recipes` VALUES \((.*)\);(?:\s*--.*)?$"
)


@dataclass(frozen=True)
class Recipe:
    values: dict[str, int | str | None]

    @property
    def primary_craft(self) -> str | None:
        best = max(CRAFTS, key=lambda name: int(self.values[name]))
        return best if int(self.values[best]) > 0 else None

    @property
    def cap(self) -> int:
        craft = self.primary_craft
        return int(self.values[craft]) if craft else 0


def parse_value_list(text: str) -> list[int | str | None]:
    """Parse the limited SQL literal grammar used by synth_recipes.sql."""
    tokens: list[str] = []
    current: list[str] = []
    in_string = False
    index = 0
    while index < len(text):
        char = text[index]
        if char == "'":
            current.append(char)
            if in_string and index + 1 < len(text) and text[index + 1] == "'":
                current.append("'")
                index += 2
                continue
            if index == 0 or text[index - 1] != "\\":
                in_string = not in_string
        elif char == "," and not in_string:
            tokens.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        index += 1
    if in_string:
        raise ValueError("unterminated SQL string literal")
    tokens.append("".join(current).strip())

    values: list[int | str | None] = []
    for token in tokens:
        if token == "NULL":
            values.append(None)
        elif token.startswith("'") and token.endswith("'"):
            values.append(token[1:-1].replace("''", "'").replace("\\'", "'"))
        else:
            values.append(int(token))
    return values


def parse_recipes(sql_text: str) -> list[Recipe]:
    recipes: list[Recipe] = []
    for line_number, line in enumerate(sql_text.splitlines(), 1):
        match = INSERT_RE.match(line)
        if not match:
            continue
        values = parse_value_list(match.group(1))
        if len(values) != len(COLUMNS):
            raise ValueError(
                f"line {line_number}: expected {len(COLUMNS)} values, got {len(values)}"
            )
        recipes.append(Recipe(dict(zip(COLUMNS, values))))
    return recipes


def verify_source(sql_bytes: bytes, allow_unpinned: bool) -> None:
    digest = hashlib.sha256(sql_bytes).hexdigest()
    if digest != SOURCE_SHA256 and not allow_unpinned:
        raise ValueError(
            "source SHA-256 does not match the pinned Phoenix revision: "
            f"expected {SOURCE_SHA256}, got {digest}; pass --allow-unpinned to inspect it"
        )


def level_75_recipe(recipe: Recipe) -> bool:
    return (
        int(recipe.values["desynth"]) == 0
        and recipe.primary_craft is not None
        and recipe.cap <= 110
        and recipe.values["content_tag"] in LEVEL_75_TAGS
    )


def aggregate_items(item_ids: Iterable[int]) -> list[tuple[int, int]]:
    counts = collections.Counter(item_id for item_id in item_ids if item_id > 0)
    return sorted(counts.items())


def lua_scalar(value: int | str | None) -> str:
    if value is None:
        return "nil"
    if isinstance(value, int):
        return str(value)
    escaped = value.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def render_recipe(recipe: Recipe, craft_name: str) -> list[str]:
    values = recipe.values
    subcrafts = [
        (craft, int(values[craft]))
        for craft in CRAFTS
        if craft != craft_name and int(values[craft]) > 0
    ]
    subcraft_text = ", ".join(
        f"{{ craft = '{craft}', cap = {cap} }}" for craft, cap in subcrafts
    )
    ingredients = aggregate_items(int(values[f"ingredient{i}"]) for i in range(1, 9))
    ingredient_text = ", ".join(
        f"{{ id = {item_id}, count = {count} }}" for item_id, count in ingredients
    )
    return [
        "    {",
        f"        id = {values['id']}, cap = {values[craft_name]}, key_item = {values['key_item']},",
        f"        crystal = {values['crystal']}, hq_crystal = {values['hq_crystal']},",
        f"        subcrafts = {{ {subcraft_text} }},",
        f"        ingredients = {{ {ingredient_text} }},",
        f"        result = {{ id = {values['result']}, count = {values['result_qty']} }},",
        "        hq = { "
        f"{{ id = {values['result_hq1']}, count = {values['result_hq1_qty']} }}, "
        f"{{ id = {values['result_hq2']}, count = {values['result_hq2_qty']} }}, "
        f"{{ id = {values['result_hq3']}, count = {values['result_hq3_qty']} }} "
        "},",
        f"        content_tag = {lua_scalar(values['content_tag'])},",
        "    },",
    ]


def render_lua(craft: str, recipes: Sequence[Recipe]) -> str:
    lines = [
        "-- Generated by tools/convert_recipes.py; do not edit by hand.",
        f"-- Source: {SOURCE_URL}",
        f"-- Source SHA-256: {SOURCE_SHA256}",
        "-- Upstream license: GNU General Public License v3.0.",
        f"-- Filter: active INSERT, non-desynth, pre-WotG Phoenix content through cap 110, {craft} primary craft.",
        "return {",
    ]
    for recipe in recipes:
        lines.extend(render_recipe(recipe, craft))
    lines.extend(("}", ""))
    return "\n".join(lines)


def select_recipes(
    recipes: Sequence[Recipe], craft: str, minimum: int, maximum: int
) -> list[Recipe]:
    selected = [
        recipe for recipe in recipes
        if level_75_recipe(recipe)
        and int(recipe.values[craft]) > 0
        and int(recipe.values[craft]) == recipe.cap
        and minimum <= int(recipe.values[craft]) <= maximum
    ]
    return sorted(
        selected,
        key=lambda recipe: (int(recipe.values[craft]), int(recipe.values["id"])),
    )


def print_stats(recipes: Sequence[Recipe]) -> None:
    print(f"active rows: {len(recipes)}")
    print(f"active non-desynth rows: {sum(int(r.values['desynth']) == 0 for r in recipes)}")
    print(f"level-75 filtered rows: {sum(level_75_recipe(r) for r in recipes)}")
    print("active rows by content_tag:")
    tags = collections.Counter(r.values["content_tag"] for r in recipes)
    for tag, count in sorted(tags.items(), key=lambda item: str(item[0])):
        print(f"  {tag or 'NULL'}: {count}")
    print("level-75 rows by craft book (ties appear in each matching book):")
    for craft in CRAFTS:
        count = sum(
            level_75_recipe(recipe)
            and int(recipe.values[craft]) > 0
            and int(recipe.values[craft]) == recipe.cap
            for recipe in recipes
        )
        print(f"  {craft}: {count}")


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=pathlib.Path, help="path to synth_recipes.sql")
    parser.add_argument("--output-dir", type=pathlib.Path)
    parser.add_argument("--craft", choices=CRAFTS, default="smithing")
    parser.add_argument("--min-level", type=int, default=0)
    parser.add_argument("--max-level", type=int, default=20)
    parser.add_argument("--stats", action="store_true")
    parser.add_argument("--allow-unpinned", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    sql_bytes = args.input.read_bytes()
    verify_source(sql_bytes, args.allow_unpinned)
    recipes = parse_recipes(sql_bytes.decode("utf-8"))
    if args.stats:
        print_stats(recipes)
    if args.output_dir:
        selected = select_recipes(recipes, args.craft, args.min_level, args.max_level)
        args.output_dir.mkdir(parents=True, exist_ok=True)
        output_path = args.output_dir / f"{args.craft}.lua"
        output_path.write_text(render_lua(args.craft, selected), encoding="utf-8", newline="\n")
        print(f"wrote {len(selected)} recipes to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
