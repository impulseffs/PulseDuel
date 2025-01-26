-- Create main addon frame and namespace
PulseDuel = CreateFrame("Frame", "PulseDuelFrame", UIParent)
local addonName, addon = ...

-- Initialize variables
local frame = nil
local isAutoDuelEnabled = false
local autoDuelTimer = nil
local DUEL_RETRY_DELAY = 1.0  -- Delay in seconds between duel attempts
local timeSinceLastAttempt = 0

-- Initialize saved variables structure
local defaults = {
    lastOpponent = "",
    autoDuelEnabled = false
}

-- Register Events
PulseDuel:RegisterEvent("ADDON_LOADED")
PulseDuel:RegisterEvent("DUEL_REQUESTED")
PulseDuel:RegisterEvent("PLAYER_LOGIN")
PulseDuel:RegisterEvent("DUEL_FINISHED")
PulseDuel:RegisterEvent("DUEL_WINNER_UPDATE")
PulseDuel:RegisterEvent("DUEL_CANCELLED")
PulseDuel:RegisterEvent("PLAYER_TARGET_CHANGED")

-- Create slash commands
SLASH_PULSEDUEL1 = "/pd"
SLASH_PULSEDUEL2 = "/pulseduel"

-- Function to start auto-duel timer
local function StartAutoDuelTimer()
    if not isAutoDuelEnabled or PulseDuelDB.lastOpponent == "" then
        if autoDuelTimer then
            autoDuelTimer:SetScript("OnUpdate", nil)
            autoDuelTimer = nil
        end
        return
    end
    
    if not autoDuelTimer then
        autoDuelTimer = CreateFrame("Frame")
        timeSinceLastAttempt = 0
        
        autoDuelTimer:SetScript("OnUpdate", function(self, elapsed)
            timeSinceLastAttempt = timeSinceLastAttempt + elapsed
            if timeSinceLastAttempt >= DUEL_RETRY_DELAY then
                timeSinceLastAttempt = 0
                if isAutoDuelEnabled and PulseDuelDB.lastOpponent ~= "" then
                    StartDuel(PulseDuelDB.lastOpponent)
                end
            end
        end)
    end
end

-- Main frame setup
local function CreateMainFrame()
    if frame then return frame end
    
    frame = CreateFrame("Frame", "PulseDuelMainFrame", UIParent)
    frame:SetSize(300, 150)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Create backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    
    -- Create close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    
    frame:Hide()

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cFF00FF00PulseDuel|r")  -- Green color

    -- Create editbox
    local editBox = CreateFrame("EditBox", nil, frame)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetSize(180, 20)
    editBox:SetPoint("TOP", title, "BOTTOM", 0, -20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(12)
    editBox:SetTextInsets(8, 8, 0, 0)
    editBox:SetTextColor(1, 1, 1, 1)  -- White text
    
    -- Set the last opponent name in editbox if it exists
    if PulseDuelDB and PulseDuelDB.lastOpponent then
        editBox:SetText(PulseDuelDB.lastOpponent)
    end
    
    -- EditBox backdrop
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    editBox:SetBackdropColor(0, 0, 0, 0.9)
    editBox:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    editBox:SetScript("OnEnterPressed", function(self)
        local name = self:GetText()
        if name and name ~= "" then
            StartDuel(name)
            frame:Hide()
        end
    end)

    -- Create button
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(100, 25)
    button:SetPoint("TOP", editBox, "BOTTOM", 0, -10)
    button:SetText("Duel")
    button:SetScript("OnClick", function()
        local name = editBox:GetText()
        if name and name ~= "" then
            StartDuel(name)
            frame:Hide()
        end
    end)

    -- Create auto-reduel checkbox
    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", button, "BOTTOMLEFT", -5, -10)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(PulseDuelDB.autoDuelEnabled)
    
    local checkboxLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkboxLabel:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkboxLabel:SetText("Auto Re-duel")
    
    -- Store the checkbox reference globally
    frame.autoReduelCheckbox = checkbox
    
    -- Add checkbox click handler
    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        isAutoDuelEnabled = checked
        PulseDuelDB.autoDuelEnabled = checked
        if checked and PulseDuelDB.lastOpponent ~= "" then
            StartDuel(PulseDuelDB.lastOpponent)
        end
    end)

    return frame
end

-- Function to start duel
local function StartDuel(targetName)
    if not targetName or targetName == "" then return end
    
    -- Convert target name to proper format (first letter uppercase, rest lowercase)
    targetName = targetName:gsub("^%l", string.upper)
    
    -- Store the last opponent name
    PulseDuelDB.lastOpponent = targetName
    
    -- Try to target the player
    TargetByName(targetName, true)
    
    -- Check if we have a valid target
    if UnitExists("target") then
        -- Start the duel
        StartDuel("target")
        
        -- Accept the duel immediately
        AcceptDuel()
        
        -- Start the auto-duel timer if enabled
        if isAutoDuelEnabled then
            StartAutoDuelTimer()
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000PulseDuel:|r Player " .. targetName .. " not found!")
        -- Retry after delay if auto-duel is enabled
        if isAutoDuelEnabled then
            StartAutoDuelTimer()
        end
    end
end

-- Slash command handler
local function SlashCommandHandler(msg)
    msg = msg and msg:trim() or ""
    if msg ~= "" then
        StartDuel(msg)
    else
        -- Toggle main frame
        if not frame then
            frame = CreateMainFrame()
        end
        
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

-- Register slash commands
SlashCmdList["PULSEDUEL"] = SlashCommandHandler

-- Main event handler
PulseDuel:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == "PulseDuel" then
        -- Initialize saved variables
        PulseDuelDB = PulseDuelDB or defaults
        isAutoDuelEnabled = PulseDuelDB.autoDuelEnabled
        
        -- Display welcome message with creator info and GitHub link
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00PulseDuel|r loaded! Use |cFF00FF00/pd|r or |cFF00FF00/pulseduel|r to open the interface.")
        DEFAULT_CHAT_FRAME:AddMessage("Created by: |cFF00FF00impulseffs|r")
        DEFAULT_CHAT_FRAME:AddMessage("Download at: |cFF00FFFF" .. "https://github.com/impulseffs/PulseDuel" .. "|r")
    elseif event == "DUEL_REQUESTED" then
        AcceptDuel()
    elseif event == "PLAYER_LOGIN" then
        -- Create frame on login
        frame = CreateMainFrame()
    elseif event == "DUEL_FINISHED" or event == "DUEL_WINNER_UPDATE" or event == "DUEL_CANCELLED" then
        -- Start auto-duel timer if enabled
        if isAutoDuelEnabled then
            StartAutoDuelTimer()
        end
    end
end)
