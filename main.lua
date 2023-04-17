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

local lume = require "lume" -- required for certain functionality, may be intergrated at some point.

local enet = require "enet"

local enethost = nil
local hostevent = nil
local clientpeer = nil
local enetclient = nil
local enetnick = lume.uuid()

if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    local lldebugger = require("lldebugger")
    lldebugger.start()
    local run = love.run
    function love.run(...)
        local f = lldebugger.call(run, false, ...)
        return function(...) return lldebugger.call(f, false, ...) end
    end
end

love.filesystem.setIdentity("Ghost Engine")

love.filesystem.write("test.txt", "Hi")

ghostengine = {}
ghostengine.log = function (text) print(text) io.write(text) end

local currentDate = os.date("*t")

local logFile = io.open("log", "a")

---@diagnostic disable-next-line: param-type-mismatch
io.output(logFile)

ghostengine.log("Hello, World! - "..currentDate.month.."/"..currentDate.day.."/"..currentDate.year.." at "..currentDate.hour..":"..currentDate.min..":"..currentDate.sec.. "\n    (Using user's local os time)")

love.window.setTitle("Ghost Engine: Initalizing")

-- Define local variables & functions:

local preparedebugmode = false
local debugmode = false
local utf8 = require("utf8")
local gameLoaded = false
local currentInternalError = nil
local validTypes = { "text", "image", "rect", "circle", "textbox", "button" }
local majorUiTypes = {"textbox", "button"}
local internalEngineErrors = {
    NoGameDetected =
    "Welcome to Ghost Engine!\nNo game.lua file detected.\nIs it in the right folder?\nRead the DOCUMENTATION file for help.\n\n[ [-- (E404) --] ]",
    GameUnloadable =
    "game.lua file detected, but couldn't be assessed.\nRead the DOCUMENTATION file for help.\n\n[ [-- (E403) --] ]",
    Test = "Success.\n\n[ [-- (E000) --] ]",
    IncompatiableSystem = "Your system (" ..
        love.system.getOS() ..
        ") is incompatible with Ghost Engine.\nWe apologize for the inconvenience.\n\n[ [-- (E100) --] ]",
    LeftAltHeld = "LeftAlt was held down.\n\n[ [-- (E001) --] ]"
}
local textboxThatIsFocused = ""
local focusedOnTextbox = false
local camera = {x=0,y=0}

local function file_exists(name)
    if type(name) ~= "string" then return false end
    local f, err = io.open(name, "r")
    if err then return false end
    ---@diagnostic disable-next-line: need-check-nil
    f:close()
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

local function _errorScreen(c)
    if currentInternalError then
        return;
    end
    if c == "IncompatiableSystem" then
        love.graphics.setBackgroundColor(0.8,0,0)
        CreateUI("warning", "text", {t="Your system is incompatible."})
        currentInternalError = c
        return;
    else
        love.window.setTitle("Ghost Engine: Engine Menu")
        currentInternalError = c
        love.keyboard.setKeyRepeat(true)
        ghostengine.log("SoftHalt: ".. c)
        ghostengine.log("Going to Engine Menu.")
        love.graphics.setBackgroundColor(0.45, 0.45, 0.45)
        CreateUI("label", "text", {t="Ghost Engine v0.4.0", x=295})
        CreateUI("fill1", "rect", {x=-1, y=470, w=400, h=200, mode="fill", clr={0.2, 0.2, 0.2}})
        CreateUI("border1", "rect", {x=-1, y=470, w=400, h=200})
        CreateUI("reasoning", "text", {t="You are seeing this screen because:\ngame.lua couldn't be loaded\ngame.lua doesn't exist\nOr LeftAlt was held down\nCTRL-C to copy err", y=480, x=10})
        ghostengine.createObject("UILayer","buttonToGit", "button", {t="Open GitHub repository", x=50, y=100, w=400, h=50})
        ghostengine.createObject("UILayer","buttonToOpenReadme", "button", {t="Open README.md", x=50, y=170, w=400, h=50})
        ghostengine.createObject("UILayer","buttonToClose", "button", {t="Close Ghost Engine (or press ESC)", x=50, y=240, w=400, h=50})
        ghostengine.createObject("UILayer", "warning", "text", {t="Use textbox below to forcefully open a file in current working directory.\nBeware: bugs ahead!", x=40, y=285})
        ghostengine.createObject("UILayer","fileInsertion", "textbox", {x=50, y=350, w=400, h=50, maxCharLimit = 30})
        ghostengine.createObject("UILayer","buttonToLoad", "button", {t="Open this file anyway", x=480, y=350, w=250, h=50})
        ---@diagnostic disable-next-line: duplicate-set-field
        function ghostengine.onButtonPress(button)
            if button == "buttonToGit" then
                love.system.openURL("https://github.com/GhostedNotFound/ghostEngine")
            elseif button == "buttonToOpenReadme" then
                if not love.system.openURL("readme.md") then
                    love.system.openURL("https://github.com/GhostedNotFound/ghostEngine/blob/master/readme.md")
                end
            elseif button == "buttonToClose" then
                love.event.quit()
            elseif button == "buttonToLoad" then
                local toLoad = ghostengine.layers.UILayer.fileInsertion.data.t
                if toLoad == "--debug-mode" and not preparedebugmode then
                    ghostengine.log("preparing debug mode")
                    preparedebugmode = true
                    ghostengine.layers.UILayer.warning.data.t = "\nenter superuser authetication"
                    ghostengine.layers.UILayer.fileInsertion.data.t = ""
                    return;
                end
                if toLoad == love.system.getOS():lower().."-debug" and preparedebugmode and not debugmode then
                    debugmode = true
                    ghostengine.log("debug mode active")
                    ghostengine.layers.UILayer.warning.data.t = "\ndebugmode active"
                    ghostengine.layers.UILayer.fileInsertion.data.t = ""
                    return;
                end
                if toLoad == "" then
                    return;
                end
                ghostengine.layers = {UILayer = {}, BackgroundLayer = {}, ForegroundLayer={}}
                ghostengine.textboxes = {}
                ghostengine.buttons = {}
                love.graphics.setBackgroundColor(0,0,0)
                love.window.setTitle("Ghost Engine: Custom Load")
                currentInternalError = false
                require(toLoad)
                ghostengine.fontSize = 15
                _getGameDat()
            end
        end
    end
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
        ghostengine.layers.ForegroundLayer = {}
    end
end

local function _isInsideBox(x1, y1, x2, y2, x, y)
    if x >= x1 and y >= y1 and x <= x2 and y <= y2 then
        return true
    else
        return false
    end
end

local function _doPredeterminedTypes(k, v)
    love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
    local coords = {x=v.data.x or 0, y=v.data.y or 0}
    coords.x = coords.x + camera.x
    coords.y = coords.y + camera.y
    if v.type == "text" then
        love.graphics.print(v.data.t, coords.x, coords.y)
    elseif v.type == "button" then
        if v.data.t then
            love.graphics.setColor({ 0, 0, 0, 1 })
            if _isInsideBox(coords.x-(ghostengine.fontSize*0.5), coords.y-(ghostengine.fontSize*0.5), (coords.x-(ghostengine.fontSize*0.5)) + v.data.w, (coords.y-(ghostengine.fontSize*0.5)) + v.data.h, love.mouse.getX(), love.mouse.getY()) then
                love.graphics.setColor({ 0.05, 0.05, 0.05, 1 }) 
            end
            love.graphics.rectangle("fill", (coords.x-(ghostengine.fontSize*0.5)), (coords.y-(ghostengine.fontSize*0.5)), v.data.w, v.data.h)
            love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
            love.graphics.rectangle("line", (coords.x-(ghostengine.fontSize*0.5)), (coords.y-(ghostengine.fontSize*0.5)), v.data.w, v.data.h)
            love.graphics.print(v.data.t, coords.x, coords.y)
        else
            love.graphics.setColor({ 0, 0, 0, 1 })
            if _isInsideBox(coords.x, coords.y, coords.x + v.data.w, coords.y + v.data.h, love.mouse.getX(), love.mouse.getY()) then
                love.graphics.setColor({ 0.05, 0.05, 0.05, 1 }) 
            end
            love.graphics.rectangle("fill", coords.x, coords.y, v.data.w, v.data.h)
            love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
            love.graphics.rectangle("line", coords.x, coords.y, v.data.w, v.data.h)
        end
    elseif v.type == "textbox" then
        love.graphics.setColor({ 0, 0, 0, 1 })
        love.graphics.rectangle("fill", (coords.x-(ghostengine.fontSize*0.5)) or 0, (coords.y-(ghostengine.fontSize*0.5)) or 0, v.data.w, v.data.h)
        love.graphics.setColor(v.data.clr or { 1, 1, 1, 1 })
        if textboxThatIsFocused == v.data.id or _isInsideBox(coords.x, coords.y, coords.x + v.data.w, v.data.h + coords.y, love.mouse.getX(), love.mouse.getY()) then
            love.graphics.print(v.data.t.."|", coords.x, coords.y)
        else
            love.graphics.print(v.data.t, coords.x, coords.y)
        end
        love.graphics.rectangle("line", (coords.x-(ghostengine.fontSize*0.5)) or 0, (coords.y-(ghostengine.fontSize*0.5)) or 0, v.data.w, v.data.h)
    elseif v.type == "image" then
        _enforceHaltIf(file_exists(v.data.i), "Originated from CreateUI(" ..
            k ..
            ", " ..
            v.type ..
            ", {i=\"" ..
            v.data.i ..
            "\"}): Image (" ..
            v.data.i .. ") is non-existant.\nCurrent version of Ghost Engine has flaws, so halt was enforced.")
        love.graphics.draw(love.graphics.newImage(v.data.i), coords.x, coords.y)
    elseif v.type == "rect" then
        love.graphics.rectangle(v.data.mode or "line", coords.x, coords.y, v.data.w,
            v.data.h)
    elseif v.type == "circle" then
        love.graphics.circle(v.data.mode or "line", coords.x, coords.y, v.data.rad,
            v.data.seg or 30)
    elseif v.type == "3D-Cube" then
        love.graphics.line(coords.x * v.data.size, coords.y * v.data.size, coords.x * v.data.size, (coords.y + 50) * v.data.size)
        love.graphics.line((coords.x + 50) * v.data.size, (coords.y + 75) * v.data.size, (coords.x + 50) * v.data.size, (coords.y + 25) * v.data.size)
        love.graphics.line((coords.x + 100) * v.data.size, (coords.y + 50) * v.data.size, (coords.x + 100) * v.data.size, coords.y * v.data.size)
        love.graphics.line(coords.x * v.data.size, coords.y * v.data.size, (coords.x + 50) * v.data.size, (coords.y + 25) * v.data.size)
        love.graphics.line(coords.x * v.data.size, (coords.y + 50) * v.data.size, (coords.x + 50) * v.data.size, (coords.y + 75) * v.data.size)
        love.graphics.line((coords.x + 50) * v.data.size, (coords.y + 75) * v.data.size, (coords.x + 100) * v.data.size, (coords.y + 50) * v.data.size)
        love.graphics.line((coords.x + 50) * v.data.size, (coords.y + 25) * v.data.size, (coords.x + 100) * v.data.size, coords.y * v.data.size)
        love.graphics.line(coords.x * v.data.size, coords.y * v.data.size, (coords.x + 50) * v.data.size, (coords.y - 25) * v.data.size)
        love.graphics.line((coords.x + 100) * v.data.size, coords.y * v.data.size, (coords.x + 50) * v.data.size, (coords.y - 25) * v.data.size)
    end
end

local function _drawBackgroundLayer()
    for key, value in pairs(ghostengine.layers.BackgroundLayer) do
        _doPredeterminedTypes(key, value)
        ghostengine.drawCustomTypes(key, value)
    end
end

local function _inTable(table, searchFor)
    local found = false
    for key, value in pairs(table) do
        if value == searchFor then
            found = true
        end
    end
    return found
end

local function _drawForegroundLayer()
    for key, value in pairs(ghostengine.layers.ForegroundLayer) do
        _doPredeterminedTypes(key, value)
        ghostengine.drawCustomTypes(key, value)
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
    buttons = {},
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
        id = id or lume.uuid()
        if type(id) == "string" and type(layer) == "string" and type(data) == "table" and _inTable(validTypes, typeOf) and ghostengine.layers[layer] and not ghostengine.layers[layer][id] then
            if layer == "BackgroundLayer" and _inTable(majorUiTypes, typeOf) then
                ghostengine.log("[?] "..typeOf.." (a major UI object) cannot be in the BackgroundLayer, moving to ForegroundLayer.")
                layer = "ForegroundLayer"
            end
            if typeOf == "textbox" then
                ghostengine.textboxes[id] = data
                if not data.t then
                    data.t = ""
                end
            end
            if typeOf == "button" then
                ghostengine.buttons[id] = data
            end
            data["id"] = id
            data["destroy"] = function(self)
                ghostengine.log("Destroyed ObjectId " .. self.id)
                if ghostengine.layers[layer][self.id].type == "textbox" then
                    ghostengine.textboxes[self.id] = nil
                end
                if ghostengine.layers[layer][self.id].type == "button" then
                    ghostengine.buttons[self.id] = nil
                end
                ghostengine.layers[layer][self.id] = nil
            end
            ghostengine.layers[layer][id] = { type = typeOf, data = data }
            ghostengine.log("Created new Object in layer ".. layer.. " with id ".. id .. " as type ".. typeOf)
            return ghostengine.layers[layer][id].data
        elseif not _inTable(validTypes, typeOf) then
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
    log = function (text)
        if currentDate.day == 1 and currentDate.month == 4 then
            print("           \n\n\n"..text.." ...or did it?")
            io.write("\n\n\n\n\n\n"..text.." ...or did it?")
        else
            print(text)
            io.write("\n"..text)
        end
    end,
    network = {
        connections = {},
        host = function(port)
            if type(port) ~= "number" then
                port = nil
            end
            port = port or 12211 -- 12211 -> 12 21 1 -> 12(L) 21(U) 1(A) -> LUA
            -- establish host for receiving msg
            enethost = enet.host_create("localhost:"..port)

            -- establish a connection to host on same PC
            enetclient = enet.host_create()
            clientpeer = enetclient:connect("localhost:"..port)
            ghostengine.log("Hosting a server on localhost:"..port..".")
            ghostengine.log("[ ! ] Do not, for any reason, use the connections table inside OnClientDataGet().")
        end,
        server = function (port)
            if type(port) ~= "number" then
                port = nil
            end
            port = port or 12211 -- 12211 -> 12 21 1 -> 12(L) 21(U) 1(A) -> LUA
            -- establish host for receiving msg
            enethost = enet.host_create("localhost:"..port)
            ghostengine.log("Created a server on localhost:"..port..", but did not connect to it.")
        end,
        client = function (nick, port)
            if type(port) ~= "number" then
                port = nil
            end
            if type(nick) ~= "string" then
                nick = nil
            end
            port = port or 12211 -- 12211 -> 12 21 1 -> 12(L) 21(U) 1(A) -> LUA
            enetnick = nick or lume.uuid()
            enetclient = enet.host_create()
            clientpeer = enetclient:connect("localhost:"..port)
            ghostengine.log("Connected to a server on localhost:"..port.." if any.\nDisconnection may occur if keepalive fails.")
        end,
        OnAddConnection = function (peer)
            
        end,
        OnRemoveConnection = function (peer)
            
        end,
        OnServerGet = function (data)
            
        end
    },
    socket = require("socket"),
    camera = {
        x = camera.x,
        y = camera.y,
        setCoordinates = function (x,y)
            camera.x = x
            camera.y = y
        end,
        changeCoordinatesBy = function (x,y)
            camera.x = camera.x + x
            camera.y = camera.y + y
        end,
        changeXBy = function (x)
            camera.x = camera.x + x
        end,
        changeYBy = function (y)
            camera.y = camera.y + y
        end
    },
    drawCustomTypes = function(k, v) end,
    frame = function() end,
    keyDown = function (key, scancode, rep) end,
    onTextboxSubmit = function (textboxId, dataSubmitted) -- If returns true (requires submitOnEnter attribute), undo readOnly. Rationale: if returned true, most likely what was inputted was invalid by the dev's standards
        
    end,
    onButtonPress = function (button) 
    end
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
    ghostengine.camera.x = camera.x
    ghostengine.camera.y = camera.y
    love.graphics.setNewFont(ghostengine.fontSize)
    _layersExist()
    _drawBackgroundLayer()
    _drawOtherLayers()
    _drawForegroundLayer()
    _drawUiLayer()
end

function love.update()
    ghostengine.frame()
    if enethost then
        local event = enethost:service(100)
        while event do
          if event.type == "connect" then
            ghostengine.network.connections[tostring(event.peer)] = event.peer
            ghostengine.log("New Client Connected ("..tostring(event.peer)..")")
            ghostengine.network.OnAddConnection(event.peer)
          elseif event.type == "disconnect" then
            ghostengine.network.connections[tostring(event.peer)] = nil
            ghostengine.log("Client Disconnected ("..tostring(event.peer)..")")
            ghostengine.network.OnRemoveConnection(event.peer)
          elseif event.type == "receive" then
            ghostengine.log("Data Get From ("..tostring(event.peer).."), "..event.data)
            ghostengine.network.OnServerGet(event.data)
          end
          event = enethost:service()
        end
    end
    if enetclient then
        local event = enetclient:service(100)
        while event do
            if event.type == "connect" then
              ghostengine.network.connections[tostring(event.peer)] = event.peer
              ghostengine.log("Other Client Connected")
              ghostengine.network.OnAddConnection(event.peer)
            elseif event.type == "disconnect" then
              ghostengine.network.connections[tostring(event.peer)] = nil
              ghostengine.log("Other Client Disconnected")
              ghostengine.network.OnRemoveConnection(event.peer)
            elseif event.type == "receive" then
              ghostengine.log("Server Sent Data "..event.data)
              ghostengine.network.OnServerGet(event.data)
            end
            event = enethost:service()
          end
    end
    ghostengine.ticks = ghostengine.ticks + 1
end

function love.mousepressed(mx, my, button, istouch, presses)
    mx = love.mouse.getX() - camera.x
    my = love.mouse.getY() - camera.y
    local clickontxtbox
    for key, value in pairs(ghostengine.textboxes) do
        if _isInsideBox(value.x-(ghostengine.fontSize*0.5), value.y-(ghostengine.fontSize*0.5), (value.x-(ghostengine.fontSize*0.5)) + value.w, (value.y-(ghostengine.fontSize*0.5)) + value.h, mx, my) and not value.readOnly then
            clickontxtbox = value.id
            ghostengine.log("Focused on textbox named \""..value.id.."\".")
        elseif value.readOnly and _isInsideBox(value.x-(ghostengine.fontSize*0.5), value.y-(ghostengine.fontSize*0.5), (value.x-(ghostengine.fontSize*0.5)) + value.w, (value.y-(ghostengine.fontSize*0.5)) + value.h, mx, my) then
            ghostengine.log("Textbox \"".. value.id .."\" is read-only. Did not focus.")
            if presses == 3 then
                ghostengine.log("please stop clicking on the textbox.")
            end
            if presses == 4 then
                ghostengine.log("no like seriously please stop clicking on the textbox.")
            end
            if presses >= 5 then
                ghostengine.log("the logs are gonna look like chaos")
            end
        end
    end
    for key, value in pairs(ghostengine.buttons) do
        if value.t then
            if _isInsideBox(value.x-(ghostengine.fontSize*0.5), value.y-(ghostengine.fontSize*0.5), (value.x-(ghostengine.fontSize*0.5)) + value.w, (value.y-(ghostengine.fontSize*0.5)) + value.h, mx, my) and not value.readOnly then
                ghostengine.log("Pressed button named \""..value.id.."\".")
                ghostengine.onButtonPress(value.id)
            elseif value.readOnly and _isInsideBox(value.x-(ghostengine.fontSize*0.5), value.y-(ghostengine.fontSize*0.5), (value.x-(ghostengine.fontSize*0.5)) + value.w, (value.y-(ghostengine.fontSize*0.5)) + value.h, mx, my) then
                ghostengine.log("Button \"".. value.id .."\" is read-only. Did not focus.")
            end
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
    if key == "d" and love.keyboard.isDown("lctrl") and love.keyboard.isDown("lalt") and debugmode then
        ghostengine.log("debugKeybindPressed")
        debug.debug()
    end
    if not focusedOnTextbox then
        ghostengine.keyDown(key, scancode, isrepeat)
    else
        if key == "backspace" then
            local byteoffset = utf8.offset(ghostengine.textboxes[textboxThatIsFocused].t, -1)
            if byteoffset then
                ghostengine.textboxes[textboxThatIsFocused].t = string.sub(ghostengine.textboxes[textboxThatIsFocused].t, 1, byteoffset - 1)
            end 
        end
        if key == "return" and ghostengine.textboxes[textboxThatIsFocused].stopOnEnter then
            ghostengine.textboxes[textboxThatIsFocused].readOnly = true
            ghostengine.log("Unfocused & locked textbox because enter was pressed.")
            focusedOnTextbox = false
            if ghostengine.onTextboxSubmit(textboxThatIsFocused, ghostengine.textboxes[textboxThatIsFocused].t) then -- Rationale: if returned true, most likely what was inputted was invalid by the dev's standards
                ghostengine.textboxes[textboxThatIsFocused].readOnly = false
                ghostengine.log("Undid changes, onTextboxSubmit returned true.")
            end
            textboxThatIsFocused = ""
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

if love.keyboard.isDown("lalt") then
    _errorScreen("LeftAltHeld")
end

if love.system.getOS() == "Windows" then
    if not currentInternalError or love.keyboard.isDown("lalt") then
        ghostengine.fontSize = 15
        require("game")
        _getGameDat()
    end
else
    if file_exists("game.lua") and not currentInternalError or love.keyboard.isDown("lalt") then
        ghostengine.fontSize = 15
        require("game")
        _getGameDat()
    elseif not currentInternalError then
        _errorScreen("NoGameDetected")
    end
end

function love.quit()
    ghostengine.log("Ran for ".. os.clock() .." in OSCLOCK\n[✓] PRESS \n    (Program Ran and Exited System Successfully)".."\n\n\n")
    if currentDate.day == 1 and currentDate.month == 4 then
        ghostengine.log("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse porttitor accumsan urna sit amet finibus. Sed tincidunt laoreet purus vitae maximus. Aliquam erat volutpat. Integer tincidunt libero leo, eget vehicula odio fringilla quis. Donec tortor nibh, pellentesque at consequat vitae, pellentesque ut dolor. Duis sit amet ipsum in lorem aliquam pharetra. Ut condimentum convallis ex. Aliquam quis mauris elit. Vestibulum laoreet velit vel libero vulputate porttitor. Donec porttitor congue elit, sit amet iaculis neque pellentesque sit amet. Suspendisse cursus quis ante nec rhoncus.".."\n\n\n")
    end
    io.close(logFile)
end