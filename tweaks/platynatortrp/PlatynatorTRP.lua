local _, core = ...;

local initialized = false;
local pendingUnits = {};
local appliedNames = {};
local addedCount, refreshedCount, appliedCount = 0, 0, 0;

local function extendQueryRange(module, unit)
    local request = module.requests:GetUnitRequest(unit);
    if not request then return; end;

    -- only visible nameplates enter this queue so no separate distance cap is needed
    request.DistanceLimit = math.huge;
    request:Update();
end;

local function updatePlayerText(module, nameplate, unit)
    if not TRP3_NamePlates:IsEnabled() or not module.unitDisplayInfo
        or nameplate:IsForbidden() or not nameplate:IsShown() then
        return;
    end;
    unit = unit or TRP3_NamePlatesUtil.GetNameplateUnit(nameplate);
    if not unit then return; end;

    local info = module:GetUnitDisplayInfo(unit);
    if not info or not info.isPlayerUnit or info.shouldHide then return; end;

    -- blizzard's name visibility rules don't describe platynator's name widgets
    local name = info.nameUncropped;
    if name then
        if info.shouldColorName and info.color then
            name = info.color:WrapTextInColorCode(name);
        end;
        if info.roleplayStatus then
            name = TRP3_NamePlatesUtil.PrependRoleplayStatusToText(name, info.roleplayStatus);
        end;
        if info.icon then
            local size = TRP3_NamePlatesUtil.GetPreferredIconSize();
            local icon;
            if TRP3_MarkupUtil then
                icon = TRP3_MarkupUtil.GenerateIconMarkup(info.icon, { size = size });
            else
                icon = LibStub:GetLibrary("LibRPMedia-1.2"):GenerateIconMarkup(info.icon, size, size, 0, 0);
            end;
            name = icon .. " " .. name;
        end;
        name = "|W" .. name .. "|w";
    end;

    local subtext;
    if TRP3_NamePlatesUtil.IsFullTitleEnabled() then
        subtext = info.fullTitleUncropped or "";
    elseif TRP3_NamePlatesUtil.IsGuildNameEnabled() then
        subtext = info.guildNameUncropped;
    elseif TRP3_NamePlatesUtil.IsSubtextDisabled() then
        subtext = "";
    end;
    if subtext then subtext = "|W" .. subtext .. "|w"; end;
    Platynator.API.SetUnitTextOverride(unit, name, subtext);
    appliedNames[unit] = name;
    appliedCount = appliedCount + 1;
end;

local function refreshPlate(unit)
    if not TRP3_NamePlates:IsEnabled() or not TRP3_Platynator.unitDisplayInfo then return; end;
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit, false);
    if not nameplate or nameplate:IsForbidden() or not nameplate:IsShown() then return; end;
    TRP3_NamePlates:UpdateCharacterIDForUnit(unit);
    TRP3_NamePlates:UpdateNamePlateForUnit(unit);
    refreshedCount = refreshedCount + 1;
end;

local function refreshPlateDeferred(unit)
    if pendingUnits[unit] then return; end;
    local pending = {};
    pendingUnits[unit] = pending;

    -- platynator sets the default name before subscribing to text override updates
    C_Timer.After(0, function()
        if pendingUnits[unit] ~= pending then return; end;
        pendingUnits[unit] = nil;
        refreshPlate(unit);
    end);
end;

function core:initializePlatynatorTRP()
    if initialized then return true; end;
    if not (Platynator and Platynator.API and Platynator.API.SetUnitTextOverride
            and TRP3_NamePlates and TRP3_NamePlates.UpdateNamePlateForUnit
            and TRP3_NamePlates.UpdateCharacterIDForUnit
            and TRP3_NamePlates.RequestUnitProfile
            and TRP3_NamePlatesRequestManagerMixin and TRP3_NamePlatesRequestManagerMixin.GetUnitRequest
            and TRP3_NamePlatesUtil and TRP3_NamePlatesUtil.GetNameplateUnit
            and TRP3_Platynator and TRP3_Platynator.UpdateNamePlate
            and TRP3_Platynator.GetUnitDisplayInfo) then
        print("Gooby Frame Tweaks: TRP names require Platynator and Total RP 3's Platynator module.");
        return false;
    end;
    initialized = true;
    hooksecurefunc(TRP3_Platynator, "UpdateNamePlate", updatePlayerText);
    hooksecurefunc(TRP3_NamePlates, "RequestUnitProfile", extendQueryRange);
    if TRP3_NamePlates.requests then
        for unit in pairs(TRP3_NamePlates.requests.requests) do
            extendQueryRange(TRP3_NamePlates, unit);
        end;
    end;

    local function refreshAll()
        for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = TRP3_NamePlatesUtil.GetNameplateUnit(nameplate);
            if unit then refreshPlateDeferred(unit); end;
        end;
    end;

    local events = CreateFrame("Frame");
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED");
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
    events:RegisterEvent("UNIT_NAME_UPDATE");
    events:RegisterEvent("PLAYER_ENTERING_WORLD");
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            refreshAll();
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            pendingUnits[unit] = nil;
            appliedNames[unit] = nil;
        elseif event == "NAME_PLATE_UNIT_ADDED"
            or (event == "UNIT_NAME_UPDATE" and unit:match("^nameplate%d+$")) then
            if event == "NAME_PLATE_UNIT_ADDED" then addedCount = addedCount + 1; end;
            refreshPlateDeferred(unit);
        end;
    end);

    refreshAll();
    return true;
end;
