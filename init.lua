mq = require('mq')
require('ImGui')
Write = require("ldon/Write")
Locs = require('ldon/AdventureLocs')
Cast = require('ldon/LemonCast')


local advWnd = mq.TLO.Window("AdventureRequestWnd").Child
local currentZone = mq.TLO.Zone.ShortName()
local run = true

Write.loglevel = 'debug'

--Edit this
local HealthWatchPct = 80
local ManaWatchPct = 80
local PullAbilityTable = {--disc, spell, aa, ability, item
    ['PAL'] = {spell = 'Cease', type = 'spell'},
    ['WAR'] = {spell = 'Provoke', type = 'disc'},
    ['SHD'] = {spell = 'Clinging Darkness', type = 'spell'},
}
--Stop editing

local PullAbility = PullAbilityTable[mq.TLO.Me.Class.ShortName()].spell
local PullType = PullAbilityTable[mq.TLO.Me.Class.ShortName()].type

local recruiters = {
    ['northro'] = { name = "Escon Quickbow" },
    ['commonlands'] = { name = "Periac Windfell" },
    ['butcherblock'] = { name = "Xyzelauna TuValzir" },
    ['everfrost'] = { name = "Mannis McGuyett" },
    ['southro'] = { name = "Kallei Ribblok" }
}

arg = {...}
if #arg > 0 then
    skipToNum = tonumber(arg[1])
end

function GetAdventureStatus()
    if not mq.TLO.Group.Leader.Name() == mq.TLO.Me.Name() then
        Write.Error('You are not the group leader. Please get leadership of the group and try again. Ending Macro!')
        run = false
        return
    end

    if OpenWindow("AdventureRequestWnd") then
        if advWnd("AdvRqst_NPCText").Text():find('you are not currently assigned') then
            GetTask()
        elseif advWnd("AdvRqst_EnterTimeLeftLabel").Text():len() == 0 and advWnd("AdvRqst_CompleteTimeLeftLabel").Text():len() == 0 then
            GetTask()
        end
    else
        Write.Error('Cant open window. Ending.')
        run = false
    end
end

function GetTask()
    local zoneName = mq.TLO.Zone.ShortName()
    local recruiter = recruiters[zoneName]
    
    if recruiter then
        local recruiterSpawn = mq.TLO.Spawn(recruiter.name)
        local recruiterDistance = recruiterSpawn.Distance3D()
        Write.Debug('Recruiter Distance: %s',recruiterDistance)
        if recruiterDistance and recruiterDistance < 20 then
            print(1)
            FindTask()
        else
            print(2)
            if mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_EnterTimeLeftLabel").Text.Length() == 0 and mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_CompleteTimeLeftLabel").Text.Length() == 0 then
                Write.Info("Going to [%s] to pick up a task...", recruiter.name)
                NavLoc(recruiterSpawn.X(), recruiterSpawn.Y(), recruiterSpawn.Z(), 20000)
                GetTask() -- Recursively call function until task is found
            end
        end
    end
end

function FindTask()
    local Recruiter

    if currentZone == 'northro' then
        Recruiter = "Escon Quickbow"
    elseif currentZone == 'commonlands' then
        Recruiter = "Periac Windfell"
    elseif currentZone == 'butcherblock' then
        Recruiter = "Xyzelauna Tu`Valzir"
    elseif currentZone == 'everfrost' then
        Recruiter = "Mannis McGuyett"
    elseif currentZone == 'southro' then
        Recruiter = "Kallei Ribblok"
    end

    mq.delay(500)
    if mq.TLO.Target.ID() ~= mq.TLO.Spawn(Recruiter).ID() then
        mq.cmdf('/target id %d', mq.TLO.Spawn(Recruiter).ID())
    end
    mq.delay(2000, function() return mq.TLO.Target.ID() == mq.TLO.Spawn(Recruiter).ID() end)
    mq.cmd('/invoke ${Target.RightClick}')
    mq.delay(1000, function() return mq.TLO.Window("AdventureRequestWnd").Open() end)
    mq.cmd('/notify AdventureRequestWnd AdvRqst_RiskCombobox listselect 1') --**This is where hardmode would be selected
    mq.delay(1000)
    mq.cmd('/notify AdventureRequestWnd AdvRqst_TypeCombobox listselect 3')
    mq.delay(1000)
    mq.cmd('/notify AdventureRequestWnd AdvRqst_RequestButton leftmouseup')
    mq.delay(5000)
    mq.delay(1000, function() return mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_NPCText").Text():find("Slay") end)
    mq.delay(1000, function() return mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_AcceptButton").Enabled() end)
    mq.cmd('/notify AdventureRequestWnd AdvRqst_AcceptButton leftmouseup')
    mq.delay(5000)
    mq.cmd('/squelch /target clear')

    Write.Debug('window TimeLeft %s Text %s %s',mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_EnterTimeLeftLabel").Text():len(),mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_CompleteTimeLeftLabel").Text():len(),mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_NPCText").Text())
    if mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_EnterTimeLeftLabel").Text():len() > 0 then
        if mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_NPCText").Text():find("Slay") then
            print("This appears to be a slay count task. ")
        elseif mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_NPCText").Text():find("kill") then
            print("This appears to be a kill count task. ")
        elseif mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_NPCText").Text():find("Ridding") then
            print("This appears to be a ridding count task. ")
        end
    elseif mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_NPCText").Text():find("number of adventures") then
        Write.Error('Not available yet, looping after 1 minute')
        mq.delay(60000)
        FindTask()
    end
end

--EverFrost Peaks
function MoveToEntranceEverfrost()
    local zoneID = mq.TLO.Zone.ID()
    local zone_name = mq.TLO.Zone.ShortName()
    local enterTimeLeft = advWnd("AdvRqst_EnterTimeLeftLabel").Text():len()
    local completeTimeLeft = advWnd("AdvRqst_CompleteTimeLeftLabel").Text():len()
    local npcText = advWnd("AdvRqst_NPCText").Text()
    mq.delay(1000)
    Write.Debug('Finding which one it is: %s %s %s %s',zone_name,enterTimeLeft,completeTimeLeft,npcText)
    if (zone_name == 'everfrost' and enterTimeLeft > 0 and completeTimeLeft == 0) or (zone_name == 'everfrost' and enterTimeLeft == 0 and completeTimeLeft > 0) then
        Write.Debug(mq.TLO.Zone.ShortName() .. " vs Everfrost: " .. zone_name)
        -- getoutalive61
        if (npcText:find("glimmering portal of magic") and enterTimeLeft > 0 and completeTimeLeft == 0) or (npcText:find("glimmering portal of magic") and enterTimeLeft == 0 and completeTimeLeft > 0) then
            mq.cmd("/checkinvis")
            mq.cmd("/dgge /nav loc -841.47 -5460 188")
            mq.cmd("/nav loc -841.47 -5460 188")
            while not WaitToArrive(-841.47, -5460, 188,12) do
                mq.delay(5000)
                mq.cmd("/dgge /nav loc -841.47 -5460 188")
            mq.cmd("/nav loc -841.47 -5460 188")
            end
            Write.Info("Everyone is here. Going in to task...")
            mq.cmd("/dgge /removelev")
            GetIntoAdventure('efportal')
            Write.Debug('Made it in')
            mq.cmd("/generatelist")
            
        end
        if (npcText:find("snowy mine") and enterTimeLeft > 0 and completeTimeLeft == 0) or (npcText:find("snowy mine") and enterTimeLeft == 0 and completeTimeLeft > 0) then
            mq.cmd("/checkinvis")
            mq.cmd("/dgge /nav loc 2739.42 -4684.45 -105.04")
            mq.cmd("/nav loc 2739.42 -4684.45 -105.04")
            while not WaitToArrive(-841.47, -5460, 188,12) do
                mq.delay(5000)
                mq.cmd("/dgge /nav loc 2739.42 -4684.45 -105.04")
                mq.cmd("/nav loc 2739.42 -4684.45 -105.04")
            end
            print("Everyone is here. Going in to task...")
            mq.cmd("/dgge /nav loc 2772.21 -4726.54 -97.27")
            mq.cmd("/removelev")
            mq.cmd("/nav loc 2772.21 -4726.54 -97.27")
            Write.Info("Everyone is here. Going in to task...")
            mq.cmd("/doevents")
            GetIntoAdventure('efmine')
            Write.Debug('Made it in')
        end
    --mq.cmd("/generatelist") genreates a list of mobs and objects (named) up
        
    end
end

function GetIntoAdventure(adventureName)
    if adventureName == 'efportal' then
        Write.Debug('Trying to get through portal')
        mq.cmd("/dgge /doortarget MIRPORTAL700")
        mq.delay(2000)
        mq.cmd("/dgge /click left door")
        mq.cmd("/removelev")
        mq.cmd("/doortarget MIRPORTAL700")
        mq.delay(2000)
        mq.cmd("/click left door")
        while not WaitToZone() do
            Write.Debug('Trying again')
            mq.cmd("/dgge /doortarget MIRPORTAL700")
            mq.delay(2000)
            mq.cmd("/dgge /click left door")
            mq.cmd("/removelev")
            mq.cmd("/doortarget MIRPORTAL700")
            mq.delay(2000)
            mq.cmd("/click left door")
        end
    end
    if adventureName == 'efmine' then
        Write.Debug('Trying to get everyone into the mine')
        mq.cmd("/dgge /keypress back hold")
        mq.delay(2000)
        mq.cmd("/dgge /keypress back")
        mq.cmd("/dgge /doortarget")
        mq.delay(2000)
        mq.cmd("/dgge /click left door")
        mq.cmd("/keypress back hold")
        mq.delay(2000)
        mq.cmd("/keypress back")
        mq.cmd("/doortarget")
        mq.delay(2000)
        mq.cmd("/click left door")
        while not WaitToZone() do --Loop with the delay until we zone.
            Write.Debug('Trying to get everyone again')
            mq.cmd("/dgge /keypress back hold")
            mq.delay(2000)
            mq.cmd("/dgge /keypress back")
            mq.cmd("/dgge /doortarget")
            mq.delay(2000)
            mq.cmd("/dgge /click left door")
            mq.cmd("/keypress back hold")
            mq.delay(2000)
            mq.cmd("/keypress back")
            mq.cmd("/doortarget")
            mq.delay(2000)
            mq.cmd("/click left door")
        end
    end
    
end

function Adventure()
    Write.Debug('Going to start killing')
    for number=1, #Locs[mq.TLO.Zone.ShortName()] do
        if skipToNum then
            if number == skipToNum then skipToNum = nil end
        else
            Write.Debug('Moving to loc %s',number)
            mq.delay(500000, function () return mq.TLO.Me.CombatState() ~= 'COMBAT' end)
            MoveToPoint(number)
            mq.delay(500000, function () return mq.TLO.Me.CombatState() ~= 'COMBAT' end)
            while not WaitToArrive(Locs[mq.TLO.Zone.ShortName()][number].y, Locs[mq.TLO.Zone.ShortName()][number].x, Locs[mq.TLO.Zone.ShortName()][number].z,20) and mq.TLO.Me.CombatState() ~= 'COMBAT'  do
                MoveToPoint(number)
                mq.delay(2000)
            end
            mq.cmd('/dgge /nav stop')--If we caught agro mid move, stop everyone from going on
            Write.Debug('Arrived at loc %s',number)
            
            if not Locs[mq.TLO.Zone.ShortName()][number].no_kill then
                Write.Debug('Not no kill')
                mq.delay(2000)
                if Locs[mq.TLO.Zone.ShortName()][number].pull then 
                    Write.Debug('Need to pull')
                    PrepToKill()
                    PullMob()
                end
                Write.Debug('Should get agro')
                mq.delay(10000, function () return mq.TLO.Me.CombatState() == 'COMBAT' end)
                Write.Debug('Should have aggro %s',mq.TLO.Me.CombatState())
                mq.delay(500000, function () return mq.TLO.Me.CombatState() ~= 'COMBAT' end)
                Write.Debug('Should be done killing')
            end
            if not Locs[mq.TLO.Zone.ShortName()][number].no_prep then PrepToKill() end
        end
    end
    ExitInstance()
end

function PrepToKill()
    local ready = false
    while not ready do
        if mq.TLO.Group.Injured(HealthWatchPct)() >0 or mq.TLO.Group.LowMana(ManaWatchPct)() > 0 then
            mq.delay(5000)
            Write.Debug('Someone needs to med %s %s',mq.TLO.Group.Injured(HealthWatchPct)(),mq.TLO.Group.LowMana(ManaWatchPct)())
        else ready = true end
    end
    Write.Debug('Everyone is ready to kill')
end

function PullMob()
    local min = mq.TLO.Me.Level() - 9
    local max = mq.TLO.Me.Level() + 5
    Write.Debug('Targeting %s',mq.TLO.NearestSpawn('1, npc range '..min..' '..max).DisplayName())
    while mq.TLO.Target.ID() ~= mq.TLO.NearestSpawn('1, npc range '..min..' '..max).ID() do
        Write.Debug('Targeting %s',mq.TLO.NearestSpawn('1, npc range '..min..' '..max).DisplayName())
        DoTarget(mq.TLO.NearestSpawn('1, npc range '..min..' '..max).ID())
        mq.delay(2000)
    end
    Write.Debug('pulling %s with %s spawn %s',mq.TLO.Target.DisplayName(),PullAbility,mq.TLO.NearestSpawn('1, npc range '..min..' '..max).DisplayName())
    Cast.Cast(PullAbility,mq.TLO.Target.ID())
end

function ExitInstance()
    Write.Debug('Trying to exit')
    mq.cmd("/dgge /doortarget MPORTAL700e")
    mq.delay(2000)
    mq.cmd("/dgge /click left door")
    mq.cmd("/removelev")
    mq.cmd("/doortarget MPORTAL700e")
    mq.delay(2000)
    mq.cmd("/click left door")
    while not WaitToZone() do
        Write.Debug('Trying again')
        allNavLoc(641.88, 548.5, -88.369)
        WaitToArrive(641.88, 548.5, -88.369,12)
        mq.cmd("/dgge /doortarget MPORTAL700e")
        mq.delay(2000)
        mq.cmd("/dgge /click left door")
        mq.cmd("/removelev")
        mq.cmd("/doortarget MPORTAL700e")
        mq.delay(2000)
        mq.cmd("/click left door")
        
    end
end



--Helper Functions

function MoveToPoint(num)
    local zone_name = mq.TLO.Zone.ShortName()
    allNavLoc(Locs[zone_name][num].x, Locs[zone_name][num].y, Locs[zone_name][num].z, 20000)
end

function WaitToArrive(y,x,z,buffer)--Flipflopped EQ coordinates....
    --For each group member, wait until were all at this given location using Spawn, then return
    mq.delay(3000)
    Write.Debug('Waiting for everyone to arrive at %s %s %s',x,y,z)
    for i = 0, mq.TLO.Group.Members() do
        local member = mq.TLO.Group.Member(i)
        --Write.Debug('member %s x%s y%s z%s minus x %s y %s z %s',member(),member.X(),member.Y(),member.Z(),math.abs(member.X() - x),math.abs(member.Y() - y),math.abs(member.Z() - z))
        if member() and member.X() and (math.abs(member.X() - x) > buffer or math.abs(member.Y() - y) > buffer or math.abs(member.Z() - z) > buffer) then
            Write.Debug('%s isnt here yet ',member())
            return false
        end
    end
    return true
end

function WaitToZone()
    Write.Debug('Waiting to zone from %s',currentZone)
    mq.delay(15000, function() return currentZone ~= mq.TLO.Zone.ShortName() end)
    mq.delay(1000)
    if currentZone ~= mq.TLO.Zone.ShortName() then
        currentZone = mq.TLO.Zone.ShortName()
        Write.Debug('Zoned to %s',currentZone)
        return true
    else
        Write.Debug('Failed to zone. Still in %s',currentZone)
        return false
    end
end

function OpenWindow(windowName)
    mq.cmdf('/windowstate %s open',windowName)
    mq.delay(10000, function () return mq.TLO.Window(windowName).Open() end)
    if not mq.TLO.Window(windowName).Open() then
        Write.Debug('Could not open %s',windowName)
        return false
    else
        return true
    end
end

local function waitToStop(howLong)
    mq.delay(300, function() return mq.TLO.Navigation.Active() end)
    mq.delay(howLong, function() return not mq.TLO.Navigation.Active() end)
    if howLong > 3000  and mq.TLO.Navigation.Paused() then mq.cmd('/nav pause') end--If path is stuck, this should unstick it. If movement problems, try getting rid of this **
end

function NavLoc(x,y,z,wait)
    mq.cmdf("/nav loc %s %s %s",y,x,z)
    if wait then waitToStop(wait) end
end

function allNavLoc(x,y,z,wait)
    mq.cmdf("/dgga /nav loc %s %s %s",y,x,z)
    if wait then waitToStop(wait) end
end


while run do
    GetAdventureStatus()--Includes GetTask, findtask
    MoveToEntranceEverfrost() --Need to make dynamic**
    Adventure()
    mq.delay(10000)
end