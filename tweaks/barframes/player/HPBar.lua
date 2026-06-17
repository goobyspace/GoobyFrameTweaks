local _, core = ...

local frame = nil;

local function UpdateBar()
    if not frame or not frame:IsShown() then return end;

    -- hp:
    local maxHP = UnitHealthMax("player");
    local currentHP = UnitHealth("player");
    local percentHP = UnitHealthPercent("player", true, CurveConstants.ScaleTo100);
    if not maxHP then
        return frame:Hide();
    end

    local formattedString = "%.0f%%";

    if type(percentHP) ~= "number" then
        percentHP = 0;
    end

    frame.bar:SetMinMaxValues(0, maxHP, Enum.StatusBarInterpolation.ExponentialEaseOut);
    frame.bar:SetValue(currentHP, Enum.StatusBarInterpolation.ExponentialEaseOut);
    frame.text:SetFormattedText(formattedString, percentHP);

    -- healing absorb:
    local absorb = UnitGetTotalAbsorbs("player") or 0;
    if frame.absorbBar:IsShown() then
        frame.absorbBar:SetMinMaxValues(0, select(2, frame.bar:GetMinMaxValues()),
            Enum.StatusBarInterpolation.ExponentialEaseOut)
        frame.absorbBar:SetValue(absorb,
            Enum.StatusBarInterpolation.ExponentialEaseOut)
    end

    local healAbsorb = UnitGetTotalHealAbsorbs("player") or 0;
    if frame.healAbsorbBar:IsShown() then
        frame.healAbsorbBar:SetMinMaxValues(0, select(2, frame.bar:GetMinMaxValues()),
            Enum.StatusBarInterpolation.ExponentialEaseOut)
        frame.healAbsorbBar:SetValue(healAbsorb,
            Enum.StatusBarInterpolation.ExponentialEaseOut)
    end
end

function core:CreateHPBar(parent)
    frame = CreateFrame("Frame", "HPBarContainer", parent)
    frame:SetSize(100, 10);

    frame.bg = frame:CreateTexture();
    frame.bg:SetPoint("CENTER");
    frame.bg:SetTexture(134532)
    frame.bg:SetColorTexture(0, 0, 0);
    frame.bg:SetSize(100, 10);
    frame.bg:SetDrawLayer("OVERLAY", -1);

    frame.bar = CreateFrame("StatusBar", nil, frame);
    frame.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar");
    frame.bar:SetPoint("CENTER");
    frame.bar:SetSize(96, 6);
    frame.bar:SetStatusBarColor(200 / 255, 70 / 255, 100 / 255)

    frame.absorbBar = CreateFrame("StatusBar", nil, frame.bar)
    frame.absorbBar:SetPoint("CENTER");
    frame.absorbBar:SetSize(96, 6);
    frame.absorbBar:SetStatusBarTexture("Interface/Addons/GoobyFrameTweaks/tweaks/barframes/texture/absorb.png")
    frame.absorbBar:SetFrameLevel(frame.bar:GetFrameLevel() + 1)
    frame.absorbBar:SetStatusBarColor(1, 1, 1, 0.7)

    frame.healAbsorbBar = CreateFrame("StatusBar", nil, frame.bar)
    frame.healAbsorbBar:SetPoint("CENTER");
    frame.healAbsorbBar:SetSize(96, 6);
    frame.healAbsorbBar:SetStatusBarTexture("interface/RAIDFRAME/RaidFrameAbsorbOverlay")
    frame.healAbsorbBar:SetFrameLevel(frame.bar:GetFrameLevel() + 1)
    frame.healAbsorbBar:SetStatusBarColor(1, 1, 1, 0.7)

    frame.textframe = CreateFrame("Frame", nil, frame.bar);
    frame.textframe:SetFrameLevel(frame.bar:GetFrameLevel() + 2)
    frame.text = frame.textframe:CreateFontString("PrimaryText");
    frame.text:SetDrawLayer("OVERLAY", 1);
    frame.text:SetPoint("CENTER", 0, 4);
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    frame:RegisterUnitEvent("UNIT_HEALTH", "player")
    frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "player")
    frame:RegisterEvent("PET_BATTLE_OPENING_START")
    frame:RegisterEvent("PET_BATTLE_CLOSE")

    local playerClass = select(2, UnitClass("player"))

    if playerClass == "DRUID" then
        frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    end

    frame:SetScript("OnEvent", function()
        UpdateBar();
    end)

    return frame;
end
