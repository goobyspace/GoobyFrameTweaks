local _, core = ...;

-- edit mode setters taint health code, so we place the frames ourselves after every blizzard layout instead
local flowBounds;

local function fixBorder(container)
    if flowBounds and container.borderFrame:IsShown() then
        container.borderFrame:SetSize(flowBounds.width + 11, flowBounds.height + 13);
    end;
end;

local function differs(a, b)
    return issecretvalue(a) or issecretvalue(b) or math.abs(a - b) > 0.01;
end;

-- mirrors FlowContainer_DoLayout minus atomic wrapping, returns nothing if a size is secret
local function flowLayout(container)
    local horizontal = container.flowOrientation == "horizontal";
    local maxPerLine = container.flowMaxPerLine;
    local horizontalSpacing, verticalSpacing = container.flowHorizontalSpacing or 0, container.flowVerticalSpacing or 0;
    local alongSpacing = horizontal and horizontalSpacing or verticalSpacing;
    local acrossSpacing = horizontal and verticalSpacing or horizontalSpacing;

    local layout = {};
    local along, across, lineThickness, inLine, stackOffset = 0, 0, 0, 1, nil;
    local lastWasGroup = false;
    for i = 1, #container.flowFrames do
        local kind, object = container.flowFrameTypes[i], container.flowFrames[i];
        local isGroup = kind == "object" and object.isFlowGroup;

        if kind == "linebreak" or (kind == "object" and (isGroup or lastWasGroup or (maxPerLine and inLine > maxPerLine))) then
            along, inLine = 0, 1;
            across = across + lineThickness + acrossSpacing;
            lineThickness = 0;
        end;

        if kind == "object" then
            local width, height = object:GetSize();
            if issecretvalue(width) or issecretvalue(height) then return; end;

            local x, y;
            if horizontal then
                x, y = along, across + (stackOffset or 0);
                -- a target stacks with its target of target instead of taking another slot
                stackOffset = object.frameType == "target" and not stackOffset and height or nil;
            else
                x, y = across, along;
            end;
            if not stackOffset then
                along = along + (horizontal and width or height) + alongSpacing;
            end;
            if object.frameType ~= "flagged" and object.frameType ~= "target" then
                inLine = inLine + 1;
            end;
            lineThickness = max(lineThickness, horizontal and height or width);

            tinsert(layout, { object = object, x = x, y = -y, width = width, height = height });
        end;
        lastWasGroup = isGroup;
    end;
    return layout;
end;

-- redoes blizzard's layout mirrored, retried from PLAYER_REGEN_ENABLED if locked down
local function mirrorLayout(container)
    if container ~= CompactRaidFrameContainer or container.flowPauseUpdates then return; end;
    if not container:CanChangeProtectedState() then return; end;

    for i = 1, #container.flowFrames do
        if container.flowFrameTypes[i] == "object" and not container.flowFrames[i]:CanChangeProtectedState() then return; end;
    end;

    local layout = flowLayout(container);
    if not layout then return; end;

    local maxRight, maxBottom = 0, 0;
    for _, info in ipairs(layout) do
        maxRight = max(maxRight, info.x + info.width);
        maxBottom = max(maxBottom, -info.y + info.height);
    end;

    flowBounds = #layout > 0 and { width = maxRight, height = maxBottom } or nil;
    if flowBounds then
        container:SetSize(maxRight, maxBottom);
        fixBorder(container);
    end;

    for _, info in ipairs(layout) do
        local newX = maxRight - info.x - info.width;
        local point, relativeTo, _, x, y = info.object:GetPoint(1);
        if point ~= "TOPLEFT" or relativeTo ~= container or differs(x, newX) or differs(y, info.y) then
            info.object:ClearAllPoints();
            info.object:SetPoint("TOPLEFT", container, "TOPLEFT", newX, info.y);
        end;
    end;
end;

local function captureAnchor()
    local container = CompactRaidFrameContainer;
    local right, top = container:GetRight(), container:GetTop();
    if not right or not top or issecretvalue(right) or issecretvalue(top) then return nil; end;

    local scale = container:GetScale();
    return {
        x = -((UIParent:GetWidth() - right * scale) / scale),
        y = -((UIParent:GetHeight() - top * scale) / scale),
    };
end;

local function getLayoutKey()
    local layout = EditModeManagerFrame:GetActiveLayoutInfo();
    local name = layout and layout.layoutName or "default";
    return core.getMainLayoutName(name) or name;
end;

-- edit mode saves a topleft anchor and we cant change that without tainting, so we re-anchor by the right edge
-- the right edge is remembered per layout on save
local function anchorToRight()
    local container = CompactRaidFrameContainer;
    if not container:CanChangeProtectedState() or container:GetPoint(1) ~= "TOPLEFT" then return; end;

    -- capturing an edge with nothing laid out would be bogus, a saved one is fine
    local hasLayout = flowBounds or FlowContainer_GetUsedBounds(container) > 0;

    local anchor;
    if EditModeManagerFrame:IsEditModeActive() then
        anchor = hasLayout and captureAnchor();
    else
        local anchors = GoobyFrameTweaksVariables.RaidFrameGrowthAnchors;
        local key = getLayoutKey();
        anchors[key] = anchors[key] or (hasLayout and captureAnchor()) or nil;
        anchor = anchors[key];
    end;
    if not anchor then return; end;

    container:ClearAllPoints();
    container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", anchor.x, anchor.y);
end;

function core:initializeRaidFrameGrowth()
    local container = CompactRaidFrameContainer;
    if not container then return false; end;

    GoobyFrameTweaksVariables.RaidFrameGrowthAnchors = GoobyFrameTweaksVariables.RaidFrameGrowthAnchors or {};

    hooksecurefunc("FlowContainer_DoLayout", mirrorLayout);
    hooksecurefunc(container, "Layout", anchorToRight);
    hooksecurefunc(container, "UpdateBorder", fixBorder);
    hooksecurefunc(container, "SetPoint", function()
        -- the timer covers when theres no saved right edge yet
        if not EditModeManagerFrame:IsEditModeActive() and GoobyFrameTweaksVariables.RaidFrameGrowthAnchors[getLayoutKey()] then
            anchorToRight();
        end;
        C_Timer.After(0, anchorToRight);
    end);
    hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
        GoobyFrameTweaksVariables.RaidFrameGrowthAnchors[getLayoutKey()] = captureAnchor();
    end);

    local events = CreateFrame("Frame");
    events:RegisterEvent("PLAYER_REGEN_ENABLED");
    events:SetScript("OnEvent", function()
        -- no TryUpdate here, calling blizzard's layout from our code would taint it
        mirrorLayout(container);
        anchorToRight();
    end);

    core:initializeRaidFrameLayouts();
end;
