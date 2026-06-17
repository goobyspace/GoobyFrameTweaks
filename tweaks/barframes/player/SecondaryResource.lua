local _, core = ...

local frame;

local function getResource()
    local playerClass = select(2, UnitClass("player"))
    local resourceTable = core.resources.secondary;

    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = C_SpecializationInfo.GetSpecializationInfo(spec)

    local resource = resourceTable[playerClass];

    -- Druid: form-based
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        resource = resource["DRUID"][formID or 0]
    end

    if type(resource) == "table" then
        return resource[specID]
    else
        return resource
    end
end

local nextEssenceTick = nil;
local lastEssence = nil;
local startTime = nil;

local function updateBar()
    local resource = getResource()
    if not resource then return end;

    if resource == Enum.PowerType.Essence then
        for i = 1, 6 do
            -- hide just incase
            frame['bar' .. i]:Hide();
            frame['bg' .. i]:Hide();
        end

        local current = UnitPower("player", resource);
        local max = UnitPowerMax("player", resource);
        local regenRate = GetPowerRegenForPowerType(resource);

        local gap = 6;
        local barWidth = 370 / max - gap;
        local offset = gap + (gap / max);

        if issecretvalue(regenRate) then
            regenRate = 0.2;
        end

        lastEssence = lastEssence or current;

        local tickDuration = 5 / (5 / (1 / regenRate))
        local now = GetTime()

        -- If we gained an essence, reset timer
        if current > lastEssence then
            if current < max then
                startTime = now;
                nextEssenceTick = now + tickDuration
            else
                startTime = nil;
                nextEssenceTick = nil
            end
        end

        -- If missing essence and no timer, start it
        if current < max and not nextEssenceTick then
            startTime = now;
            nextEssenceTick = now + tickDuration
        end

        -- If full essence, hide timer
        if current >= max then
            startTime = nil;
            nextEssenceTick = nil
        end

        lastEssence = current

        local duration;
        if nextEssenceTick and startTime then
            duration = C_DurationUtil.CreateDuration();
            duration:SetTimeSpan(startTime, nextEssenceTick);
        end

        for i = 1, max do
            frame['container' .. i]:ClearAllPoints();
            frame['container' .. i]:SetSize(barWidth, 10);
            frame['container' .. i]:SetPoint("LEFT", frame, "LEFT", (i - 1) * (barWidth + offset), 0);

            frame["bg" .. i]:Show();
            frame["bg" .. i]:SetSize(barWidth, 10);

            local bar = frame["bar" .. i];
            bar:Show();
            bar:SetSize(barWidth - 4, 6);

            bar:SetMinMaxValues(0, 1)
            if i <= current then
                bar:SetValue(1, Enum.StatusBarInterpolation.ExponentialEaseOut);
            elseif i == current + 1 then
                bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.ExponentialEaseOut);
            else
                bar:SetValue(0, Enum.StatusBarInterpolation.ExponentialEaseOut);
            end
        end
    end
end

local globalAuraID;

local function updateEnrage(auraInstanceID)
    local resource = getResource()
    if not resource then return end;

    if resource == "ENRAGE" then
        if not frame or not frame:IsShown() then return end;

        local resource = getResource();
        if not resource then return end;

        local color = core.resources.resourceColours[resource];

        local duration = C_UnitAuras.GetAuraDuration("player", auraInstanceID);
        if duration then
            globalAuraID = auraInstanceID;
            frame.bar:SetStatusBarColor(color.r / 255, color.g / 255, color.b / 255);
            frame.bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.ExponentialEaseOut);
            --frame.text:SetFormattedText("%.1f%s", duration:GetRemainingDuration())
        else
            frame.bar:SetMinMaxValues(0, 0);
            frame.bar:SetValue(0);
            frame.text:SetText("");
        end
    end
end

local function refreshEnrage()
    if globalAuraID then
        print(globalAuraID)
        updateEnrage(globalAuraID);
    end
end

local function updateColour()
    local resource = getResource()
    if not resource then return end;

    local color = core.resources.resourceColours[resource];
    if resource == Enum.PowerType.Essence then
        for i = 1, 6 do
            frame['bar' .. i]:SetStatusBarColor(color.r / 255, color.g / 255, color.b / 255)
        end
    end
end

function core:CreateSecondaryBar(parent)
    frame = CreateFrame("Frame", "PrimaryResourceContainer", parent)
    frame:SetSize(370, 10);

    local playerClass = select(2, UnitClass("player"))

    if playerClass == "EVOKER" then
        -- with talents evoker max essence count can be 6 so we need 6 frames
        for i = 1, 6 do
            frame['container' .. i] = CreateFrame("Frame", nil, frame);

            frame['bg' .. i] = frame['container' .. i]:CreateTexture();
            local bg = frame['bg' .. i];
            bg:SetPoint("CENTER");
            bg:SetTexture(134532)
            bg:SetColorTexture(0, 0, 0);
            bg:SetSize(100, 10);
            bg:SetDrawLayer("OVERLAY", -1);

            frame['bar' .. i] = CreateFrame("StatusBar", nil, frame['container' .. i]);
            local bar = frame['bar' .. i];
            bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar");
            bar:SetPoint("CENTER");
            bar:SetSize(100, 6);

            bg:Hide();
            bar:Hide();
        end
    end

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player")
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    frame:RegisterEvent("PET_BATTLE_OPENING_START")
    frame:RegisterEvent("PET_BATTLE_CLOSE")

    if playerClass == "DRUID" then
        frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end

    local hidden = true;

    function frame:SetHidden(hidden)
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        local unit = ...;
        if event == "PLAYER_ENTERING_WORLD"
            or event == "UPDATE_SHAPESHIFT_FORM"
            or (event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit == "player") then
            local resource = getResource();
            if resource then
                hidden = false;
                frame:SetHidden(false);
            else
                hidden = true;
                frame:SetHidden(true);
                return
            end;

            updateColour();
        end
        if hidden then return end;

        updateBar();
    end)

    return frame;
end
