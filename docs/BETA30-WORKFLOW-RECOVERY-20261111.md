# Beta 30 release workflow recovery

The owner submitted the inclusive Beta 30 addon to CurseForge and requested
GitHub publication. PR 110 merged to main and tag v2.1.5-beta.30 points to the
exact reviewed source 9820fcbdf38713ad619b1852cfe89ba034be8522.

Tagged run 42928584923 passed validation and the published-release guard, but
preparation rejected its dirty checkout. The Lua setup action creates .lua
beneath its current directory, outside the package's reviewed source inventory
but inside the former checkout. The pinned action's main.js defines LUA_PREFIX
and resolves it from process.cwd():
https://github.com/leafo/gh-actions-lua/blob/6919171ccf181b826f44b9bca76307b577217377/main.js#L244

The repair checks out the unchanged release tag under release-source and runs
validation/packaging there. Lua setup remains in the parent workspace. The
clean-source, exact archive/source/Companion checks and draft-only guard remain
intact. A dispatch restricted to Beta 30 permits a rerun without moving the tag.
The generic release job remains push-only, and draft staging has an explicit
Beta 30 tag and all seven prefixed asset paths.

Both sets of eight publication safeguards pass, and YAML parsing confirms the
isolated checkout, working directory and explicit draft tag. Runtime and package
bytes are unchanged: addon SHA256
4d64f8fa19ae6055c99af75a3346ad2701d76576a664cd8520cd044a255050ed.
Native gaps documented in the release notes remain unchanged.
