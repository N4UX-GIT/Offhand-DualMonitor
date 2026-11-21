--[[
    Offhand Forever recovery bridge

    The packaged file is intentionally inert. The Windows companion may replace
    the installed copy with a validated snapshot generated from the Forever
    client's correctly written (but currently unreadable) SavedVariables file.
    Generated snapshots are guarded by the Forever interface range.
    They also set OffhandForeverStateBridgeVersion so Config.lua can prefer a
    newly generated cold-start snapshot exactly once per client session.
    Character records are isolated in OffhandForeverCharacterRecovery schema 1.
    Config.lua selects a record only after matching the current player GUID;
    account recovery never authorizes another character's settings or HUD.
--]]
