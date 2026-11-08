# EFIGS localization pass, 7 November 2026

The addon loads English first and then its selected locale. Key completeness
previously concealed explicit English text in newer locale entries. Dictionaries
were therefore loaded independently, without English fallback, and compared by
effective final values.

All 825 active English base keys now have localized values for German, French,
Italian and Spanish, including both esES and esMX. Four intentionally invariant
entries are the Offhand/Mainhand names and the two mathematical seam controls.
Existing regional Spanish translations are retained; new gaps receive shared
Spanish wording. Commands, API/CVar identifiers, product names, color escapes
and ordered format arguments retain their contracts. English names of controls
in the separate Companion and vendor applications remain where needed to find
those actual controls.

| Locale | English fallback entries translated |
| --- | ---: |
| deDE | 346 |
| frFR | 212 |
| itIT | 345 |
| esES | 344 |
| esMX | 344 |
| Total | 1591 |

The pass covers character setup, onboarding and calibration, recovery dialogs,
the setup handbook, EllesmereUI transfer, controller focus, group loot, world
text, speech bubbles and custom background messages. The unrelated existing
non-EFIGS locale content remains in place. The separate previously hardcoded
Companion download popup now uses a dictionary key and localized Close button;
its new key uses English fallback in non-EFIGS dictionaries.

`tests/locales.lua` checks complete keys and ordered format arguments in all
11 dictionaries. It now additionally rejects English-identical EFIGS values
except the four explicit invariants. All 95 Lua suites and six Lua 5.1/path/XML
manifest checks pass. A direct UI text-setter audit found only product/version
names, numerical controls, color wrappers and empty strings outside localization.
The popup-field audit additionally found and corrected the Companion download
dialog. This audit does not claim that every dynamic diagnostic must be translated.

Native display checks use an isolated QA dictionary preview on the English
Forever client. It replaces only Offhand-owned locale values, without replacing
GetLocale or changing client/account language. Full native-language client and
all-page visual acceptance are separate from these dictionary and format checks.
Main settings render in deDE, frFR, itIT, esES and esMX, with the German handbook
also inspected. The Spanish setup button initially truncated; shortening it to
"Asistente de ajustes" fixes the observed truncation. No client/account language
or gameplay setting is changed by the preview. The temporary addon is removed.
