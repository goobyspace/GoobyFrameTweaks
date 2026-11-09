local _, core = ...

local initialized = false
local trpConfigReady = false
local refreshPending = false
local hookCalls = 0

local function getSecretGUIDUnit(guid, bar)
    -- secret guids cant be read but UnitTokenFromGUID still accepts them for group members
    local unit = UnitTokenFromGUID(guid)
    if issecretvalue(unit) or type(unit) ~= "string" then
        if not issecretvalue(bar.isPlayer) and bar.isPlayer then return "player" end
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if issecretvalue(isPlayer) or not isPlayer then return end
    return unit
end

local function getCharacterID(actor, bar)
    -- the blizzard damage meter path passes a fake actor with an empty serial and stores the guid on the bar
    local guid = actor.serial
    if not issecretvalue(guid) and guid == "" then
        guid = bar.actorGUID
    end

    local characterID
    if issecretvalue(guid) then
        local unit = getSecretGUIDUnit(guid, bar)
        if unit then characterID = TRP3_NameUtil.GetQualifiedName(unit) end
    elseif type(guid) == "string" and guid:find("^Player%-") then
        characterID = TRP3_NameUtil.GetQualifiedNameByGUID(guid)
    end

    if issecretvalue(characterID) or type(characterID) ~= "string" then return end
    return characterID
end

local function updateBarColor(actor, bar, instance, _, _, _, a)
    hookCalls = hookCalls + 1
    if type(actor) ~= "table" or actor.customColor or type(bar) ~= "table"
        or type(instance) ~= "table" or not instance.row_info then
        return
    end

    local characterID = getCharacterID(actor, bar)
    if not characterID then return end
    local r, g, b = core.Utils:GetTRPColor(characterID, trpConfigReady)
    if not r then return end

    a = a or 1
    local rowInfo = instance.row_info
    if rowInfo.texture_class_colors and bar.textura then
        bar.textura:SetVertexColor(r, g, b, a)
    end
    if rowInfo.texture_background_class_color and bar.background then
        bar.background:SetVertexColor(r, g, b, a)
    end
    if rowInfo.backdrop and rowInfo.backdrop.use_class_colors and bar.lineBorder then
        bar.lineBorder:SetVertexColor(r, g, b, rowInfo.backdrop.color[4])
    end
    if rowInfo.texts[1].color.byClass and bar.lineText1 then
        bar.lineText1:SetTextColor(r, g, b)
    end
    if rowInfo.texts[2].color.byClass then
        for _, text in ipairs({ bar.lineText2, bar.lineText3, bar.lineText4 }) do
            if text then text:SetTextColor(r, g, b) end
        end
    end
end

-- temporary diagnostic, remove once the colours work
SLASH_GFTDETAILS1 = "/gftdetails"
SlashCmdList.GFTDETAILS = function()
    print("hooked:", initialized, "hookCalls:", hookCalls, "trpReady:", trpConfigReady)
    local instance = Details and Details:GetInstance(1)
    if not instance or not instance.barras then return print("no details window 1") end
    for i, bar in ipairs(instance.barras) do
        if bar:IsShown() and not bar.isTotalBar then
            local guid = bar.actorGUID
            local secret = issecretvalue(guid)
            local unit = secret and getSecretGUIDUnit(guid, bar)
            local id = getCharacterID({ serial = "" }, bar)
            print(i, "guidSecret:", secret, "guid:", secret and "?" or tostring(guid), "unit:", tostring(unit),
                "isPlayer:", issecretvalue(bar.isPlayer) and "?" or tostring(bar.isPlayer),
                "id:", tostring(id), "colour:", id and core.Utils:GetTRPColor(id, trpConfigReady) or "nil")
        end
    end
end

local function refreshWindows()
    if refreshPending then return end
    refreshPending = true

    -- trp fires register updates in bursts so batch them into one redraw
    C_Timer.After(0.5, function()
        refreshPending = false
        Details:RefreshMainWindow(-1, true)
    end)
end

function core:initializeDetailsTRP()
    if initialized then return true end
    if not (issecretvalue and UnitTokenFromGUID and TRP3_NameUtil and TRP3_NameUtil.GetQualifiedNameByGUID
        and TRP3_NameUtil.GetQualifiedName
        and Details and Details.SetBarColors and Details.RefreshMainWindow
        and AddOn_TotalRP3 and AddOn_TotalRP3.Player
        and AddOn_TotalRP3.Player.CreateFromCharacterID
        and TRP3_API and TRP3_API.RegisterCallback and TRP3_Addon) then
        print("Gooby Frame Tweaks: TRP Details colours require Details! and Total RP 3.")
        return false
    end

    initialized = true
    hooksecurefunc(Details, "SetBarColors", updateBarColor)
    TRP3_API.RegisterCallback(TRP3_Addon, "REGISTER_DATA_UPDATED", refreshWindows)
    TRP3_API.RegisterCallback(TRP3_Addon, "WORKFLOW_ON_FINISH", function()
        trpConfigReady = true
        refreshWindows()
    end)
    TRP3_API.RegisterCallback(TRP3_Addon, "CONFIGURATION_CHANGED", function(_, key)
        if key == "color_contrast_level" then refreshWindows() end
    end)
    return true
end
