local _, private = ...
-- Only the placement guide uses this snapshot. The normal UI reload still
-- accepts the new topology for gameplay and the saved setup checkpoint.
local preview = _G.OffhandCompanionTopology
_G.OffhandCompanionTopology = private.previous
private.previous = nil
if _G.Offhand and _G.Offhand.Onboarding then
    _G.Offhand.Onboarding.placementPreview = preview
end
