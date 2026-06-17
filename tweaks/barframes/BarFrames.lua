local _, core = ...

function core:InitializeBarFrames()
    -- hide defaults
    PlayerFrame:SetScript("OnEvent", nil);
    PlayerFrame:Hide();

    local playerFrame = CreateFrame("Frame", "PlayerFrameContainer", UIParent)
    playerFrame:SetSize(370, 46);
    playerFrame:SetPoint("CENTER", 0, -230);

    -- temporary bg to show full size
    playerFrame.bg = playerFrame:CreateTexture();
    playerFrame.bg:SetPoint("CENTER");
    playerFrame.bg:SetColorTexture(0, 0, 0, 0.1);
    playerFrame.bg:SetSize(370, 46);

    playerFrame.click = CreateFrame("Button", "PlayerFrameTarget", playerFrame, "SecureActionButtonTemplate")
    playerFrame.click:SetPoint("CENTER");
    playerFrame.click:SetSize(370, 46);
    playerFrame.click:SetAttribute("unit", "player")
    playerFrame.click:SetAttribute("type1", "target")
    playerFrame.click:SetAttribute("type2", "togglemenu")
    playerFrame.click:RegisterForClicks("AnyUp", "AnyDown")

    local widgets = core:CreateWidgets(playerFrame);
    widgets:SetPoint("BOTTOM")

    local primaryResourceBar = core:CreatePrimaryBar(playerFrame)
    primaryResourceBar:SetPoint("BOTTOM")

    local secondaryResourceBar = core:CreateSecondaryBar(playerFrame);
    if secondaryResourceBar then
        secondaryResourceBar:SetPoint("BOTTOM", 0, 18);
    end

    local tertiaryHeight = secondaryResourceBar:IsShown() and 36 or 18;

    local hpBar = core:CreateHPBar(playerFrame);
    hpBar:SetPoint("BOTTOM", 135, tertiaryHeight)


    function secondaryResourceBar:SetHidden(hidden)
        if hidden then
            secondaryResourceBar:Hide();
            tertiaryHeight = 18;
        else
            secondaryResourceBar:Show();
            tertiaryHeight = 36;
        end
        hpBar:SetPoint("BOTTOM", 135, tertiaryHeight)
    end

    -- player frame
    -- big ol bar with HP
    -- cast bar
    -- target of target
    -- pet HP/power
    -- resources (like rage/essence/mana)
    -- any other weakaura like features (enrage bar?)

    -- target frame
    -- big ol HP bar
    -- cast bar
    -- mana/other power resource
    -- target of target
end
