local _, core = ...
core.Utils = {}

function core.Utils:FilterToNewArray(arr, func)
    local newArray = {}
    local newIndex = 1
    for oldIndex, v in ipairs(arr) do
        if func(v, oldIndex) then
            newArray[newIndex] = v
            newIndex = newIndex + 1
        end
    end
    return newArray
end

function core.Utils:MapUnique(arr, func)
    local newArray = {}
    local newIndex = 1
    for oldIndex, v in ipairs(arr) do
        local newValue = func(v, oldIndex)
        local newValueFound = false;
        for i = 0, # newArray do
            if newArray[i] == newValue then
                newValueFound = true
            end
        end
        if not newValueFound then
            newArray[newIndex] = newValue
            newIndex = newIndex + 1
        end
    end
    return newArray
end

function core.Utils:FormatTime(seconds)
    local minutes = floor(seconds / 60)
    local secondsLeft = seconds % 60
    if secondsLeft < 10 and minutes > 0 then
        secondsLeft = "0" .. secondsLeft
    end
    if minutes > 0 then
        return minutes .. ":" .. secondsLeft
    else
        return secondsLeft
    end
end

-- forDisplay should stay false until trp's WORKFLOW_ON_FINISH, the contrast config isn't registered before that
function core.Utils:GetTRPColor(characterID, forDisplay)
    if not TRP3_API or not TRP3_API.profile or not TRP3_API.profile.getPlayerCurrentProfile
        or not AddOn_TotalRP3 or not AddOn_TotalRP3.Player
        or not AddOn_TotalRP3.Player.CreateFromCharacterID
        or not TRP3_Register or type(TRP3_Register.character) ~= "table"
        or type(TRP3_Register.profiles) ~= "table"
        or not TRP3_API.profile.getPlayerCurrentProfile() then
        return
    end

    local player = AddOn_TotalRP3.Player.CreateFromCharacterID(characterID)
    if not player or type(player.GetCustomColor) ~= "function" then
        return
    end

    local color
    if forDisplay then
        color = player:GetCustomColorForDisplay()
    else
        color = player:GetCustomColor()
    end
    if not color then return end
    if issecretvalue(color) or type(color.GetRGB) ~= "function" then
        return
    end

    local r, g, b = color:GetRGB()
    if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then
        return
    end

    return r, g, b
end

function core.Utils:DefaultsTableChecker(current, defaults)
    for key, value in pairs(defaults) do
        if current[key] == nil then
            current[key] = value;
        end
    end
end
