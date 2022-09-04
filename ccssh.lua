local expect = require("cc.expect")

local VERSION = '0.0.1'
---@diagnostic disable-next-line: undefined-field
local computerID = os.getComputerID()


if shell and shell.getRunningProgram() == "ccssh.lua" then
    -- loaded from shell, not a module
    print('ccssh ' .. VERSION)

    local width, height = term.getSize()
    term.clear()
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.yellow)

    -- write the computer ID
    term.setCursorPos(1, 1)
    for i = 1, width do
        term.write(" ")
    end
    term.setCursorPos(1, 1)
    term.write("Computer #" .. computerID)

    -- write CCSSH version on the bottom
    term.setCursorPos(1, height)
    for i = 1, width do
        term.write(" ")
    end
    term.setCursorPos(1, height)
    term.write("CCSSH v" .. VERSION)

    local pps = peripheral.getNames()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 3)
    term.write("Attached peripherals:")
    if #pps == 0 then
        term.setTextColor(colors.gray)
        term.setCursorPos(2, 4)
        term.write("> No peripherals found")
    else
        for i = 1, #pps do
            term.setCursorPos(2, i + 3)
            term.setTextColor(colors.gray)
            term.write("> ")
            term.setTextColor(colors.white)
            term.write(pps[i])
            term.setTextColor(colors.lightGray)
            term.write("  (" .. table.concat({ peripheral.getType(pps[i]) }, ', ') .. ")")
        end
    end

    local modem = peripheral.find("modem")
    if modem then
        rednet.open(peripheral.getName(modem))
        rednet.host("ccssh", "ccssh_" .. computerID)
        while true do
            local senderID, message, protocol = rednet.receive("ccssh")

            local command = message[1]

            if command == "call" then
                local periph, func, args = unpack(message, 2)
                local p = peripheral.wrap(periph)
                if p then
                    local s, retval = pcall(p[func], unpack(args))
                    rednet.send(senderID, { s, retval }, "ccssh")
                else
                    -- if the peripheral doesn't exist, return an error
                    local result = { false, "Peripheral not found" }
                    rednet.send(senderID, result, "ccssh")
                end
            elseif command == "ping" then
                local result = { true, "pong" }
                rednet.send(senderID, result, "ccssh")
            elseif command == "list_methods" then
                -- lists the methods for a given peripheral, used to wrap the peripheral
                local periph = message[2]
                local methods = peripheral.getMethods(periph)
                if methods ~= nil then
                    local result = { true, methods }
                    rednet.send(senderID, result, "ccssh")
                else
                    -- if the peripheral doesn't exist, return an error
                    local result = { false, "Peripheral not found" }
                    rednet.send(senderID, result, "ccssh")
                end
            else
                local result = { false, "unknown command" }
                rednet.send(senderID, result, "ccssh")
            end
        end
    else
        term.setTextColor(colors.red)
        term.setCursorPos(1, height - 2)
        term.write("No modem found!")
    end
else
    -- loaded as a module
    local ccssh = {}

    function ccssh.version()
        return VERSION
    end

    function ccssh.call(id, periph, func, ...)
        expect(1, id, "number")
        expect(2, periph, "string")
        expect(3, func, "string")
        local modem = peripheral.find("modem")
        if modem then
            rednet.open(peripheral.getName(modem))
            rednet.send(id, {
                "call",
                periph,
                func,
                { ... }
            }, "ccssh")

            local senderID, message = rednet.receive("ccssh")
            local success, result = unpack(message)
            return success, result
        else
            return false, "No modem found!"
        end
    end

    -- wraps a peripheral, allowing you to call methods on it
    function ccssh.wrap(id, periph)
        expect(1, id, "number")
        expect(2, periph, "string")
        local modem = peripheral.find("modem")
        if modem then
            rednet.open(peripheral.getName(modem))
            rednet.send(id, {
                "list_methods",
                periph
            }, "ccssh")

            local senderID, message = rednet.receive("ccssh")
            local success, methods = unpack(message)

            if success then
                local p = {}
                for i = 1, #methods do
                    local method = methods[i]
                    p[method] = function(...)
                        local s, result = ccssh.call(id, periph, method, ...)
                        if s then
                            return result
                        else
                            error("recieved remote error: \n " .. result)
                        end
                    end
                end
                p["ping"] = function(timeout)
                    return ccssh.ping(id, timeout)
                end
                return p
            else
                return nil
            end
        else
            print("No modem found!")
            return nil
        end
    end

    function ccssh.ping(id, timeout)
        expect(1, id, "number")
        expect(2, timeout, "number", "nil")
        local modem = peripheral.find("modem")
        if modem then
            rednet.open(peripheral.getName(modem))
            rednet.send(id, { "ping" }, "ccssh")
            local senderID, message = rednet.receive("ccssh", timeout or 3)
            return senderID ~= nil and message[1] == true
        else
            return false, "No modem found!"
        end
    end

    return ccssh
end
