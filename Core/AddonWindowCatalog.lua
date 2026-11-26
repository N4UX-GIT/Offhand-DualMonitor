local _, Offhand = ...

-- Forever addon window catalog. Keys are addon folder IDs and stable window roles.
-- Existing adapters still resolve and validate live frames.
-- "addon" position leaves placement and any location saving with the provider.
-- "adapter" identifies Offhand's dedicated position persistence path.
-- The entries come from the bridges (bridge.catalog and data.catalogs), merged
-- into this one table after it loads; its identity never changes.
Offhand.AddonWindowCatalog = {}
