term.setCursorPos(1, 1)
term.clear()
term.setBackgroundColor(colors.yellow)
term.setTextColor(colors.black)
print("CCSSH installation script")
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)

if (fs.exists('ccssh.lua')) then
    term.setTextColor(colors.red)
    print("\nWarning: ccssh.lua already exists in the root directory of this computer.")
end

-- ask the user if they want to run ccssh on startup
print("\nWould you like to run CCSSH on startup?")
local x, y = term.getCursorPos()
local answered = false
local selected = 0
while not answered do
    term.setCursorPos(1, y)
    term.setTextColor(selected == 0 and colors.white or colors.gray)
    term.write("> ")
    term.setTextColor(colors.white)
    term.write("Yes")
    term.setCursorPos(1, y + 1)
    term.setTextColor(selected == 1 and colors.white or colors.gray)
    term.write("> ")
    term.setTextColor(colors.white)
    term.write("No")
    local event, key = os.pullEvent("key")
    if event == "key" then
        if key == keys.up then
            selected = selected - 1
        elseif key == keys.down then
            selected = selected + 1
        elseif key == keys.enter then
            answered = true
        end
        if selected < 0 then
            selected = 1
        elseif selected > 1 then
            selected = 0
        end
    end
end
print("")

-- remove previous installation
if (fs.exists('ccssh.lua')) then
    fs.delete('ccssh.lua')
end

-- copy to ccssh.lua
fs.copy('disk/ccssh.lua', '/ccssh.lua')


if selected == 0 then
    -- copy the install script
    -- first remove the old one if it exists
    if fs.exists('/startup.lua') then
        fs.delete('/startup.lua')
    end
    -- then copy the new startup
    fs.copy('disk/startup_script.lua', '/startup.lua')
    print("\nThe Startup script has been created.")
end

print('CCSSH installed!\nRebooting...')
peripheral.find('drive').ejectDisk()

os.sleep(1)
os.reboot()
