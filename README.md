# Kraken C&C Character Wizard

A guided character-creation wizard for **Castles & Crusades** on SmiteWorks' official **C&C ruleset** in **Fantasy Grounds Unity**, styled after the 5E Character Wizard.

Tabbed flow: **Abilities → Race → Class → Primes → Hit Points → Equipment → Spells → Finish.**

It reads the official C&C books you have loaded. The **Players Handbook** gives the races, classes and spells. Gear and spells from other official books you load (the Adventurer's Backpack, for example) show up in the shop and the spell lists, and the wizard builds the character through the ruleset's own race and class loaders.

> 📖 **New here? Read the [Install & User Guide](GUIDE.md).** It covers what to install, the Castle Keeper's options and a screenshot walkthrough of every tab.

## Screenshots

**Pick a race and read its traits right in the wizard**

![Race tab](docs/images/03-race.png)

**Your class sets the hit die, base to hit, prime and starting coin**

![Class tab](docs/images/04-class.png)

**A shop of the gear your class can use and your purse can pay for**

![Equipment tab](docs/images/07-equipment.png)

**Spells by level, with the number your character can cast each day**

![Spells tab](docs/images/08-spells.png)

**…and the wizard builds the sheet through the official C&C loaders**

![Finished character sheet](docs/images/10-character-sheet.png)

> The full tab-by-tab walkthrough is in the **[Install & User Guide](GUIDE.md)**.

## What it does for you

- **Starts at any level.** The Castle Keeper sets the starting level (1 to 24) in Options. The wizard builds the character at that level, with its abilities, hit points per level, experience and spells per day.
- **Rolls in the open.** Ability scores, hit points and starting coin are rolled with FGU dice, and every roll goes to chat. The Castle Keeper chooses the method: 3d6 arranged, 4d6 drop lowest, or 3d6 in order.
- **Primes done right.** Your class's prime is ticked for you. Humans pick two more and every other race picks one.
- **A shop that makes sense.** It's sorted by type (armor, weapons, gear, clothing, provisions, transport) with a type filter and search. It shows only the weapons and armor your class may use (no plate mail for a wizard), the shields and helms your class may carry, and only what your rolled coin still covers. Magic items are never in the starting shop.
- **Spells by the book.** It shows the spells per day at your starting level, lists your class's spells up to the highest level you can cast, and puts them on the sheet's Spells tab.
- **Combine classes (Adventurer's Backpack).** You can start with more than one class. The Castle Keeper has the last word.
- **Save unfinished.** You can make a character before game night without your Castle Keeper. **Create Character** works at any point, and whatever is still open is listed in the sheet's notes so you can finish it together.
- **Level up later.** The cog beside the level on the sheet opens Class & Level. **Lvl Up** there walks you through Class, Hit Points, Spells and Finish, including dual class and reclass from the Adventurer's Backpack.

## Install

Grab the latest [**Release**](../../releases/latest), then:

1. Put `KrakenCCCharWizard.ext` in your Fantasy Grounds data folder under `extensions\`.
   - The data folder is usually `%appdata%\SmiteWorks\Fantasy Grounds`.
2. Launch FGU, load a Castles & Crusades campaign as host, click **Extensions** on the load screen, and enable **Official C&C Character Creation Wizard**.
3. In game, open **Library → Modules** and load the **Castles & Crusades Players Handbook**, plus any other official C&C books you want the wizard to use.
4. Open **Characters** and click the wizard icon in the top-left corner.

### Requirements (commercial, not included)
- Fantasy Grounds Unity
- The official Castles & Crusades ruleset (CnCRPG)
- The **Castles & Crusades Players Handbook** module. Races, classes, spells and equipment are read from it, and without it those lists are empty.

## Release

`python release.py` builds `KrakenCCCharWizard.ext` from the extension files in this repository and publishes a GitHub Release with it attached (the tag is `v` plus the version in `extension.xml`). It needs Python 3 and an authenticated GitHub CLI (`gh`).
