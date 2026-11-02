# Economy Simulation Report

1,000 virtual players, 30 virtual days, real game engines (`EconomyService`, `LoginCalendar`, `RewardTrackEngine`, `MissionEngine`, `WheelEngine`, `SafetyMode`, `NearMiss`, `ProgressionStructure`). Regenerate with:

```
flutter test test/simulation/simulation_test.dart
```

## Assertions

| # | Assertion | Status | Detail |
|---|-----------|--------|--------|
| 1 | No archetype median falls below 50 after day 4 | PASS ✅ | lowest median across all archetypes/days: 88 (Struggler day 5) |
| 2 | Mainstream archetypes stay above 150 after day 7 | PASS ✅ | casual/regular/adWatcher all comfortable |
| 3 | No archetype median balance reaches 2000 by day 30 | PASS ✅ | highest day-30 median: 1381 (Grinder) |
| 4 | At most 12% of any archetype ever touches 0 coins | PASS ✅ | worst: 0.5% (Casual) |
| 5 | Every player who hit 0 recovered above 50 by day 30 | PASS ✅ | no stranded players |
| 6 | At most 10% of any archetype ends above 2000 | PASS ✅ | worst: 5.8% (Ad Watcher) |
| 7 | Every archetype faucet/sink ratio within 1.0-1.35 | PASS ✅ | Casual 1.22, Regular 1.17, Grinder 1.04, Struggler 1.23, Ad Watcher 1.12 |
| 8 | Ads are at most 35% of the ad-watcher faucet | PASS ✅ | 22.3% of faucet comes from ads |
| 9 | Struggler hits safety mode at most 3 times in 30 days | PASS ✅ | worst player: 0 triggers |
| 10 | Grinder median balance on day 30 does not exceed 2,500 | PASS ✅ | day-30 median 1381 |

## Archetype summary

| Archetype | Players | Stage d7 | Stage d14 | Stage d30 | Safety (total / max per player) | Near-miss (total / avg per player) | Faucet | Sink | Ratio | Cosmetics |
|---|---|---|---|---|---|---|---|---|---|---|
| Casual | 400 | 16 | 32 | 68 | 0 / 0 | 27 / 0.1 | 2281468 | 1872665 | 1.218 | 1418 |
| Regular | 300 | 15 | 29 | 63 | 0 / 0 | 0 / 0.0 | 1906446 | 1634598 | 1.166 | 3147 |
| Grinder | 130 | 150 | 282 | 500 | 0 / 0 | 0 / 0.0 | 4634840 | 4470092 | 1.037 | 3315 |
| Struggler | 50 | 6 | 11 | 24 | 0 / 0 | 20 / 0.4 | 140013 | 113460 | 1.234 | 0 |
| Ad Watcher | 120 | 20 | 39 | 85 | 0 / 0 | 1 / 0.0 | 1172309 | 1051378 | 1.115 | 1574 |

## Economy health per archetype

| Archetype | Earn/day | Spend/day | Mean bal | Median bal | Min bal | Max bal | Hints bought | Hints free | Ads | Ad-double coins | % ever broke | % over 2000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Casual | 190.1 | 156.1 | 1122 | 1081 | 90 | 1621 | 100.4 | 0.0 | 0.0 | 0 | 0.5% | 2.5% |
| Regular | 211.8 | 181.6 | 1006 | 952 | 100 | 1419 | 60.4 | 1.0 | 21.7 | 540 | 0.0% | 0.3% |
| Grinder | 1188.4 | 1146.2 | 1367 | 1381 | 100 | 3979 | 186.3 | 14.1 | 113.4 | 0 | 0.0% | 5.4% |
| Struggler | 93.3 | 75.6 | 631 | 630 | 31 | 724 | 68.3 | 0.0 | 0.0 | 0 | 0.0% | 0.0% |
| Ad Watcher | 325.6 | 292.0 | 1108 | 994 | 100 | 1807 | 116.9 | 3.1 | 88.9 | 1735 | 0.0% | 5.8% |

Per-player daily averages. "Min bal" and "Max bal" are the median across players of each player's own lifetime low and high, sampled on every wallet movement — not just at end of day. "% ever broke" is the share of players whose balance touched 0 at any moment.

## Balance at the checkpoint days

| Archetype | Day 1 | Day 7 | Day 15 | Day 30 |
|---|---|---|---|---|
| Casual | 120 | 523 | 758 | 1081 |
| Regular | 218 | 642 | 644 | 952 |
| Grinder | 1054 | 1425 | 1456 | 1381 |
| Struggler | 100 | 107 | 297 | 630 |
| Ad Watcher | 221 | 675 | 659 | 994 |

## Casual — daily coin balance

| Day | p10 | Median | p90 |
|-----|-----|--------|-----|
| 1 | 65 | 120 | 217 |
| 2 | 74 | 169 | 269 |
| 3 | 68 | 188 | 296 |
| 4 | 81 | 235 | 406 |
| 5 | 119 | 321 | 517 |
| 6 | 182 | 384 | 584 |
| 7 | 274 | 523 | 750 |
| 8 | 352 | 596 | 829 |
| 9 | 407 | 657 | 887 |
| 10 | 412 | 694 | 907 |
| 11 | 451 | 716 | 907 |
| 12 | 430 | 726 | 921 |
| 13 | 440 | 736 | 944 |
| 14 | 433 | 747 | 1027 |
| 15 | 467 | 758 | 1030 |
| 16 | 464 | 762 | 1093 |
| 17 | 473 | 753 | 1130 |
| 18 | 470 | 767 | 1123 |
| 19 | 434 | 770 | 1122 |
| 20 | 423 | 759 | 1090 |
| 21 | 439 | 774 | 1089 |
| 22 | 446 | 787 | 1137 |
| 23 | 447 | 793 | 1173 |
| 24 | 463 | 801 | 1346 |
| 25 | 460 | 822 | 1404 |
| 26 | 490 | 858 | 1491 |
| 27 | 507 | 867 | 1491 |
| 28 | 529 | 895 | 1554 |
| 29 | 558 | 893 | 1617 |
| 30 | 622 | 1081 | 1726 |

## Regular — daily coin balance

| Day | p10 | Median | p90 |
|-----|-----|--------|-----|
| 1 | 100 | 218 | 325 |
| 2 | 161 | 314 | 465 |
| 3 | 238 | 403 | 575 |
| 4 | 298 | 496 | 676 |
| 5 | 350 | 548 | 743 |
| 6 | 422 | 587 | 767 |
| 7 | 466 | 642 | 868 |
| 8 | 480 | 639 | 853 |
| 9 | 471 | 643 | 826 |
| 10 | 460 | 638 | 807 |
| 11 | 477 | 628 | 787 |
| 12 | 479 | 628 | 778 |
| 13 | 474 | 632 | 765 |
| 14 | 485 | 649 | 854 |
| 15 | 478 | 644 | 853 |
| 16 | 465 | 629 | 815 |
| 17 | 450 | 631 | 776 |
| 18 | 468 | 624 | 771 |
| 19 | 483 | 640 | 770 |
| 20 | 472 | 619 | 756 |
| 21 | 476 | 638 | 877 |
| 22 | 474 | 638 | 885 |
| 23 | 482 | 655 | 846 |
| 24 | 486 | 659 | 872 |
| 25 | 473 | 660 | 978 |
| 26 | 487 | 682 | 1143 |
| 27 | 506 | 713 | 1195 |
| 28 | 497 | 738 | 1397 |
| 29 | 505 | 806 | 1417 |
| 30 | 568 | 952 | 1525 |

## Grinder — daily coin balance

| Day | p10 | Median | p90 |
|-----|-----|--------|-----|
| 1 | 889 | 1054 | 1199 |
| 2 | 726 | 1109 | 1896 |
| 3 | 797 | 1274 | 2074 |
| 4 | 842 | 1395 | 1984 |
| 5 | 873 | 1375 | 1868 |
| 6 | 900 | 1413 | 2032 |
| 7 | 906 | 1425 | 2252 |
| 8 | 795 | 1296 | 1898 |
| 9 | 858 | 1373 | 1965 |
| 10 | 806 | 1327 | 1948 |
| 11 | 982 | 1447 | 2102 |
| 12 | 945 | 1428 | 2401 |
| 13 | 823 | 1409 | 2187 |
| 14 | 935 | 1486 | 2372 |
| 15 | 858 | 1456 | 2255 |
| 16 | 918 | 1419 | 2043 |
| 17 | 907 | 1470 | 2217 |
| 18 | 848 | 1443 | 2340 |
| 19 | 836 | 1333 | 2195 |
| 20 | 694 | 1282 | 2182 |
| 21 | 886 | 1523 | 2366 |
| 22 | 913 | 1523 | 2393 |
| 23 | 856 | 1441 | 2357 |
| 24 | 873 | 1392 | 2146 |
| 25 | 807 | 1390 | 1953 |
| 26 | 895 | 1355 | 1900 |
| 27 | 797 | 1458 | 1875 |
| 28 | 924 | 1436 | 1884 |
| 29 | 867 | 1413 | 1865 |
| 30 | 835 | 1381 | 1784 |

## Struggler — daily coin balance

| Day | p10 | Median | p90 |
|-----|-----|--------|-----|
| 1 | 66 | 100 | 160 |
| 2 | 51 | 100 | 160 |
| 3 | 55 | 91 | 160 |
| 4 | 55 | 93 | 148 |
| 5 | 55 | 88 | 198 |
| 6 | 57 | 90 | 192 |
| 7 | 57 | 107 | 265 |
| 8 | 61 | 111 | 272 |
| 9 | 72 | 136 | 327 |
| 10 | 70 | 175 | 471 |
| 11 | 65 | 213 | 471 |
| 12 | 85 | 243 | 467 |
| 13 | 69 | 246 | 494 |
| 14 | 69 | 299 | 494 |
| 15 | 69 | 297 | 532 |
| 16 | 69 | 289 | 531 |
| 17 | 87 | 292 | 531 |
| 18 | 92 | 289 | 533 |
| 19 | 71 | 311 | 529 |
| 20 | 69 | 333 | 603 |
| 21 | 70 | 332 | 669 |
| 22 | 92 | 331 | 674 |
| 23 | 85 | 368 | 774 |
| 24 | 91 | 402 | 774 |
| 25 | 90 | 416 | 778 |
| 26 | 127 | 432 | 761 |
| 27 | 170 | 450 | 703 |
| 28 | 120 | 487 | 691 |
| 29 | 120 | 465 | 784 |
| 30 | 211 | 630 | 991 |

## Ad Watcher — daily coin balance

| Day | p10 | Median | p90 |
|-----|-----|--------|-----|
| 1 | 100 | 221 | 368 |
| 2 | 166 | 326 | 540 |
| 3 | 239 | 476 | 716 |
| 4 | 338 | 528 | 741 |
| 5 | 398 | 560 | 758 |
| 6 | 423 | 593 | 776 |
| 7 | 467 | 675 | 884 |
| 8 | 461 | 666 | 978 |
| 9 | 460 | 676 | 1034 |
| 10 | 493 | 715 | 968 |
| 11 | 445 | 699 | 970 |
| 12 | 450 | 659 | 971 |
| 13 | 433 | 641 | 950 |
| 14 | 450 | 679 | 987 |
| 15 | 448 | 659 | 972 |
| 16 | 459 | 671 | 1073 |
| 17 | 454 | 693 | 1080 |
| 18 | 479 | 716 | 1272 |
| 19 | 481 | 686 | 1350 |
| 20 | 475 | 755 | 1239 |
| 21 | 509 | 804 | 1447 |
| 22 | 511 | 902 | 1478 |
| 23 | 574 | 998 | 1556 |
| 24 | 575 | 920 | 1478 |
| 25 | 534 | 908 | 1379 |
| 26 | 528 | 874 | 1403 |
| 27 | 534 | 858 | 1586 |
| 28 | 572 | 881 | 1589 |
| 29 | 595 | 945 | 1582 |
| 30 | 586 | 994 | 1771 |

## World gates

There is no star or jar gate any more: finishing every stage of a chapter opens the next chapter, and finishing the last chapter of a world opens the next world. No player can be blocked from progressing, so there is nothing to farm and nothing to bypass.

## Behavioral model assumptions

Balance numbers all come from `BalanceConfig` and the real engines. The rows below are *behavior*, which the game cannot know and the simulation must assume (see `sim_model.dart`).

| Assumption | Casual | Regular | Grinder | Struggler | Ad Watcher |
|---|---|---|---|---|
| Share of players | 0.4 | 0.3 | 0.13 | 0.05 | 0.12 |
| Sessions/day | 1 | 2 | 4 | 1 | 2 |
| Stages/day | 4 | 9 | 22 | 2 | 8 |
| Mean hints/stage | 1.5 | 1.0 | 0.4 | 3.5 | 1.4 |
| Abandon rate | 0.05 | 0.04 | 0.02 | 0.35 | 0.05 |
| Plays on a given day | 0.8 | 0.72 | 0.95 | 0.6 | 0.75 |
| First-clear share of stages | 0.7 | 0.34 | 1.0 | 1.0 | 0.45 |
| Bonus words/new stage | 0.9 | 1.05 | 1.2 | 0.6 | 1.0 |
| Bonus words/replay | 0.35 | 0.35 | 0.35 | 0.35 | 0.35 |
| Bonus words/farm replay | 0.8 | 0.8 | 1.0 | 0.8 | 0.8 |
| Claims login calendar + reward track | 1.0 | 0.85 | 1.0 | 0.9 | 0.95 |
| Mission easy/med/hard | 0.0/0.0/0.0 | 0.75/0.6/0.2 | 1.0/1.0/0.95 | 0.0/0.0/0.0 | 0.6/0.35/0.1 |
| Weekly badge chance | 0.0 | 0.25 | 0.9 | 0.0 | 0.15 |
| Watches all rewarded ads | false | false | true | false | true |
| Spins wheel | false | false | true | false | true |
| Hint reserve (never spends below) | 0 | 0 | 0 | 25 | 0 |
| Cosmetic buy threshold | 900 | 780 | 1900 | 100000 | 800 |
| Cosmetic buy chance/day | 0.45 | 0.9 | 0.9 | 0.0 | 0.85 |
| Cosmetic price range | 300-700 | 300-400 | 800-1500 | 300-300 | 300-500 |
| Max cosmetics/day | 1 | 1 | 2 | 0 | 1 |

Core words per stage: 5 (same assumption as `test/economy/economy_simulation_test.dart` — real per-stage word counts are not authored yet).

### Reading note

The Regular balance-band assertion (300-800 every day) and the faucet/sink ratio assertion (1.10-1.30) are mathematically coupled: retained balance = faucet − sink, so both can only hold if the Regular 30-day faucet stays under ~8,800 coins. With the current `BalanceConfig` daily grants (~85/day login calendar, the six-month reward track, missions + chest), that forces the model to assume Regular players skip days, skip some claims, and spend most stage slots on replays. If real telemetry shows higher engagement than this model, the daily-grant faucet must shrink for these targets to stay reachable.
