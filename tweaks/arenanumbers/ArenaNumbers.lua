local _, core = ...

-- for some reason the vs code extension i use doesnt recognize unitframe.unit even though its like, literally what its called
-- idk why but code works thumbsup emoji

-- for transparency sake this is lifted straight from betterblizzplates, im not rebuilding all this
-- the basics is that we first check if every nameplate has the same race/gender/spec/power as arena1 (and 2 and 3)
-- if we can narrow that down to only 1 match then job done we know which nameplate is arena1 put the number on chief
-- if we cannot narrow it down then every time target or mouseover changes, and its arena123, then check what nameplate is also the target/mouseover
-- and then store that
-- tada
local unsafeUnits = {}
for i = 1, 40 do
    unsafeUnits["boss" .. i] = true
    unsafeUnits["boss" .. i .. "target"] = true
    unsafeUnits["boss" .. i .. "targettarget"] = true
    unsafeUnits["raid" .. i] = true
    unsafeUnits["raidpet" .. i] = true
    unsafeUnits["raidpet" .. i .. "target"] = true
    unsafeUnits["raidpet" .. i .. "targettarget"] = true
    unsafeUnits["raid" .. i .. "target"] = true
    unsafeUnits["raid" .. i .. "targettarget"] = true
    unsafeUnits["nameplate" .. i .. "target"] = true
    unsafeUnits["nameplate" .. i .. "targettarget"] = true
end
for i = 1, 5 do
    unsafeUnits["party" .. i] = true
    unsafeUnits["party" .. i .. "target"] = true
    unsafeUnits["party" .. i .. "targettarget"] = true
    unsafeUnits["partypet" .. i] = true
    unsafeUnits["partypet" .. i .. "target"] = true
    unsafeUnits["partypet" .. i .. "targettarget"] = true
end
for i = 1, 5 do
    unsafeUnits["arena" .. i] = true
    unsafeUnits["arena" .. i .. "target"] = true
    unsafeUnits["arena" .. i .. "targettarget"] = true
    unsafeUnits["arenapet" .. i] = true
    unsafeUnits["arenapet" .. i .. "target"] = true
    unsafeUnits["arenapet" .. i .. "targettarget"] = true
end
unsafeUnits["targettarget"] = true
unsafeUnits["focustarget"]  = true

local function getSafeNameplate(unitToken)
    if unsafeUnits[unitToken] then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken, issecure())
    if not nameplate or not nameplate.UnitFrame then return nil, nil end

    local frame = nameplate.UnitFrame
    return nameplate, frame
end

local UnitIsUnit           = UnitIsUnit
local GetArenaOpponentSpec = GetArenaOpponentSpec

local arenaCache           = {} -- [1..3] = { class, race, sex, power, spec }
local plateToIndex         = {} -- [plate]      = arenaIndex
local indexToPlate         = {} -- [arenaIndex] = plate
local isInArena            = false;

local function safeVal(v)
    if v == nil or issecretvalue(v) then return nil end
    return v
end

local function readUnitProps(unit)
    local _, class = UnitClass(unit)
    local _, race  = UnitRace(unit)
    return {
        class = safeVal(class),
        race  = safeVal(race),
        sex   = safeVal(UnitSex(unit)),
        power = safeVal(UnitPowerType(unit)),
    }
end

local function isValidEnemy(unit)
    return unit
        and UnitIsPlayer(unit)
        and UnitIsEnemy("player", unit)
        and not UnitIsPossessed(unit)
end

local function cacheArenaIndex(idx)
    local arenaUnit = "arena" .. idx
    if not UnitExists(arenaUnit) then
        local specID = GetArenaOpponentSpec(idx)
        if specID and specID ~= 0 then
            local _, _, _, _, _, classFile = GetSpecializationInfoByID(specID)
            arenaCache[idx] = arenaCache[idx] or {}
            arenaCache[idx].spec = specID
            if classFile then arenaCache[idx].class = classFile end
        end
        return
    end
    local props = readUnitProps(arenaUnit)
    local specID = GetArenaOpponentSpec(idx)
    if specID and specID ~= 0 then
        props.spec = specID
        if not props.class then
            local _, _, _, _, _, classFile = GetSpecializationInfoByID(specID)
            if classFile then props.class = classFile end
        end
    end

    if arenaCache[idx] then
        for k, v in pairs(props) do
            if v then arenaCache[idx][k] = v end
        end
    else
        arenaCache[idx] = props
    end
end

local function buildArenaCache()
    local numSpecs = GetNumArenaOpponentSpecs and GetNumArenaOpponentSpecs() or 0
    for i = 1, 3 do
        if numSpecs >= i or UnitExists("arena" .. i) then
            cacheArenaIndex(i)
        end
    end
end

local function wipePlateMappings()
    for plate in pairs(plateToIndex) do
        if plate.UnitFrame then
            plate.UnitFrame.arenaID = nil
        end
    end
    wipe(plateToIndex)
    wipe(indexToPlate)
end

local function wipeArenaState()
    wipe(arenaCache)
    wipePlateMappings()
end

local function propsMatch(unitProps, idx)
    local cached = arenaCache[idx]
    if not cached then return nil end

    local checked = 0
    if unitProps.class and cached.class then
        if unitProps.class ~= cached.class then return false end
        checked = checked + 1
    end
    if unitProps.race and cached.race then
        if unitProps.race ~= cached.race then return false end
        checked = checked + 1
    end
    if unitProps.sex and cached.sex then
        if unitProps.sex ~= cached.sex then return false end
        checked = checked + 1
    end
    if unitProps.power and cached.power then
        if unitProps.power ~= cached.power then return false end
        checked = checked + 1
    end

    return checked > 0 and true or nil
end

local function resolveIndex(props, cache, candidates)
    if #candidates == 0 then return nil end

    if #candidates == 1 then
        local c = cache[candidates[1]]
        if not c then return nil end
        if props.class and c.class and props.class ~= c.class then return nil end
        if props.race and c.race and props.race ~= c.race then return nil end
        if props.power ~= nil and c.power ~= nil and props.power ~= c.power then return nil end
        if props.sex and c.sex and props.sex ~= c.sex then return nil end
        return candidates[1]
    end

    local remaining = {}
    for _, idx in ipairs(candidates) do
        local c = cache[idx]
        if c then
            local dominated = false
            if props.class and c.class and props.class ~= c.class then dominated = true end
            if props.race and c.race and props.race ~= c.race then dominated = true end
            if props.power ~= nil and c.power ~= nil and props.power ~= c.power then dominated = true end
            if props.sex and c.sex and props.sex ~= c.sex then dominated = true end
            if not dominated then
                remaining[#remaining + 1] = idx
            end
        end
    end

    if #remaining == 0 then return nil end
    if #remaining == 1 then return remaining[1] end

    if props.class then
        local narrowed = {}
        for _, idx in ipairs(remaining) do
            if not cache[idx].class or cache[idx].class == props.class then
                narrowed[#narrowed + 1] = idx
            end
        end
        if #narrowed == 1 then return narrowed[1] end
        if #narrowed > 1 then remaining = narrowed end
    end

    if props.race then
        local narrowed = {}
        for _, idx in ipairs(remaining) do
            if not cache[idx].race or cache[idx].race == props.race then
                narrowed[#narrowed + 1] = idx
            end
        end
        if #narrowed == 1 then return narrowed[1] end
        if #narrowed > 1 then remaining = narrowed end
    end

    if props.power ~= nil then
        local narrowed = {}
        for _, idx in ipairs(remaining) do
            if cache[idx].power == nil or cache[idx].power == props.power then
                narrowed[#narrowed + 1] = idx
            end
        end
        if #narrowed == 1 then return narrowed[1] end
        if #narrowed > 1 then remaining = narrowed end
    end

    if props.sex then
        local narrowed = {}
        for _, idx in ipairs(remaining) do
            if not cache[idx].sex or cache[idx].sex == props.sex then
                narrowed[#narrowed + 1] = idx
            end
        end
        if #narrowed == 1 then return narrowed[1] end
        if #narrowed > 1 then remaining = narrowed end
    end

    if #remaining == 1 then return remaining[1] end
    return nil
end

local function tagPlate(plate, idx)
    local oldIdx = plateToIndex[plate]
    if oldIdx and oldIdx ~= idx then
        indexToPlate[oldIdx] = nil
    end
    local oldPlate = indexToPlate[idx]
    if oldPlate and oldPlate ~= plate then
        plateToIndex[oldPlate] = nil
        if oldPlate.UnitFrame then oldPlate.UnitFrame.arenaID = nil end
    end

    plateToIndex[plate] = idx
    indexToPlate[idx]   = plate
    if plate.UnitFrame then plate.UnitFrame.arenaID = idx end
end

local function untagPlate(plate)
    local idx = plateToIndex[plate]
    if idx then indexToPlate[idx] = nil end
    plateToIndex[plate] = nil
    if plate.UnitFrame then plate.UnitFrame.arenaID = nil end
end

local function tryTagByFingerprint(plate)
    local frame = plate.UnitFrame
    if not frame or not frame.unit then return false end
    if not isValidEnemy(frame.unit) then return false end
    if plateToIndex[plate] then return true end

    local props = readUnitProps(frame.unit)

    local allIndices = {}
    for i = 1, 3 do
        if arenaCache[i] then allIndices[#allIndices + 1] = i end
    end
    local idx = resolveIndex(props, arenaCache, allIndices)
    if idx then
        tagPlate(plate, idx)
        return true
    end

    local untaggedIndices = {}
    for i = 1, 3 do
        if arenaCache[i] and not indexToPlate[i] then
            untaggedIndices[#untaggedIndices + 1] = i
        end
    end
    idx = resolveIndex(props, arenaCache, untaggedIndices)
    if idx then
        tagPlate(plate, idx)
        return true
    end

    return false
end

local function learnViaIntermediary(plate, intermediary)
    local frame = plate.UnitFrame
    if not frame or not frame.unit then return false end
    if not isValidEnemy(frame.unit) then return false end
    if not UnitIsUnit(frame.unit, intermediary) then return false end

    for i = 1, 3 do
        if UnitIsUnit(intermediary, "arena" .. i) then
            local props = readUnitProps(frame.unit)
            local specID = GetArenaOpponentSpec(i)
            if specID and specID ~= 0 then props.spec = specID end
            if not arenaCache[i] then arenaCache[i] = {} end
            for k, v in pairs(props) do
                if v then arenaCache[i][k] = v end
            end
            tagPlate(plate, i)
            return true
        end
    end
    return false
end

local function tryElimination()
    for _ = 1, 2 do
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if not plateToIndex[plate] then
                local frame = plate.UnitFrame
                if frame and frame.unit and isValidEnemy(frame.unit) then
                    local props = readUnitProps(frame.unit)
                    local matchIdx, matchCount = nil, 0
                    for i = 1, 3 do
                        if arenaCache[i] and not indexToPlate[i] then
                            if propsMatch(props, i) ~= false then
                                matchCount = matchCount + 1
                                matchIdx = i
                                if matchCount > 1 then break end
                            end
                        end
                    end
                    if matchCount == 1 then
                        tagPlate(plate, matchIdx)
                    end
                end
            end
        end
    end
end

local function refreshAll()
    if not isInArena then return end

    for plate, idx in pairs(plateToIndex) do
        local frame = plate.UnitFrame
        if not frame or not frame.unit or not isValidEnemy(frame.unit) then
            untagPlate(plate)
        else
            if propsMatch(readUnitProps(frame.unit), idx) == false then
                untagPlate(plate)
            end
        end
    end

    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if not plateToIndex[plate] then
            local frame = plate.UnitFrame
            if frame and frame.unit and isValidEnemy(frame.unit) then
                if not learnViaIntermediary(plate, "target")
                    and not learnViaIntermediary(plate, "focus")
                    and not learnViaIntermediary(plate, "mouseover") then
                    tryTagByFingerprint(plate)
                end
            end
        end
    end

    tryElimination()
end

local function onPlateAdded(unitToken)
    if not isInArena then return end
    local plate, frame = getSafeNameplate(unitToken)
    if not frame then return end
    local unit = frame.unit
    if not unit or not isValidEnemy(unit) then return end

    if plateToIndex[plate] then
        local idx = plateToIndex[plate]
        if propsMatch(readUnitProps(unit), idx) == false then
            untagPlate(plate)
        else
            return
        end
    end

    if not learnViaIntermediary(plate, "target")
        and not learnViaIntermediary(plate, "focus")
        and not learnViaIntermediary(plate, "mouseover") then
        tryTagByFingerprint(plate)
    end

    tryElimination()
end

local function onIntermediaryChanged(intermediary)
    if not isInArena then return end
    if not UnitExists(intermediary) then return end

    local arenaIdx
    for i = 1, 3 do
        if UnitIsUnit(intermediary, "arena" .. i) then
            arenaIdx = i
            break
        end
    end
    if not arenaIdx then return end

    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local frame = plate.UnitFrame
        if not frame or not frame.unit then
            -- skip
        elseif UnitIsUnit(frame.unit, intermediary) and isValidEnemy(frame.unit) then
            learnViaIntermediary(plate, intermediary)
        elseif plateToIndex[plate] == arenaIdx then
            untagPlate(plate)
        end
    end

    refreshAll()
end


local function getArenaNumber(frame)
    if not frame.unit then return nil end
    if frame.arenaID then return frame.arenaID end
    local plate = getSafeNameplate(frame.unit)
    if not plate then return nil end
    return plateToIndex[plate]
end

local function updateNameplate(frame)
    local arenaNumber = getArenaNumber(frame)

    if not arenaNumber then
        Platynator.API.SetUnitTextOverride(frame.unit, nil, nil);
        return
    end

    Platynator.API.SetUnitTextOverride(frame.unit, arenaNumber, nil);
end

local function updateNameplateByUnit(unitToken)
    local plate = getSafeNameplate(unitToken);
    if not plate then return end;
    local arenaNumber = plateToIndex[plate];

    if not arenaNumber then
        Platynator.API.SetUnitTextOverride(unitToken, nil, nil);
        return
    end

    Platynator.API.SetUnitTextOverride(unitToken, arenaNumber, nil);
end


function core:initializeArenaNumbers()
    if not Platynator or not Platynator.API then
        return false;
    end

    local requirements = {
        Platynator.API.SetUnitTextOverride,
    };

    for _, func in ipairs(requirements) do
        if func == nil then
            return false;
        end
    end

    local instanceEvent = CreateFrame("Frame")
    instanceEvent:RegisterEvent("PLAYER_ENTERING_WORLD")
    instanceEvent:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    instanceEvent:RegisterEvent("ZONE_CHANGED")
    instanceEvent:SetScript("OnEvent", function()
        local inInstance, instanceType = IsInInstance()
        isInArena = inInstance and (instanceType == "arena")
    end)

    local events = CreateFrame("Frame");
    events:RegisterEvent("PVP_MATCH_STATE_CHANGED")
    events:RegisterEvent("PVP_MATCH_ACTIVE")
    events:RegisterEvent("ARENA_OPPONENT_UPDATE")
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("PLAYER_FOCUS_CHANGED")
    events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function(_, event, unitToken)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, function()
                if not isInArena then return end
                buildArenaCache()
                refreshAll()
                for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                    local frame = plate and plate.UnitFrame
                    if frame and frame.unit then
                        updateNameplate(frame)
                    end
                end
            end)
            return
        end

        if event == "PVP_MATCH_STATE_CHANGED" then
            local state = C_PvP.GetActiveMatchState()
            if state == Enum.PvPMatchState.Inactive
                or state == Enum.PvPMatchState.Waiting
                or state == Enum.PvPMatchState.StartUp
                or state == Enum.PvPMatchState.PostRound then
                wipeArenaState()
            elseif state == Enum.PvPMatchState.Engaged then
                wipePlateMappings()
                buildArenaCache()
                refreshAll()
            end
            return
        end

        if event == "PVP_MATCH_ACTIVE" then
            wipeArenaState()
            buildArenaCache()
            refreshAll()
            return
        end

        if not isInArena then return end

        if event == "ARENA_OPPONENT_UPDATE" then
            buildArenaCache()
            local state = C_PvP.GetActiveMatchState()
            if state == Enum.PvPMatchState.Engaged then
                refreshAll()
            end
            return
        end

        if event == "NAME_PLATE_UNIT_ADDED" then
            onPlateAdded(unitToken)
            updateNameplateByUnit(unitToken)
            return
        end

        if event == "NAME_PLATE_UNIT_REMOVED" then
            if unitToken then
                local plate, frame = getSafeNameplate(unitToken)
                if plate then
                    untagPlate(plate)
                end
            end
            return
        end

        if event == "PLAYER_TARGET_CHANGED" then
            onIntermediaryChanged("target")
            return
        end

        if event == "PLAYER_FOCUS_CHANGED" then
            onIntermediaryChanged("focus")
            return
        end

        if event == "UPDATE_MOUSEOVER_UNIT" then
            onIntermediaryChanged("mouseover")
            return
        end
    end);
end
