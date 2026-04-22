local _, core = ...

-- this dictionary is literally just so i cant mess up spelling the keys
core.TweakNames = {
    ArenaNumbers = "ArenaNumbers",
    RaidRoleIcon = "RaidRoleIcon",
    RaidName = "RaidName",
    ArenaCommands = "ArenaCommands",
    DebugCommands = "DebugCommands",
}

-- variables are saved in the GoobyFrameTweaksVariables dictionary under their respective TweakName
-- we pass the tweaknames to the function, incase they need to do something if they're turned off
-- otherwise loop over all of the tweaks, check if this is the tweak we need, and then call its function with its toggled state
core.Tweaks = {
    {
        name = core.TweakNames.RaidRoleIcon,
        title = "Hide raid role icons",
        description = "Hide role icons on raid frames.",
        category = "Frames",
        func = function()
            hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
                if issecretvalue(frame) then return end
                if frame.optionTable == DefaultCompactUnitFrameOptions then
                    frame.roleIcon:SetAlpha(0)
                end
            end)
        end
    },
    {
        name = core.TweakNames.RaidName,
        title = "Hide raid frame names",
        description = "Hide names on raid frames.",
        category = "Frames",
        func = function()
            hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
                if issecretvalue(frame) then return end
                if frame.optionTable == DefaultCompactUnitFrameOptions then
                    frame.name:Hide()
                end
            end)
        end
    },
    {
        name = core.TweakNames.ArenaNumbers,
        title = "Arena nameplate numbers",
        category = "Nameplates",
        description = "Change the names of enemies in arenas to numbers so they match up with arena 1-5 targeting binds.",
        func = function()
            -- hooksecurefunc("CompactUnitFrame_UpdateName", function(F)
            --     if IsActiveBattlefieldArena() and F.unit:find("nameplate") then
            --         for i = 1, 5 do
            --             if UnitIsUnit(F.unit, "arena" .. i) then
            --                 F.name:SetText(i)
            --                 F.name:SetTextColor(1, 1, 0);
            --                 break;
            --             end
            --         end
            --     end
            -- end)
        end
    },
    {
        name = core.TweakNames.ArenaCommands,
        title = "Arena surrender command",
        description = "Adds the /gg and /sr commands to surrender in arena.",
        category = "Misc",
        func = function()
            SLASH_SURRENDERGG1 = "/gg"
            SlashCmdList.SURRENDERGG = SurrenderArena;

            SLASH_SURRENDERSR1 = "/sr"
            SlashCmdList.SURRENDERSR = SurrenderArena;
        end
    },
    {
        name = core.TweakNames.DebugCommands,
        title = "Reload command",
        description = "Adds the /rl command for faster reloading.",
        category = "Misc",
        func = function()
            SLASH_RELOADUI1 = "/rl"
            SlashCmdList.RELOADUI = function()
                C_UI.Reload();
            end
        end
    },

}
