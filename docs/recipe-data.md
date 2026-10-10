# Recipe data pipeline

Artisan uses one pinned public Phoenix source file as a temporary
development input. It does not scrape the Phoenix Wiki, clone the Phoenix
repository, ship SQL, or access the network at runtime.

## Pinned input

- Commit: `6976f063d36f9e5b17072df4922c2ae0c13c024a`
- Raw file: <https://raw.githubusercontent.com/phoenixffxi/Phoenix/6976f063d36f9e5b17072df4922c2ae0c13c024a/sql/synth_recipes.sql>
- SHA-256: `65569737190cdb86ea6e1834e7edfc4a9fa49d966668a97550122612285bfea3`
- Upstream license: GPL-3.0

The converter rejects any input with a different hash unless
`--allow-unpinned` is explicitly supplied for investigation.

## Active Phoenix-era filter

The converter applies these rules:

1. Parse only active lines beginning with `INSERT INTO`; commented-out,
   disabled, placeholder, and unverified rows remain excluded.
2. Exclude rows where `Desynth` is nonzero.
3. Assign the primary craft to the highest of the eight craft requirements.
4. Exclude rows whose primary craft cap is above Phoenix's configured cap of 110.
5. Include base rows with a SQL `NULL` content tag plus `ROTZ`, `COP`, and
   `TOAU`. Exclude `WOTG` until Phoenix enables that expansion, along with later
   `ABYSSEA`, `SOA`, `ROV`, and `TVR` content.

For the pinned source this yields:

- 4,446 active rows
- 3,905 active non-desynthesis rows
- 2,787 active pre-WotG recipe candidates
- 2,783 usable candidates through skill 110 after excluding four cap-255 placeholders
- 395 Smithing recipes with primary caps from 1 through 104
- 321 Woodworking recipes with primary caps from 2 through 102
- 356 Clothcraft recipes with primary caps from 1 through 100
- 391 Alchemy recipes with primary caps from 2 through 101
- 235 Bonecraft recipes with primary caps from 1 through 104
- 457 Goldsmithing recipes with primary caps from 1 through 102
- 314 Leathercraft recipes with primary caps from 1 through 103
- 319 Cooking recipes with primary caps from 1 through 100

Equal-level multi-craft recipes appear in each matching craft book, as they do
on Phoenix Wiki. This is why Oak Bed is present in both Woodworking and
Clothcraft, while Bronze Bed is present in both Smithing and Clothcraft.

These counts exactly match the generated Phoenix Smithing and Woodworking Wiki
pages. Those pages identify this same Phoenix commit as their source. The newer public SQL
branch reorganizes historical tags and includes not-yet-enabled WotG rows, so it
is not used for the current in-era Craftbook.

Phoenix's public default map configuration expresses craft limits in tenths:
`CRAFT_COMMON_CAP = 700` provides 70 common points and
`CRAFT_SPECIALIZATION_POINTS = 400` provides 40 additional specialization
points. Together they support a 110 target for a specialized craft. The
Phoenix Wiki also publishes Expert progression and recipes above 100. A private
deployment override could differ, so this documents the public Phoenix baseline.

- [Phoenix public crafting configuration](https://github.com/phoenixffxi/Phoenix/blob/base/settings/default/map.lua)
- [Phoenix Smithing guide](https://wiki.phoenix-xi.com/Smithing)
- [Phoenix Smithing guild ranks](https://wiki.phoenix-xi.com/Smithing/Guild)
- [Phoenix Woodworking guide](https://wiki.phoenix-xi.com/Woodworking)
- [Phoenix Woodworking guild ranks](https://wiki.phoenix-xi.com/Woodworking/Guild)
- [Phoenix Clothcraft guide](https://wiki.phoenix-xi.com/Clothcraft)
- [Phoenix Clothcraft guild ranks](https://wiki.phoenix-xi.com/Clothcraft/Guild)
- [Phoenix Alchemy guide](https://wiki.phoenix-xi.com/Alchemy)
- [Phoenix Alchemy guild ranks](https://wiki.phoenix-xi.com/Alchemy/Guild)
- [Phoenix Bonecraft guide](https://wiki.phoenix-xi.com/Bonecraft)
- [Phoenix Bonecraft guild ranks](https://wiki.phoenix-xi.com/Bonecraft/Guild)
- [Phoenix Goldsmithing guide](https://wiki.phoenix-xi.com/Goldsmithing)
- [Phoenix Goldsmithing guild ranks](https://wiki.phoenix-xi.com/Goldsmithing/Guild)
- [Phoenix Leathercraft guide](https://wiki.phoenix-xi.com/Leathercraft)
- [Phoenix Leathercraft guild ranks](https://wiki.phoenix-xi.com/Leathercraft/Guild)
- [Phoenix Cooking guide](https://wiki.phoenix-xi.com/Cooking)
- [Phoenix Cooking guild ranks](https://wiki.phoenix-xi.com/Cooking/Guild)

The Alchemy page heading currently says 393 recipes, but its published recipe
tables contain 391 rows. A row-by-row comparison of cap and result ID matches all
391 generated recipes with no missing or extra rows.

The current Goldsmithing Wiki page is generated from a newer Phoenix revision
and lists 458 recipes. Artisan retains the documented pinned pre-WotG source,
which yields 457 Goldsmithing recipes after applying the same expansion filter.

The current Leathercraft Wiki page similarly lists 315 recipes from newer data.
The documented pinned pre-WotG source yields 314 Leathercraft recipes.

## Output

Generated Lua stores numeric IDs and quantities for the crystal, aggregated
ingredients, normal result, HQ results, key item, and content tag. Duplicate
ingredient IDs are collapsed into a single `{ id, count }` requirement.
Names and icons are resolved at runtime through Ashita's resource manager.
Nonzero requirements for crafts other than the primary craft are emitted as
ordered per-recipe subcraft requirements.

## Synthesis skill gate

Phoenix checks all eight crafting fields on a matched recipe. For every nonzero
field, the player's real skill must be within 15 levels of that requirement or
the server cancels the attempt as too difficult. This applies equally to the
primary craft and every subcraft; subcrafts do not require the exact listed cap.
Success and break calculations then consider every involved craft separately.

- [Phoenix synthesis implementation](https://github.com/phoenixffxi/Phoenix/blob/base/src/map/utils/synthutils.cpp)

## Guild rank-test items

All eight crafts' rank-test item IDs and attained ranks come from the
Phoenix Wiki's generated guild pages. They are kept as small explicit lookups in
`data/rank_tests.lua` so recipe provenance and guild-progression metadata remain
distinct.
The Wiki's Expert test item, Gorkhali Kukri (19788), is tagged `ABYSSEA` in the
Phoenix recipe database and is therefore not added to the current pre-WotG book
or marked as an available rank-test recipe.
The Woodworking Expert test item (18884) likewise has no recipe in the filtered
pre-WotG book, so it is not marked.
The Leathercraft Expert test item, Urja Trousers (10577), is tagged `ABYSSEA`
in the Phoenix recipe database and is likewise excluded.
The Cooking Expert test item, Sprightly Soup (5930), is also tagged `ABYSSEA`
and excluded from the current book.

The checked-in complete books are regenerated with:

```powershell
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft smithing --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft woodworking --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft clothcraft --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft alchemy --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft bonecraft --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft goldsmithing --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft leathercraft --min-level 0 --max-level 110
python tools\convert_recipes.py C:\path\to\synth_recipes.sql `
    --output-dir data --craft cooking --min-level 0 --max-level 110
```

The same converter accepts every craft listed by `--help`; expanding the data
set later does not require a new parser or runtime format.
