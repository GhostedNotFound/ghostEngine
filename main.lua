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
]]--

love.window.setTitle("Ghost Engine: Initalizing")

-- Define local variables & functions:

local currentInternalError = nil
local internalEngineErrors = {
    NoGameDetected = "Welcome to Ghost Engine!\nNo game.lua file detected.\nIs it in the right folder?\nRead the DOCUMENTATION file for help.\n\n[ [-- (E404) --] ]",
    GameUnloadable = "game.lua file detected, but couldn't be assessed.\nRead the DOCUMENTATION file for help.\n\n[ [-- (E403) --] ]",
    Test = "Success.\n\n[ [-- (E000) --] ]"
}
local testingError = false
local function _errorScreen(c)
    if currentInternalError then
        return;
    end
    love.window.setTitle("Ghost Engine: InternalEngineError"..c)
    currentInternalError = c
    love.keyboard.setKeyRepeat(true)
    print(internalEngineErrors[c])
    CreateUI("latestError", "text", {t=internalEngineErrors[c].."\n(Press ESC to quit, press CTRL+C to copy)"})
    love.graphics.setBackgroundColor(0.2, 0, 0, 1)
end
local function _read_file(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end
local function _drawUiLayer()
    for key, value in pairs(UILayer) do
        love.graphics.setColor(value.data.clr or {1,1,1,1})
        if value.type == "text" then
            love.graphics.print(value.data.t ,value.data.x or 0, value.data.y or 0)
        elseif value.type == "image" then
            if file_exists(value.data.i) then
                love.graphics.draw(love.graphics.newImage(value.data.i), value.data.x or 0, value.data.y or 0)
            else
                CreateUI("latestError", "text", {x=0,y=0,t="Originated from CreateUI("..key..", "..value.type.."): Image ("..value.data.i..") is non-existant.",c={1,0,0}})
                print("Originated from CreateUI("..key..", "..value.type.."): Image ("..value.data.i..") is non-existant.")
                value.data.i = "engineAssets/noImage.png"
            end
        elseif value.type == "rect" then
            love.graphics.rectangle(value.data.mode or "line", value.data.x or 0, value.data.y or 0, value.data.w, value.data.h)
        elseif value.type == "circle" then
            love.graphics.circle(value.data.mode or "line", value.data.x or 0, value.data.y or 0, value.data.rad, value.data.seg or 50)
        end
    end
end

-- Define global variables & functions:

BackgroundLayer = {}
ForegroundLayer = {}
UILayer = {}
TICKS = 0
_SCREENWIDTH = love.graphics.getWidth()
_SCREENHEIGHT = love.graphics.getHeight()
_SEED = 0
GameLoaded = false
FontSize = 20
CurrentFont = "default"

function RegenerateRandomness()
    _SEED = math.ceil(((os.time() * math.random(-5, 5)) * os.time() / 1000000) - os.clock())
    math.randomseed(_SEED)
    math.random()
    math.random()
    math.random()
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function CreateUI(id, typeOf, data)
    local validType = false
    for key, value in pairs({"text", "image", "rect", "circle"}) do
        if value == typeOf then
            validType = true
        end
    end
    if type(id) == "string" and validType and type(data) == "table" then
        UILayer[id] = {type = typeOf, data = data}
        return UILayer[id].data
    elseif not validType then
        CreateUI("latestError", "text", {x=0,y=0,t="CreateUI("..id..", "..typeOf.."): \""..typeOf.."\" is not a valid type.",c={1,0,0}})
        print("CreateUI("..id..", "..typeOf.."): \""..typeOf.."\" is not a valid type.")
        return UILayer.data.latestError
    else
        CreateUI("latestError", "text", {x=0,y=0,t="CreateUI(...): An error occurred. Probably missing params.",c={1,0,0}})
        print("CreateUI(...): An error occurred. Probably missing params.")
        return UILayer.data.latestError
    end
end

function DestroyUI(id)
    if id and UILayer[id] then
        UILayer[id] = nil
    else
        CreateUI("latestError", "text", {x=0,y=0,t="DestroyUI(...): UI doesn't exist or no ID given.",c={1,0,0}})
        print("DestroyUI(...): UI doesn't exist or no ID given.")
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
        love.system.setClipboardText("currentInternalError is "..currentInternalError..".\nError is listed as follows:\n"..internalEngineErrors[currentInternalError])
    end
end

-- Load "books":

for key, value in pairs(love.filesystem.getDirectoryItems("_books")) do
    print("Detected book ("..value.."), adding to library.")
    require("_books."..value:sub(1, value:len()-4))
end

-- Begin with loading game.

RegenerateRandomness()

if testingError then
    _errorScreen("test")
end

if file_exists("game.lua") and not currentInternalError then
    if _read_file("game.lua") ~= "" then
        FontSize = 15
        require "game"
        if GameDat then
            if GameDat.title then
                love.window.setTitle("Ghost Engine: "..GameDat.title)
            else
                love.window.setTitle("Ghost Engine: Untitled Game")
                if math.random() >= 0.75 then
                    love.window.setTitle("Ghost Engine: The Newest Best Game?")
                end
            end
            if GameDat.removeWatermark and GameDat.title then
                love.window.setTitle(GameDat.title)
            end
        end
    else
        _errorScreen("GameUnloadable")
    end
else
    _errorScreen("NoGameDetected")
end