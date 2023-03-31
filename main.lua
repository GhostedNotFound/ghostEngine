---@diagnostic disable: lowercase-global
--[[
    Copyright (C)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at our option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see https://www.gnu.org/licenses/agpl-3.0.en.html.
]] --

print("Hello, World!")

love.window.setTitle("Ghost Engine: Initalizing")

-- Define local variables & functions:

GhostEngine = {
    drawCustomTypes = function (k,v)
        
    end,
    frame = function ()
        
    end
}

local GameLoaded = false
local currentInternalError = nil
local validTypes = {"text", "image", "rect", "circle"}
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
local function _errorScreen(c)
    if currentInternalError then
        return;
    end
    love.window.setTitle("Ghost Engine: InternalEngineError" .. c)
    currentInternalError = c
    love.keyboard.setKeyRepeat(true)
    print("SoftHalt:",c)
    CreateUI("latestError", "text", { t = internalEngineErrors[c] .. "\n(Press ESC to quit, press CTRL+C to copy)" })
    love.graphics.setBackgroundColor(0.2, 0, 0, 1)
end

local function _checkCompatSystem()
    if love.system.getOS() == "OS X" or love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
        print("[!] Using an IncompatiableSystem.")
        _errorScreen("IncompatiableSystem")
        return false
    end
    if love.system.getOS() == "Windows" then
        print("[!] Running on Windows, may have problems!")
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
        print("Attempting to load Custom Icon...")
        love.window.setIcon(GameDat.icon)
        print("Loaded Custom Icon successfully!")
    end
end

local function _enforceHaltIf(condition, message)
    if not condition then love.window.setTitle("Ghost Engine: EnforcedHaltViaAssertion") print("Halt Enbound!") end
    assert(condition, message.."\n\nCheck your code, traceback is unhelpful here." or "Halt was enforced unexpectingly.\n\nCheck with the current maintainer of Ghost Engine.")
end

local function _layersExist()
    if not Layers.UILayer then
        print("Layers.UILayer was deleted. This would cause a halt, so it was regenerated as a blank table.")
        Layers.UILayer = {}
    end
    if not Layers.BackgroundLayer then
        print("Layers.BackgroundLayer was deleted. This would cause a halt, so it was regenerated as a blank table.")
        Layers.BackgroundLayer = {}
    end
    if not Layers.ForegroundLayer then
        print("Layers.ForegroundLayer was deleted. This would cause a halt, so it was regenerated as a blank table.")
        Layers.UILayer = {}
    end
end

local function _doPredeterminedTypes(k, v)
    love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
    if v.type == "text" then
        love.graphics.print(v.data.t, v.data.x or 0, v.data.y or 0)
    elseif v.type == "image" then
        _enforceHaltIf(file_exists(v.data.i),"Originated from CreateUI(" ..
        k .. ", " .. v.type .. ", {i=\""..v.data.i.."\"}): Image (" .. v.data.i .. ") is non-existant.\nCurrent version of Ghost Engine has flaws, so halt was enforced.")
        love.graphics.draw(love.graphics.newImage(v.data.i), v.data.x or 0, v.data.y or 0)
    elseif v.type == "rect" then
        love.graphics.rectangle(v.data.mode or "line", v.data.x or 0, v.data.y or 0, v.data.w,
            v.data.h)
    elseif v.type == "circle" then
        love.graphics.circle(v.data.mode or "line", v.data.x or 0, v.data.y or 0, v.data.rad,
            v.data.seg or 30)
    end
end

local function _drawBackgroundLayer()
    for key, value in pairs(Layers.BackgroundLayer) do
        _doPredeterminedTypes(key, value)
        GhostEngine.drawCustomTypes(key, value)
    end
end

local function _drawForegroundLayer()
    for key, value in pairs(Layers.ForegroundLayer) do
        _doPredeterminedTypes(key, value)
        GhostEngine.drawCustomTypes(key, value)
    end
end

local function _drawUiLayer()
    for key, value in pairs(Layers.UILayer) do
        _doPredeterminedTypes(key, value)
        GhostEngine.drawCustomTypes(key, value)
    end
end

local function _drawOtherLayers()
    for key, value in pairs(Layers) do
        if key == "BackgroundLayer" or key == "ForegroundLayer" or key == "UILayer" then
        else
            for key, value in pairs(Layers[key]) do
                _doPredeterminedTypes(key, value)
                GhostEngine.drawCustomTypes(key, value) 
            end
        end
    end
end

-- Define global variables & functions:

Layers = {BackgroundLayer = {},ForegroundLayer = {},UILayer = {}}
TICKS = 0
_SCREENWIDTH = love.graphics.getWidth()
_SCREENHEIGHT = love.graphics.getHeight()
_SEED = 0
FontSize = 20
CurrentFont = "default"

function RegenerateRandomness()
    _SEED = math.ceil(((os.time() * math.random(-5, 5)) * os.time() / 1000000) - os.clock())
    math.randomseed(_SEED)
    math.random()
    math.random()
    math.random()
    if not TICKS == 0 then
        print("Regenerated Randomness.")
    end
end

function CreateNewLayer(l, merge)
    if Layers[l] then
        print("Attempted to make a layer that already exists:", l)
        return;
    end
    local newLayer = {};
    print("Creating new layer:", l)
    if merge and Layers[l] then
        print("Merging layer with same name")
        for k, v in pairs(Layers[l]) do
            newLayer[k] = v;
        end
        Layers[l] = nil;
    end
    Layers[l] = newLayer;
end

function exp_CopyLayer(fromLayer, toLayer, deleteFromLayer)
    if Layers[fromLayer] and Layers[toLayer] then
        print("Copying items from layer",fromLayer,"to layer",toLayer)
        Layers[toLayer] = Layers[fromLayer]
        if deleteFromLayer then
            print("Deleted Layers."..fromLayer)
            Layers[fromLayer] = nil
        end
        return Layers[toLayer]
    else
        print("Attempted to copy from layer", fromLayer , "to layer", toLayer, "and failed.")
    end
end

function file_exists(name)
    if type(name) ~= "string" then return false end
    local f, err = io.open(name, "r")
    if err then return false end
---@diagnostic disable-next-line: need-check-nil
    f:close()
    return true
end

function exp_CreateObject(layer, id, typeOf, data)
    local validType = false
    for _, value in ipairs(validTypes) do
        if value == typeOf then
            validType = true
            break
        end
    end
    if type(id) == "string" and type(layer) == "string" and type(data) == "table" and validType and Layers[layer] and not Layers[layer][id] then
        data["id"] = id
        data["destroy"] = function (self)
            print("Destroyed ObjectId "..self.id)
            Layers[layer][self.id] = nil
        end
        Layers[layer][id] = { type = typeOf, data = data }
        print("Created new Object in layer",layer,"with id",id,"as type",typeOf)
        return Layers[layer][id].data
    elseif not validType then
        CreateUI("latestError", "text",
            {
                x = 0,
                y = 0,
                t = "CreateObject(...): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.",
                clr = { 1, 0, 0 }
            })
        print("CreateObject(...): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.")
        return Layers.UILayer.latestError.data
    elseif (not Layers[layer]) or (Layers[layer][id]) then
        CreateUI("latestError", "text",
        {
            x = 0,
            y = 0,
            t = "CreateObject(...): Layer \"" .. layer .. "\" has conflict. Error is not fatal, so halt wasn't enforced.",
            clr = { 1, 0, 0 }
        })
        print("CreateObject(...): Layer \"" .. layer .. "\" has conflict. Error is not fatal, so halt wasn't enforced.")
        return Layers.UILayer.latestError.data
    else
        CreateUI("latestError", "text",
            { x = 0, y = 0, t = "CreateObject(...): An error occurred. Probably missing params.", clr = { 1, 0, 0 } })
        print("CreateObject(...): An error occurred. Probably missing params.")
        return Layers.UILayer.latestError.data
    end
end

function CreateUI(id, typeOf, data)
    local validType = false
    for _, value in ipairs(validTypes) do
        if value == typeOf then
            validType = true
            break
        end
    end
    if type(id) == "string" and validType and type(data) == "table" then
        print("Created UI object with id", id)
        data["id"] = id
        data["destroy"] = function (self)
            print("Destroyed ObjectId "..self.id)
            Layers.UILayer[self.id] = nil
        end
        Layers.UILayer[id] = { type = typeOf, data = data }
        return Layers.UILayer[id].data
    elseif not validType then
        CreateUI("latestError", "text",
            {
                x = 0,
                y = 0,
                t = "CreateUI(" .. id .. ", " .. typeOf .. "): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.",
                clr = { 1, 0, 0 }
            })
        print("CreateUI(" .. id .. ", " .. typeOf .. "): \"" .. typeOf .. "\" is not a valid type. Error is not fatal, so halt wasn't enforced.")
        return Layers.UILayer.latestError.data
    else
        CreateUI("latestError", "text",
            { x = 0, y = 0, t = "CreateUI(...): An error occurred. Probably missing params.", clr = { 1, 0, 0 } })
        print("CreateUI(...): An error occurred. Probably missing params.")
        return Layers.UILayer.latestError.data
    end
end

function DestroyUI(id)
    print("Destroyed UI object with id", id)
    if id and Layers.UILayer[id] then
        Layers.UILayer[id] = nil
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
    love.graphics.setNewFont(FontSize)
    _SCREENWIDTH = love.graphics.getWidth()
    _SCREENHEIGHT = love.graphics.getHeight()
    _layersExist()
    _drawBackgroundLayer()
    _drawOtherLayers()
    _drawForegroundLayer()
    _drawUiLayer()
end

function love.update()
    GhostEngine.frame()
    TICKS = TICKS + 1
end

function love.keypressed(key)
    if key == "escape" and not GameLoaded then
        print("Emergency Quit.")
        love.event.quit()
    end
    if key == "c" and love.keyboard.isDown("lctrl") and not GameLoaded then
        print("Copied!")
        love.system.setClipboardText("currentInternalError is " ..
            currentInternalError .. ".\nError is listed as follows:\n" .. internalEngineErrors[currentInternalError])
    end
end

-- Load "books":

for key, value in pairs(love.filesystem.getDirectoryItems("_books")) do
    print("Detected book (" .. value .. "), adding to library.")
    require("_books." .. value:sub(1, value:len() - 4))
end

-- Begin with loading game.

RegenerateRandomness()

_checkCompatSystem()

if love.system.getOS() == "Windows" then
    if not currentInternalError then
        FontSize = 15
        require("game")
        _getGameDat()
    end
else
    if file_exists("game.lua") and not currentInternalError then
        FontSize = 15
        require("game")
        _getGameDat()
    elseif not currentInternalError then
        _errorScreen("NoGameDetected")
    end
end