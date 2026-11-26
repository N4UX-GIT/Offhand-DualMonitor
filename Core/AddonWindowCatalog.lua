local _, Offhand = ...

-- Initial Forever catalog. Keys are addon folder IDs and stable window roles.
-- Existing adapters still resolve and validate live frames.
-- "addon" position leaves placement and any location saving with the provider.
-- "adapter" identifies Offhand's dedicated position persistence path.
Offhand.AddonWindowCatalog = {
    Leatrix_Maps = {
        settings = {position = "addon", close = "workspace-special-windows", opener = "Leatrix_Maps"},
        worldMap = {position = "addon", close = "map-adapter"},
    },
    Leatrix_Plus = {
        settings = {position = "addon", close = "workspace-special-windows", opener = "Leatrix_Plus"},
    },
    Leatrix_Sounds = {
        settings = {position = "addon", close = "workspace-special-windows", opener = "Leatrix_Sounds"},
    },
    Leveldon = {
        settings = {position = "addon", close = "workspace-special-windows", opener = "LEVELDON"},
    },
    Questdon = {
        questBook = {position = "addon", close = "workspace-special-windows", opener = "QUESTDON"},
    },
    Platynator = {
        settings = {position = "addon", close = "workspace-special-windows", opener = "Platynator",
            learnPlacementFile = "customisedialog/main.lua"},
    },
    ForeverDungeonJournal = {
        journal = {position = "addon", close = "workspace-special-windows", opener = "FOREVERDUNGEONJOURNAL",
            learnPlacementFile = "core/journal.lua"},
    },
    Baganator = {
        backpack = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"},
    },
    Bagnon = {
        inventory = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"},
    },
    EllesmereUIBags = {
        backpack = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"},
    },
    BetterBags = {
        backpack = {position = "addon", close = "native"},
        bank = {position = "addon", close = "native"},
    },
    RXPGuides = {
        guide = {position = "addon", close = "native"},
    },
    OpenMap = {
        worldMap = {position = "addon", close = "map-adapter"},
    },
    MoveAny = {
        worldMap = {position = "addon", close = "map-adapter"},
    },
    ClassicUIForever = {
        worldMap = {position = "addon", close = "native"},
        character = {position = "addon", close = "native"},
    },
    EllesmereUI = {
        suitePrefix = "ellesmereui",
        hud = {position = "addon", close = "native"},
    },
    ElvUI = {
        suitePrefix = "elvui",
        hud = {position = "addon", close = "native"},
    },
    FlareUI = {
        suitePrefix = "flareui",
        hud = {position = "addon", close = "native"},
    },
    ArkInventory = {
        inventory = {position = "adapter", close = "bag-adapter"},
    },
    BagSmith = {
        inventory = {position = "adapter", close = "bag-adapter"},
    },
    Bagnaros = {
        inventory = {position = "adapter", close = "bag-adapter"},
    },
}
