local _, core = ...

local frame = nil;

local function getResource()
    local playerClass = select(2, UnitClass("player"))


    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = C_SpecializationInfo.GetSpecializationInfo(spec)

    local resource = core.resources.primary[playerClass]

    -- Druid: form-based
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        resource = resource and resource[formID or 0]
    end

    if type(resource) == "table" then
        return resource[specID]
    else
        return resource
    end
end

local function getResourceValue(resource)
    if not resource then return nil, nil end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil end

    return max, current
end

local function updateBar()
    if not frame or not frame:IsShown() then return end;

    local resource = getResource();
    if not resource then return end;

    local max, current = getResourceValue(resource);
    if not max then
        return frame:Hide();
    end
    if not current then current = 0; end

    local formattedString = "%.0f";
    if max > 1000 then
        -- if its over a thousand always turn it into a percentage
        current = max / current * 100;
        max = 100;
        formattedString = "%.0f %%"
    end

    frame.bar:SetMinMaxValues(0, max, Enum.StatusBarInterpolation.ExponentialEaseOut);
    frame.bar:SetValue(current, Enum.StatusBarInterpolation.ExponentialEaseOut);
    frame.text:SetFormattedText(formattedString, current);
end

local function updateColour()
    -- this is always a bar so we only need to worry about colour
    if not frame or not frame:IsShown() then return end;

    local resource = getResource();
    if not resource then return end;

    local color = core.resources.resourceColours[resource];

    frame.bar:SetStatusBarColor(color.r / 255, color.g / 255, color.b / 255)
end

function core:CreatePrimaryBar(parent)
    frame = CreateFrame("Frame", "PrimaryResourceContainer", parent)
    frame:SetSize(370, 10);

    frame.bg = frame:CreateTexture();
    frame.bg:SetPoint("CENTER");
    frame.bg:SetTexture(134532)
    frame.bg:SetColorTexture(0, 0, 0);
    frame.bg:SetSize(370, 10);
    frame.bg:SetDrawLayer("OVERLAY", -1);

    frame.bar = CreateFrame("StatusBar", nil, frame);
    frame.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar");
    frame.bar:SetPoint("CENTER");
    frame.bar:SetSize(366, 6);

    frame.text = frame.bar:CreateFontString("PrimaryText");
    frame.text:SetDrawLayer("OVERLAY", 1);
    frame.text:SetPoint("CENTER", 0, 4);
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    frame:RegisterEvent("UNIT_POWER_FREQUENT")
    frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    frame:RegisterEvent("PET_BATTLE_OPENING_START")
    frame:RegisterEvent("PET_BATTLE_CLOSE")
    frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

    local playerClass = select(2, UnitClass("player"))

    if playerClass == "DRUID" then
        frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_ENTERING_WORLD"
            or event == "UPDATE_SHAPESHIFT_FORM"
            or (event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit == "player") then
            updateColour();
        end
        updateBar();
    end)

    return frame;
end
