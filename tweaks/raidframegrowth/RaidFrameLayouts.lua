local _, core = ...;

local sizeTiers = {
    { maxMembers = 20 },
    { maxMembers = 30, width = 132, height = 60, columnSize = 6 },
    { maxMembers = 40, width = 114, height = 44, columnSize = 8 },
};

local LAYOUT_PREFIX = "GFT DO NOT TOUCH ";
local MIN_WIDTH, MIN_HEIGHT = 72, 36;
local MAX_WIDTH, MAX_HEIGHT = 144, 72;

local syncing = false;
local warnedAboutSlots = false;
local syncedMain;

local function tierLayoutName(tier)
    return LAYOUT_PREFIX .. tier.maxMembers;
end;

local function hasOverrides(tier)
    return tier.width or tier.height or tier.columnSize;
end;

local function isTierLayoutName(name)
    return name:sub(1, #LAYOUT_PREFIX) == LAYOUT_PREFIX;
end;

local function findLayout(layouts, name)
    for index, layout in ipairs(layouts) do
        if layout.layoutName == name then return index; end;
    end;
end;

local function sameTable(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b; end;
    for key, value in pairs(a) do
        if not sameTable(value, b[key]) then return false; end;
    end;
    for key in pairs(b) do
        if a[key] == nil then return false; end;
    end;
    return true;
end;

local function setSetting(settings, setting, value)
    for _, info in ipairs(settings) do
        if info.setting == setting then
            info.value = value;
            return;
        end;
    end;
    tinsert(settings, { setting = setting, value = value });
end;

-- tier layouts share the anchor of the layout they are copied from
function core.getMainLayoutName(name)
    return isTierLayoutName(name) and GoobyFrameTweaksVariables.RaidFrameGrowthMainLayout or name;
end;

local function buildTierLayout(source, tier)
    local layout = CopyTable(source);
    layout.layoutName = tierLayoutName(tier);
    layout.layoutType = Enum.EditModeLayoutType.Character;

    for _, systemInfo in ipairs(layout.systems) do
        if systemInfo.system == Enum.EditModeSystem.UnitFrame and systemInfo.systemIndex == Enum.EditModeUnitFrameSystemIndices.Raid then
            -- edit mode saves width and height as the difference from their minimum
            if tier.width then
                setSetting(systemInfo.settings, Enum.EditModeUnitFrameSetting.FrameWidth,
                    Clamp(tier.width, MIN_WIDTH, MAX_WIDTH) - MIN_WIDTH);
            end;
            if tier.height then
                setSetting(systemInfo.settings, Enum.EditModeUnitFrameSetting.FrameHeight,
                    Clamp(tier.height, MIN_HEIGHT, MAX_HEIGHT) - MIN_HEIGHT);
            end;
            if tier.columnSize then
                setSetting(systemInfo.settings, Enum.EditModeUnitFrameSetting.RowSize, Clamp(tier.columnSize, 2, 10));
            end;
        end;
    end;
    return layout;
end;

local function syncLayouts()
    local info = EditModeManagerFrame.layoutInfo;
    local mainIndex = findLayout(info.layouts, GoobyFrameTweaksVariables.RaidFrameGrowthMainLayout);
    if not mainIndex then return; end;

    -- switching layouts fires this again and copying every tier each time made group changes hitch
    local main = info.layouts[mainIndex];
    if syncedMain and sameTable(main, syncedMain) then
        local complete = true;
        for _, tier in ipairs(sizeTiers) do
            if hasOverrides(tier) and not findLayout(info.layouts, tierLayoutName(tier)) then
                complete = false;
                break;
            end;
        end;
        if complete then return false; end;
    end;

    local replaced = {};
    local added = {};
    local freeSlots = Constants.EditModeConsts.EditModeMaxLayoutsPerType -
        EditModeManagerFrame.numLayouts[Enum.EditModeLayoutType.Character];

    for _, tier in ipairs(sizeTiers) do
        if hasOverrides(tier) then
            local wanted = buildTierLayout(info.layouts[mainIndex], tier);
            local index = findLayout(info.layouts, wanted.layoutName);
            if index then
                if not sameTable(info.layouts[index], wanted) then
                    replaced[index] = wanted;
                end;
            elseif #added < freeSlots then
                tinsert(added, wanted);
            elseif not warnedAboutSlots then
                warnedAboutSlots = true;
                print(
                    "GoobyFrameTweaks: no free character edit mode layout slot, delete some");
            end;
        end;
    end;
    if not next(replaced) and #added == 0 then
        syncedMain = CopyTable(main);
        return false;
    end;

    local saveInfo = { layouts = CopyTable(info.layouts), activeLayout = info.activeLayout };
    for index, layout in pairs(replaced) do
        saveInfo.layouts[index] = layout;
    end;
    local addedIndexes = {};
    for _, layout in ipairs(added) do
        tinsert(saveInfo.layouts, layout);
        tinsert(addedIndexes, #saveInfo.layouts);
    end;

    syncing = true;
    local ok, err = pcall(function()
        C_EditMode.SaveLayouts(saveInfo);
        for _, index in ipairs(addedIndexes) do
            C_EditMode.OnLayoutAdded(index, false, false);
        end;
    end);
    syncing = false;
    if not ok then error(err, 0); end;
    return true;
end;

local function canSwitch()
    local manager = EditModeManagerFrame;
    return manager:IsInitialized() and not syncing and not InCombatLockdown() and not manager:IsEditModeActive() and
        not manager.overrideLayoutInfo;
end;

local function updateLayoutForGroup()
    local mainName = GoobyFrameTweaksVariables.RaidFrameGrowthMainLayout;
    if not mainName or not canSwitch() then return; end;

    local info = EditModeManagerFrame.layoutInfo;
    local members = IsInRaid() and GetNumGroupMembers() or 0;
    local tier = sizeTiers[#sizeTiers];
    for _, candidate in ipairs(sizeTiers) do
        if members <= candidate.maxMembers then
            tier = candidate;
            break;
        end;
    end;

    local tierIndex = hasOverrides(tier) and findLayout(info.layouts, tierLayoutName(tier));
    local index = tierIndex or findLayout(info.layouts, mainName);
    if index and index ~= info.activeLayout then
        C_EditMode.SetActiveLayout(index);
    end;
end;

-- the non-tier layout is the one copies are made from
local function refreshLayouts()
    local manager = EditModeManagerFrame;
    if not manager:IsInitialized() or syncing or manager.overrideLayoutInfo then return; end;

    local info = manager.layoutInfo;
    local active = info.layouts[info.activeLayout];
    if active and not isTierLayoutName(active.layoutName) then
        GoobyFrameTweaksVariables.RaidFrameGrowthMainLayout = active.layoutName;
    end;

    if InCombatLockdown() or manager:IsEditModeActive() then return; end;
    -- saving and switching both rebuild the raid frames, so split them over separate frames
    if syncLayouts() then
        C_Timer.After(0.5, updateLayoutForGroup);
    else
        updateLayoutForGroup();
    end;
end;

-- exiting edit mode fires several triggers in the same frame
local refreshScheduled = false;
local function scheduleRefresh()
    if refreshScheduled then return; end;
    refreshScheduled = true;
    C_Timer.After(0, function()
        refreshScheduled = false;
        refreshLayouts();
    end);
end;

function core:initializeRaidFrameLayouts()
    local updateScheduled = false;
    local function scheduleGroupUpdate()
        if updateScheduled then return; end;
        updateScheduled = true;
        C_Timer.After(1, function()
            updateScheduled = false;
            updateLayoutForGroup();
        end);
    end;

    local events = CreateFrame("Frame");
    events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED");
    events:RegisterEvent("PLAYER_ENTERING_WORLD");
    events:RegisterEvent("GROUP_ROSTER_UPDATE");
    events:RegisterEvent("PLAYER_REGEN_ENABLED");
    events:SetScript("OnEvent", function(_, event)
        if event == "GROUP_ROSTER_UPDATE" then
            scheduleGroupUpdate();
        elseif not syncing then
            scheduleRefresh();
        end;
    end);

    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        C_Timer.After(0, function()
            local info = EditModeManagerFrame.layoutInfo;
            local active = info.layouts[info.activeLayout];
            local mainIndex = findLayout(info.layouts, GoobyFrameTweaksVariables.RaidFrameGrowthMainLayout);
            if active and isTierLayoutName(active.layoutName) and mainIndex then
                C_EditMode.SetActiveLayout(mainIndex);
            end;
        end);
    end);
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", scheduleRefresh);

    scheduleRefresh();
end;
