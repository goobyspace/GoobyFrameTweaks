local _, core = ...;

-- this dictionary is literally just so i cant mess up spelling the keys
core.TweakNames = {
    PlatynatorTRP = "PlatynatorTRP",
    RaidFrameTRP = "RaidFrameTRP",
    RaidRoleIcon = "RaidRoleIcon",
    RaidName = "RaidName",
    BarFrames = "BarFrames",
    ArenaCommands = "ArenaCommands",
    DebugCommands = "DebugCommands",
    BagSlotCount = "BagSlotCount",
    RaidFrameGrowth = "RaidFrameGrowth",
};

-- variables are saved in the GoobyFrameTweaksVariables dictionary under their respective TweakName
-- we pass the tweaknames to the function, incase they need to do something if they're turned off
-- otherwise loop over all of the tweaks, check if this is the tweak we need, and then call its function with its toggled state
core.Tweaks = {
    {
        name = core.TweakNames.RaidFrameTRP,
        title = "TRP raid frame health colours",
        description =
        "Use known TRP profile colours for raid-frame health bars. Respects TRP's colour contrast setting once TRP has finished loading. Requires Total RP 3.",
        category = "Frames",
        func = function()
            core:initializeRaidFrameTRP();
        end
    },
    {
        name = core.TweakNames.RaidRoleIcon,
        title = "Hide raid role icons",
        description = "Hide role icons on raid frames.",
        category = "Frames",
        func = function()
            hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
                if issecretvalue(frame) then return; end;
                if frame.optionTable == DefaultCompactUnitFrameOptions then
                    frame.roleIcon:SetAlpha(0);
                end;
            end);
        end
    },
    {
        name = core.TweakNames.RaidName,
        title = "Hide raid frame names",
        description = "Hide names on raid frames.",
        category = "Frames",
        func = function()
            hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
                if issecretvalue(frame) then return; end;
                if frame.optionTable == DefaultCompactUnitFrameOptions then
                    frame.name:Hide();
                end;
            end);
        end
    },
    {
        name = core.TweakNames.RaidFrameGrowth,
        title = "Raid frames grow right to left",
        description =
        "Makes raid frames grow from right to left instead of left to right. Raid frame size and column size can change with the raid size (see RaidFrameLayouts.lua), done by switching between copies of your Edit Mode layout out of combat.",
        category = "Frames",
        func = function()
            core:initializeRaidFrameGrowth();
        end
    },
    {
        name = core.TweakNames.PlatynatorTRP,
        title = "Platynator TRP names",
        category = "Nameplates",
        description =
        "Show TRP player names and colours without targeting.",
        func = function()
            core:initializePlatynatorTRP();
        end
    },
    {
        name = core.TweakNames.ArenaCommands,
        title = "Arena surrender command",
        description = "Adds the /gg and /sr commands to surrender in arena.",
        category = "Misc",
        func = function()
            SLASH_SURRENDERGG1 = "/gg";
            SlashCmdList.SURRENDERGG = SurrenderArena;

            SLASH_SURRENDERSR1 = "/sr";
            SlashCmdList.SURRENDERSR = SurrenderArena;
        end
    },
    {
        name = core.TweakNames.DebugCommands,
        title = "Reload command",
        description = "Adds the /rl command for faster reloading.",
        category = "Misc",
        func = function()
            SLASH_RELOADUI1 = "/rl";
            SlashCmdList.RELOADUI = function()
                C_UI.Reload();
            end;
        end
    },
    {
        name = core.TweakNames.BagSlotCount,
        title = "Bag Slot Count",
        description = "Adds the amount of empty bag slots as a number over the main bag.",
        category = "Misc",
        func = function()
            local overlay = CreateFrame("Frame", nil, UIParent);
            overlay:SetAllPoints(MainMenuBarBackpackButton);
            overlay:SetFrameStrata(MainMenuBarBackpackButton:GetFrameStrata());
            overlay:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel() + 1);

            local countText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge");
            countText:SetPoint("CENTER", overlay, "CENTER");
            countText:SetFont(countText:GetFont(), 14, "OUTLINE");
            countText:SetTextColor(1, 1, 1);

            local function updateFreeSlotCount()
                local freeSlots = 0;
                for bagID = 0, NUM_BAG_SLOTS do
                    freeSlots = freeSlots + (C_Container.GetContainerNumFreeSlots(bagID) or 0);
                end;

                local reagentBagID = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag;
                if reagentBagID and reagentBagID > NUM_BAG_SLOTS then
                    freeSlots = freeSlots + (C_Container.GetContainerNumFreeSlots(reagentBagID) or 0);
                end;

                countText:SetText(tostring(freeSlots));
            end;

            local events = CreateFrame("Frame");
            events:RegisterEvent("BAG_UPDATE_DELAYED");
            events:RegisterEvent("PLAYER_ENTERING_WORLD");
            events:SetScript("OnEvent", updateFreeSlotCount);
            updateFreeSlotCount();
        end
    },
};
