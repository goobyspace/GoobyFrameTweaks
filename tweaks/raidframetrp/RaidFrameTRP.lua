local _, core = ...

local initialized = false
local trpConfigReady = false

local function getProfileColor(unit)
    if not TRP3_NameUtil or not TRP3_NameUtil.GetQualifiedName
        or not TRP3_API or not TRP3_API.profile or not TRP3_API.profile.getPlayerCurrentProfile
        or not AddOn_TotalRP3 or not AddOn_TotalRP3.Player
        or not AddOn_TotalRP3.Player.CreateFromCharacterID then
        return
    end

    local realm = GetNormalizedRealmName()
    if issecretvalue(realm) or type(realm) ~= "string" or realm == "" then
        return
    end

    local characterID = TRP3_NameUtil.GetQualifiedName(unit)
    if not characterID or issecretvalue(characterID) or type(characterID) ~= "string" then
        return
    end

    if not TRP3_Register or type(TRP3_Register.character) ~= "table"
        or type(TRP3_Register.profiles) ~= "table"
        or not TRP3_API.profile.getPlayerCurrentProfile() then
        return
    end

    local player = AddOn_TotalRP3.Player.CreateFromCharacterID(characterID)
    if not player or type(player.GetCustomColor) ~= "function" then
        return
    end

    local color
    if trpConfigReady then
        color = player:GetCustomColorForDisplay()
    else
        color = player:GetCustomColor()
    end
    if not color then return end
    if issecretvalue(color) or type(color.GetRGB) ~= "function" then
        return
    end

    local r, g, b = color:GetRGB()
    if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then
        return
    end

    return r, g, b
end

local function getFrameProfileColor(frame)
    if issecretvalue(frame) then return end
    if not DefaultCompactUnitFrameOptions or frame.optionTable ~= DefaultCompactUnitFrameOptions then
        return
    end
    local unit = frame.unit
    if issecretvalue(unit) or type(unit) ~= "string" then
        return
    end

    local r, g, b = getProfileColor(unit)
    return r, g, b
end

local function updateHealthColor(frame)
    if issecretvalue(frame) then return end
    local r, g, b = getFrameProfileColor(frame)
    local healthBar = frame.healthBar
    if r and healthBar and not issecretvalue(healthBar) then
        healthBar:SetStatusBarColor(r, g, b)
    end
end

local function refreshRaidFrames()
    if not CompactRaidFrameContainer or not CompactRaidFrameContainer.ApplyToFrames
        or not CompactUnitFrame_UpdateHealthColor then
        return
    end

    CompactRaidFrameContainer:ApplyToFrames("normal", updateHealthColor)
end

function core:initializeRaidFrameTRP()
    if initialized then return end
    if not (issecretvalue and hooksecurefunc and CompactUnitFrame_UpdateHealthColor
        and TRP3_NameUtil and TRP3_NameUtil.GetQualifiedName
        and TRP3_API and TRP3_API.profile and TRP3_API.profile.getPlayerCurrentProfile
        and AddOn_TotalRP3 and AddOn_TotalRP3.Player
        and AddOn_TotalRP3.Player.CreateFromCharacterID and AddOn_TotalRP3.Player.GetCustomColor
        and AddOn_TotalRP3.Player.GetCustomColorForDisplay
        and TRP3_API.RegisterCallback and TRP3_Addon) then
        return
    end

    initialized = true
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", updateHealthColor)
    TRP3_API.RegisterCallback(TRP3_Addon, "REGISTER_DATA_UPDATED", function()
        refreshRaidFrames()
    end)
    TRP3_API.RegisterCallback(TRP3_Addon, "WORKFLOW_ON_FINISH", function()
        trpConfigReady = true
        refreshRaidFrames()
    end)
    TRP3_API.RegisterCallback(TRP3_Addon, "CONFIGURATION_CHANGED", function(_, key)
        if key == "color_contrast_level" then refreshRaidFrames() end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", refreshRaidFrames)
    refreshRaidFrames()
end
