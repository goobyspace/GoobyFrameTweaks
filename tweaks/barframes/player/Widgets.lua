local _, core = ...;

local frame;

local function checkAfk()
    frame.afk:SetShown(UnitIsAFK("player"));
end

local function checkCombat()
    frame.combat:SetShown(PlayerIsInCombat());
end

local function checkRested()
    -- 1 = rested 2 = normal
    local rested = GetRestState();
    print(rested);
    if rested == 1 then
        frame.restedGroup:Play()
        frame.restedFrame:Show();
        print(frame.restedGroup:IsPlaying());
    else
        frame.restedGroup:Stop()
        frame.restedFrame:Hide();
    end
end

local function checkPvP()
    local isFreeForAll = UnitIsPVPFreeForAll("player")
    local isPvP = UnitIsPVP("player")
    local faction = UnitFactionGroup("player")

    if isFreeForAll then
        frame.ffaPvP:Show();
        frame.alliancePvP:Hide();
        frame.hordePvP:Hide();
    elseif isPvP then
        if faction == "Alliance" then
            frame.ffaPvP:Hide();
            frame.alliancePvP:Show();
            frame.hordePvP:Hide();
        elseif faction == "Horde" then
            frame.ffaPvP:Hide();
            frame.alliancePvP:Hide();
            frame.hordePvP:Show();
        end
    else
        frame.ffaPvP:Hide();
        frame.alliancePvP:Hide();
        frame.hordePvP:Hide();
    end
end

function core:CreateWidgets(parent)
    frame = CreateFrame("Frame", nil, parent);
    frame:SetSize(370, 1);

    frame.afk = frame:CreateTexture();
    frame.afk:SetPoint("CENTER", -193, 4);
    frame.afk:SetTexture("interface/FriendsFrame/StatusIcon-Away");
    frame.afk:SetSize(16, 16);

    frame.combat = frame:CreateTexture();
    frame.combat:SetPoint("CENTER", 193, 6);
    frame.combat:SetTexture("interface/FriendsFrame/StatusIcon-Away");
    frame.combat:SetSize(8, 8);

    do -- rested
        frame.restedFrame = CreateFrame("Frame", nil, frame);
        frame.restedFrame:SetSize(20, 20);
        frame.restedFrame:SetPoint("CENTER", -185, 16);

        frame.restedTexture = frame.restedFrame:CreateTexture(nil, "OVERLAY");
        frame.restedTexture:SetSize(20, 20);
        frame.restedTexture:SetPoint("CENTER");
        frame.restedTexture:SetTexture("Interface\\HUD\\UI-HUD-UnitFrame-Player-Rest-Flipbook");
        frame.restedTexture:SetParentKey("FlipBookRestedTexture")

        frame.restedGroup = frame.restedTexture:CreateAnimationGroup();
        frame.restedAnim = frame.restedGroup:CreateAnimation("FlipBook");

        frame.restedAnim:SetFlipBookRows(4);
        frame.restedAnim:SetFlipBookColumns(4);
        frame.restedAnim:SetDuration(2.0);
        frame.restedAnim:SetFlipBookFrames(8);
        frame.restedAnim:SetChildKey("FlipBookRestedTexture")

        frame.restedGroup:SetLooping("REPEAT");

        frame.restedFrame:Show();
        frame.restedTexture:Show();
        frame.restedGroup:Play();
        frame.restedAnim:Play();
    end

    do -- pvp
        frame.ffaPvP = frame:CreateTexture();
        frame.ffaPvP:SetPoint("CENTER", 178, 8);
        frame.ffaPvP:SetTexture("interface/TARGETINGFRAME/UI-PVP-FFA");
        frame.ffaPvP:SetSize(8, 8);

        frame.hordePvP = frame:CreateTexture();
        frame.hordePvP:SetPoint("CENTER", 178, 8);
        frame.hordePvP:SetTexture("interface/TARGETINGFRAME/UI-PVP-Horde");
        frame.hordePvP:SetSize(8, 8);

        frame.alliancePvP = frame:CreateTexture();
        frame.alliancePvP:SetPoint("CENTER", 178, 8);
        frame.alliancePvP:SetTexture("interface/TARGETINGFRAME/UI-PVP-Alliance");
        frame.alliancePvP:SetSize(8, 8);
    end

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PET_BATTLE_OPENING_START")
    frame:RegisterEvent("PET_BATTLE_CLOSE")
    frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED");
    frame:RegisterEvent("ZONE_CHANGED_INDOORS");
    frame:RegisterEvent("PLAYER_FLAGS_CHANGED");
    frame:RegisterEvent("PLAYER_IN_COMBAT_CHANGED");

    frame:SetScript("OnEvent", function(_, event)
        if event == "ZONE_CHANGED" then
            checkRested();
        elseif event == "ZONE_CHANGED_INDOORS" then
            checkRested();
        elseif event == "PLAYER_FLAGS_CHANGED" then
            checkRested();
            checkAfk();
            checkPvP();
        elseif event == "PLAYER_IN_COMBAT_CHANGED" then
            checkCombat();
        else
            checkRested();
            checkAfk();
            checkPvP();
            checkCombat();
        end
    end)
    return frame;
end
