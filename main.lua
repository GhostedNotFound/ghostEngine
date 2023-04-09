--[[
    Copyright (C)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the MIT license as published by the 
    Open Source Initiative.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    MIT license for more details.

    You should have received a copy of the MIT license along with this program. 
    If not, see https://opensource.org/license/mit/.
]]--

local lume = require "lume"

love.filesystem.setIdentity("Ghost Engine")

love.filesystem.write("test.txt", "Hi")

ghostengine = {}
ghostengine.log = function (text) print(text) io.write("\n\n\n"..text) end

local currentDate = os.date("*t")

local logFile = io.open("log", "a")

---@diagnostic disable-next-line: param-type-mismatch
io.output(logFile)

ghostengine.log("Hello, World! - "..currentDate.month.."/"..currentDate.day.."/"..currentDate.year.." at "..currentDate.hour..":"..currentDate.min..":"..currentDate.sec.. "\n    (Using user's local os time)")

love.window.setTitle("Ghost Engine: Initalizing")

-- Define local variables & functions:

local utf8 = require("utf8")
local gameLoaded = false
local currentInternalError = nil
local validTypes = { "text", "image", "rect", "circle", "3D-Cube", "textbox" }
local internalEngineErrors = {
    NoGameDetected =
    "Welcome to Ghost Engine!\nNo game.lua file detected.\nIs it in the right folder?\nRead the DOCUMENTATION file for help.\n\n[ [-- (E404) --] ]",
    GameUnloadable =
    "game.lua file detected, but couldn't be assessed.\nRead the DOCUMENTATION file for help.\n\n[ [-- (E403) --] ]",
    Test = "Success.\n\n[ [-- (E000) --] ]",
    IncompatiableSystem = "Your system (" ..
        love.system.getOS() ..
        ") is incompatible with Ghost Engine.\nWe apologize for the inconvenience.\n\n[ [-- (E100) --] ]"
}
local textboxThatIsFocused = ""
local focusedOnTextbox = false

local function file_exists(name)
    if type(name) ~= "string" then return false end
    local f, err = io.open(name, "r")
    if err then return false end
    ---@diagnostic disable-next-line: need-check-nil
    f:close()
    return true
end

local function _errorScreen(c)
    if currentInternalError then
        return;
    end
    love.window.setTitle("Ghost Engine: InternalEngineError" .. c)
    currentInternalError = c
    love.keyboard.setKeyRepeat(true)
    ghostengine.log("SoftHalt: ".. c)
    CreateUI("latestError", "text", { t = internalEngineErrors[c] .. "\n(Press ESC to quit, press CTRL+C to copy)" })
    love.graphics.setBackgroundColor(0.2, 0, 0, 1)
end

local function _checkCompatSystem()
    if love.system.getOS() == "OS X" or love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
        ghostengine.log("[!] Using an IncompatiableSystem.")
        _errorScreen("IncompatiableSystem")
        return false
    end
    if love.system.getOS() == "Windows" then
        ghostengine.log("[!] Running on Windows, may have problems!")
        love.window.showMessageBox("Incompatiable System Warning",
            "You are currently running the open-source version of Ghost Engine on a Windows system.\nThe engine cannot check for a valid game.lua file.\nYou have been warned.",
            "warning", false)
        return true
    end
    return true
end

local function _getGameDat()
    if GameDat.title then
        love.window.setTitle("Ghost Engine: " .. GameDat.title)
    else
        love.window.setTitle("Ghost Engine: Untitled Game")
        if math.random() >= 0.75 then
            love.window.setTitle("Ghost Engine: The Newest Best Game?")
        end
    end

    if GameDat.removeWatermark and GameDat.title then
        love.window.setTitle(GameDat.title)
    end

    if GameDat.icon then
        ghostengine.log("Attempting to load Custom Icon...")
        love.window.setIcon(GameDat.icon)
        ghostengine.log("Loaded Custom Icon successfully!")
    end
end

local function _enforceHaltIf(condition, message)
    if not condition then
        love.window.setTitle("Ghost Engine: EnforcedHaltViaAssertion")
        io.write(("\n[!!!] EnforcedHaltViaAssertion: Halt\n".. message .. "\n\nCheck your code and/or the logs for details.") or ("Halt was enforced unexpectingly.\n\nCheck your code and/or the logs for details."))
        io.close(logFile)
    end
    assert(condition,
    message .. "\n\nCheck your code and/or the logs for details." or
    "Halt was enforced unexpectingly.\n\nCheck your code and/or the logs for details.")
end

local function _layersExist()
    if not ghostengine.layers.UILayer then
        ghostengine.log("Layers.UILayer was deleted. This would cause a halt, so it was regenerated as a blank table.")
        ghostengine.layers.UILayer = {}
    end
    if not ghostengine.layers.BackgroundLayer then
        ghostengine.log("Layers.BackgroundLayer was deleted. This would cause a halt, so it was regenerated as a blank table.")
        ghostengine.layers.BackgroundLayer = {}
    end
    if not ghostengine.layers.ForegroundLayer then
        ghostengine.log("Layers.ForegroundLayer was deleted. This would cause a halt, so it was regenerated as a blank table.")
        ghostengine.layers.UILayer = {}
    end
end

local function _doPredeterminedTypes(k, v)
    love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
    if v.type == "text" then
        love.graphics.print(v.data.t, v.data.x or 0, v.data.y or 0)
    elseif v.type == "textbox" then
        love.graphics.setColor({ 0, 0, 0, 1 })
        love.graphics.rectangle("fill", (v.data.x-(ghostengine.fontSize*0.5)) or 0, (v.data.y-(ghostengine.fontSize*0.5)) or 0, v.data.w or #v.data.t * 1.25, v.data.h or ghostengine.fontSize)
        love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
        love.graphics.print(v.data.t, v.data.x, v.data.y)
        love.graphics.rectangle("line", (v.data.x-(ghostengine.fontSize*0.5)) or 0, (v.data.y-(ghostengine.fontSize*0.5)) or 0, v.data.w or #v.data.t * 1.25, v.data.h or ghostengine.fontSize)
    elseif v.type == "image" then
        _enforceHaltIf(file_exists(v.data.i), "Originated from CreateUI(" ..
            k ..
            ", " ..
            v.type ..
            ", {i=\"" ..
            v.data.i ..
            "\"}): Image (" ..
            v.data.i .. ") is non-existant.\nCurrent version of Ghost Engine has flaws, so halt was enforced.")
        love.graphics.draw(love.graphics.newImage(v.data.i), v.data.x or 0, v.data.y or 0)
    elseif v.type == "rect" then
        love.graphics.rectangle(v.data.mode or "line", v.data.x or 0, v.data.y or 0, v.data.w,
            v.data.h)
    elseif v.type == "circle" then
        love.graphics.circle(v.data.mode or "line", v.data.x or 0, v.data.y or 0, v.data.rad,
            v.data.seg or 30)
    elseif v.type == "3D-Cube" then
        love.graphics.line((v.data.x or 0 ) * v.data.size, (v.data.y or 0 ) * v.data.size, (v.data.x or 0 ) * v.data.size, ((v.data.y or 0 ) + 50) * v.data.size)
        love.graphics.line(((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) + 75) * v.data.size, ((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) + 25) * v.data.size)
        love.graphics.line(((v.data.x or 0 ) + 100) * v.data.size, ((v.data.y or 0 ) + 50) * v.data.size, ((v.data.x or 0 ) + 100) * v.data.size, (v.data.y or 0 ) * v.data.size)
        love.graphics.line((v.data.x or 0 ) * v.data.size, (v.data.y or 0 ) * v.data.size, ((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) + 25) * v.data.size)
        love.graphics.line((v.data.x or 0 ) * v.data.size, ((v.data.y or 0 ) + 50) * v.data.size, ((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) + 75) * v.data.size)
        love.graphics.line(((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) + 75) * v.data.size, ((v.data.x or 0 ) + 100) * v.data.size, ((v.data.y or 0 ) + 50) * v.data.size)
        love.graphics.line(((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) + 25) * v.data.size, ((v.data.x or 0 ) + 100) * v.data.size, (v.data.y or 0 ) * v.data.size)
        love.graphics.line((v.data.x or 0 ) * v.data.size, (v.data.y or 0 ) * v.data.size, ((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) - 25) * v.data.size)
        love.graphics.line(((v.data.x or 0 ) + 100) * v.data.size, (v.data.y or 0 ) * v.data.size, ((v.data.x or 0 ) + 50) * v.data.size, ((v.data.y or 0 ) - 25) * v.data.size)
    end
end

local function _drawBackgroundLayer()
    for key, value in pairs(ghostengine.layers.BackgroundLayer) do
        _doPredeterminedTypes(key, value)
        ghostengine.drawCustomTypes(key, value)
    end
end

local function _drawForegroundLayer()
    for key, value in pairs(ghostengine.layers.ForegroundLayer) do
        _doPredeterminedTypes(key, value)
        ghostengine.drawCustomTypes(key, value)
    end
end

local function _isInsideBox(x1, y1, x2, y2, x, y)
    if x >= x1 and y >= y1 and x <= x2 and y <= y2 then
        return true
    else
        return false
    end
end

local function _drawUiLayer()
    for key, value in pairs(ghostengine.layers.UILayer) do
        _doPredeterminedTypes(key, value)
        ghostengine.drawCustomTypes(key, value)
    end
end

local function _drawOtherLayers()
    for key, value in pairs(ghostengine.layers) do
        if key == "BackgroundLayer" or key == "ForegroundLayer" or key == "UILayer" then
        else
            for key, value in pairs(ghostengine.layers[key]) do
                _doPredeterminedTypes(key, value)
                ghostengine.drawCustomTypes(key, value)
            end
        end
    end
end

-- Define global ghostengine:

ghostengine = { 
    seed = 0,
    ticks = 0,
    fontSize = 20,
    lastKeyPressed = nil,
    layers = { BackgroundLayer = {}, ForegroundLayer = {}, UILayer = {} },
    textboxes = {},
    regenerateRandomness = function ()
        ghostengine.seed = os.time() + math.random(-5, 5)
        math.randomseed(ghostengine.seed)
        if ghostengine.ticks == 0 then
            ghostengine.log("Regenerated randomness.")
        end
    end,
    createLayer = function (l, merge)
        if ghostengine.layers[l] then
            ghostengine.log("Attempted to make a layer that already exists: ".. l)
            return;
        end
        local newLayer = {};
        ghostengine.log("Creating new layer: ".. l)
        if merge and ghostengine.layers[l] then
            ghostengine.log("Merging layer with same name")
            for k, v in pairs(ghostengine.layers[l]) do
                newLayer[k] = v;
            end
            ghostengine.layers[l] = nil;
        end
        ghostengine.layers[l] = newLayer;
    end,
    createObject = function (layer, id, typeOf, data)
        local validType = false
        for _, value in ipairs(validTypes) do
            if value == typeOf then
                validType = true
                break
            end
        end
        if type(id) == "string" and type(layer) == "string" and type(data) == "table" and validType and ghostengine.layers[layer] and not ghostengine.layers[layer][id] then
            if layer == "BackgroundLayer" and typeOf == "textbox" then
                ghostengine.log("[?] Textboxes (a major UI object) cannot be in the BackgroundLayer, moving to ForegroundLayer.")
                layer = "ForegroundLayer"
            end
            if typeOf == "textbox" then
                ghostengine.textboxes[id] = data
            end
            data["id"] = id
            data["destroy"] = function(self)
                ghostengine.log("Destroyed ObjectId " .. self.id)
                ghostengine.layers[layer][self.id] = nil
            end
            ghostengine.layers[layer][id] = { type = typeOf, data = data }
            ghostengine.log("Created new Object in layer ".. layer.. " with id ".. id .. " as type ".. typeOf)
            return ghostengine.layers[layer][id].data
        elseif not validType then
            CreateUI("latestError", "text",
                {
                    x = 0,
                    y = 0,
                    t = "CreateObject(...): \"" ..
                    typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.",
                    clr = { 1, 0, 0 }
                })
            ghostengine.log("CreateObject(...): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.")
            return ghostengine.layers.UILayer.latestError.data
        elseif (not ghostengine.layers[layer]) or (ghostengine.layers[layer][id]) then
            CreateUI("latestError", "text",
                {
                    x = 0,
                    y = 0,
                    t = "CreateObject(...): Layer \"" ..
                    layer .. "\" has conflict. Error is not fatal, so halt wasn't enforced.",
                    clr = { 1, 0, 0 }
                })
            ghostengine.log("CreateObject(...): Layer \"" .. layer .. "\" has conflict. Error is not fatal, so halt wasn't enforced.")
            return ghostengine.layers.UILayer.latestError.data
        else
            CreateUI("latestError", "text",
                { x = 0, y = 0, t = "CreateObject(...): An error occurred. Probably missing params.", clr = { 1, 0, 0 } })
            ghostengine.log("CreateObject(...): An error occurred. Probably missing params.")
            return ghostengine.layers.UILayer.latestError.data
        end
    end,
    exp_create3DCube = function (x, y, size)
        ghostengine.createObject("UILayer", "3DObject", "3D-Cube", {x=x,y=y,size=size})
    end,
    log = function (text) print(text) io.write("\n"..text) end,
    drawCustomTypes = function(k, v) end,
    frame = function() end,
    keyDown = function (key, scancode, rep) end,
}

function CreateUI(id, typeOf, data)
    local validType = false
    for _, value in ipairs(validTypes) do
        if value == typeOf then
            validType = true
            break
        end
    end
    if type(id) == "string" and validType and type(data) == "table" then
        ghostengine.log("Created UI object with id ".. id)
        data["id"] = id
        data["destroy"] = function(self)
            ghostengine.log("Destroyed ObjectId " .. self.id)
            ghostengine.layers.UILayer[self.id] = nil
        end
        ghostengine.layers.UILayer[id] = { type = typeOf, data = data }
        return ghostengine.layers.UILayer[id].data
    elseif not validType then
        CreateUI("latestError", "text",
            {
                x = 0,
                y = 0,
                t = "CreateUI(" ..
                id ..
                ", " ..
                typeOf .. "): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.",
                clr = { 1, 0, 0 }
            })
        ghostengine.log("CreateUI(" ..
        id ..
        ", " .. typeOf .. "): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.")
        return ghostengine.layers.UILayer.latestError.data
    else
        CreateUI("latestError", "text",
            { x = 0, y = 0, t = "CreateUI(...): An error occurred. Probably missing params.", clr = { 1, 0, 0 } })
        ghostengine.log("CreateUI(...): An error occurred. Probably missing params.")
        return ghostengine.layers.UILayer.latestError.data
    end
end

function DestroyUI(id)
    if type(id) == "string" and ghostengine.layers.UILayer[id] then
        ghostengine.log("Destroyed UI object with id ".. id)
        ghostengine.layers.UILayer[id] = nil
    else
        CreateUI("latestError", "text", {
            x = 0,
            y = 0,
            t = "DestroyUI(...): UI doesn't exist or no ID given.",
            c = { 1, 0, 0 }
        })
    end
end

-- Load Love functions:

function love.draw()
    love.graphics.setNewFont(ghostengine.fontSize)
    _layersExist()
    _drawBackgroundLayer()
    _drawOtherLayers()
    _drawForegroundLayer()
    _drawUiLayer()
end

function love.update()
    ghostengine.frame()
    ghostengine.ticks = ghostengine.ticks + 1
end

function love.mousepressed(mx, my, button, istouch, presses)
    local clickontxtbox
    for key, value in pairs(ghostengine.textboxes) do
        if _isInsideBox(value.x-(ghostengine.fontSize*0.5), value.y-(ghostengine.fontSize*0.5), (value.x-(ghostengine.fontSize*0.5)) + value.w, (value.y-(ghostengine.fontSize*0.5)) + value.h, mx, my) then
            clickontxtbox = value.id
            ghostengine.log("Focused on textbox named \""..value.id.."\".")
        end
    end
    if clickontxtbox then
        focusedOnTextbox = true
        textboxThatIsFocused = clickontxtbox
    elseif focusedOnTextbox then
        focusedOnTextbox = false
        ghostengine.log("Unfocused textbox.")
    end

end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" and not gameLoaded then
        ghostengine.log("Emergency Quit.")
        love.event.quit()
    end
    if key == "c" and love.keyboard.isDown("lctrl") and not gameLoaded then
        ghostengine.log("Copied!")
        love.system.setClipboardText("currentInternalError is " ..
            currentInternalError .. ".\nError is listed as follows:\n" .. internalEngineErrors[currentInternalError])
    end
    if not focusedOnTextbox then
        ghostengine.keyDown(key, scancode, isrepeat)
    elseif key == "backspace" then
        local byteoffset = utf8.offset(ghostengine.textboxes[textboxThatIsFocused].t, -1)
        if byteoffset then
            ghostengine.textboxes[textboxThatIsFocused].t = string.sub(ghostengine.textboxes[textboxThatIsFocused].t, 1, byteoffset - 1)
        end
    end
    ghostengine.lastKeyPressed = key
end

function love.textinput(t)
    if focusedOnTextbox and (ghostengine.textboxes[textboxThatIsFocused].maxCharLimit or math.ceil(ghostengine.textboxes[textboxThatIsFocused].w/8.2)) >= #ghostengine.textboxes[textboxThatIsFocused].t then
        ghostengine.textboxes[textboxThatIsFocused].t = ghostengine.textboxes[textboxThatIsFocused].t .. t
    end
end

-- Load "books":

for key, value in pairs(love.filesystem.getDirectoryItems("_books")) do
    ghostengine.log("Detected book (" .. value .. "), adding to library.")
    require("_books." .. value:sub(1, value:len() - 4))
end

-- Begin with loading game.

ghostengine.regenerateRandomness()

_checkCompatSystem()

if love.system.getOS() == "Windows" then
    if not currentInternalError then
        ghostengine.fontSize = 15
        require("game")
        _getGameDat()
    end
else
    if file_exists("game.lua") and not currentInternalError then
        ghostengine.fontSize = 15
        require("game")
        _getGameDat()
    elseif not currentInternalError then
        _errorScreen("NoGameDetected")
    end
end

function love.quit()
    ghostengine.log("[✓] PRESS \n    (Program Ran and Exited System Successfully)")
    io.close(logFile)
end