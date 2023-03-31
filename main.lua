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
]]
   --

love.window.setTitle("Ghost Engine: Initalizing")

-- Define local variables & functions:

local GameLoaded = false
local currentInternalError = nil
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
local testingError = false
local function _errorScreen(c)
    if currentInternalError then
        return;
    end
    love.window.setTitle("Ghost Engine: InternalEngineError" .. c)
    currentInternalError = c
    love.keyboard.setKeyRepeat(true)
    print(internalEngineErrors[c])
    CreateUI("latestError", "text", { t = internalEngineErrors[c] .. "\n(Press ESC to quit, press CTRL+C to copy)" })
    love.graphics.setBackgroundColor(0.2, 0, 0, 1)
end

local function _read_file(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a"   -- *a or *all reads the whole file
    file:close()
    return content
end

local function _checkCompatSystem()
    if love.system.getOS() == "OS X" or love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
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
        love.window.setIcon(GameDat.icon)
    end
end

local function _enforceHaltIf(condition, message)
    if not condition then love.window.setTitle("Ghost Engine: EnforcedHaltViaAssertion") end
    assert(condition, message.."\n\nCheck your code, traceback is unhelpful here." or "Halt was enforced unexpectingly.\n\nCheck with the current maintainer of Ghost Engine.")
end

local function _drawUiLayer()
    for key, value in pairs(Layers.UILayer) do
        love.graphics.setColor(value.data.clr or { 1, 1, 1, 1 })
        if value.type == "text" then
            love.graphics.print(value.data.t, value.data.x or 0, value.data.y or 0)
        elseif value.type == "image" then
            _enforceHaltIf(file_exists(value.data.i),"Originated from CreateUI(" ..
            key .. ", " .. value.type .. ", {i=\""..value.data.i.."\"}): Image (" .. value.data.i .. ") is non-existant.\nCurrent version of Ghost Engine has flaws, so halt was enforced.")
            love.graphics.draw(love.graphics.newImage(value.data.i), value.data.x or 0, value.data.y or 0)
        elseif value.type == "rect" then
            love.graphics.rectangle(value.data.mode or "line", value.data.x or 0, value.data.y or 0, value.data.w,
                value.data.h)
        elseif value.type == "circle" then
            love.graphics.circle(value.data.mode or "line", value.data.x or 0, value.data.y or 0, value.data.rad,
                value.data.seg or 30)
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
end

function CreateNewLayer(l, merge)
    local newLayer = {};
    if merge then
        for k, v in pairs(Layers[l]) do
            newLayer[k] = v;
        end
        Layers[l] = nil;
    end
    Layers[l] = newLayer;
end

function file_exists(name)
    if type(name) ~= "string" then return false end
    local f, err = io.open(name, "r")
    if err then return false end
---@diagnostic disable-next-line: need-check-nil
    f:close()
    return true
end

function CreateUI(id, typeOf, data)
    local validType = false
    for _, value in ipairs({ "text", "image", "rect", "circle" }) do
        if value == typeOf then
            validType = true
            break
        end
    end
    if type(id) == "string" and validType and type(data) == "table" then
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
    _drawUiLayer()
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
        pcall(require("game"))
        _getGameDat()
        print("Loaded game.lua file successfully.")
    end
else
    if file_exists("game.lua") and not currentInternalError then
        FontSize = 15
        require("game")
        _getGameDat()
        print("Loaded game.lua file successfully.")
    elseif not currentInternalError then
        _errorScreen("NoGameDetected")
    end
end