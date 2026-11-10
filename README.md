# Forever Warband Raiders

A WoW Forever addon for level 60: is each character raid ready, what gear are they chasing, which raids are they saved to, and what needs buying, crafting or mailing before raid night. It's the follow-on to Forever Warband Journey, and works with or without it.

## Install
1. Download the release zip.
2. Put the `ForeverWarbandRaiders` folder in `World of Warcraft\_forever_\Interface\AddOns\`.
3. Log in on each character once, then type `/fwr`.

## Tabs
| Tab | What you get |
|---|---|
| Ready | Checklist per character: level, empty slots, repairs, enchants, gear plan, consumables, gold, mount, plus your own checks. Warband summary and reset timers |
| Gear | Two gear sets per character (main and off spec). Shift-click items in, add where they drop, see equipped / in bags / in bank / wanted |
| Lockouts | Weekly reset countdown and every character's saved raids with boss progress |
| Prep | Consumables per raid night, stock across the warband, who crafts what, and a to-do list of mail / craft / buy |
| Settings | Gold and durability targets, raid nights, enchant slots, custom checks, set names, forget characters |

**Works with ForeverDungeonJournal** (optional): planned items show which boss drops them and open the journal when clicked, your journal favourites can be added to a gear set in one click, a drop finder lists level 58–60 dungeon loot for any slot in your armour type, and the Lockouts tab shows your dungeon runs this week.

Plans can be shared: **Export** gives a text string a friend can **Import**.

## Commands
`/fwr` open · `/fwr ready` · `/fwr want [item] source` · `/fwr prep [item] qty` · `/fwr reset`

## Notes
- Nothing is hard-coded: items, sources and checks are yours, so WoW Forever's own data always wins.
- Auction House prices show when Auctionator is installed.
- Bank contents update when you open the bank.
