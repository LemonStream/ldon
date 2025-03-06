mq = require('mq')

local Adventure_Locs = loadfile(mq.configDir .. "/AdventureLocs.lua")() or {}

-- Function to save the table to a file
local function saveAdventureLocs()
    local path = mq.configDir .. "/AdventureLocs.lua"
    mq.pickle(path, Adventure_Locs)
end

function Event_OnLocationCaptured(line, y, x, z)
    local zone = mq.TLO.Zone.ShortName()
    
    -- Initialize table if it doesn't exist

    if not Adventure_Locs[zone] then
        Adventure_Locs[zone] =  {}
    end

    -- Add location to the table
    table.insert(Adventure_Locs[zone], {y = tonumber(y), x = tonumber(x), z = tonumber(z)})

    print(string.format("\agLocation recorded in %s: Y=%s, X=%s, Z=%s", zone, y, x, z))
    
    -- Save the table after adding a new entry
    saveAdventureLocs()
end

mq.event("OnLocationCaptured", "#*#Your Location is #1#, #2#, #3#,#*#", Event_OnLocationCaptured)

-- Function to record location
local function recordLocation()
    print("\agCapturing current location...")
    mq.cmd("/loc")  -- This triggers the event to capture the coordinates
end

-- Bind command for easy use
mq.bind("/recordloc", recordLocation)

print("\agAdventure Location Recorder Loaded. Use /recordloc to save your current location.")

while true do
    mq.delay(500)
    mq.doevents()
end