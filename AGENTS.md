# Shared addon engineering reference

<!-- wowkb:reference:start -->
For all World of Warcraft addon development, research and supporting Companion work, use `D:/Tools/Code/N4UXADDONS/wow-addon-knowledge` as the first-line shared knowledge project. Read its `README.md` and `skills/wow-addon-research/SKILL.md`. Run `scripts/wowkb.ps1` from that knowledge root (or invoke it by absolute path) for `status` and the appropriate `ask`, `api`, `search` or `study` query before making API or engineering decisions. Supply the exact client/build where relevant; record the local evidence used or the unresolved gap.

Live addon source and observed target-client behavior remain authoritative. Keep declarations, source studies, simulations and live evidence distinct. If local knowledge is missing or stale, verify the appropriate upstream and record a source-backed finding or gap in the shared project. Do not infer absence or combat/taint safety from retrieval results. Keep reference caches out of addon packages.

Apply this rule to existing and future addon projects, including checkouts outside the current workspace. At new-project setup, add a root `AGENTS.md` with this canonical reference so the convention travels with the repository. If the knowledge path is unavailable, report the access gap and use verified project/upstream evidence explicitly; do not silently claim the knowledge project was consulted.
<!-- wowkb:reference:end -->
