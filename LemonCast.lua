--[[
    Instead of a classic ini based system with a tool to autocreate it based on level, I could instead create a logic system
    that chooses what to do based on what's available and what is toggled in the UI. Problem is that's harder to do without having the UI etc
]]

local Cast = {}
local shortName = mq.TLO.Me.Class.ShortName()
fizzled = false
local DidNotStick = false


local typeToFunction = {
    spell = 'Cast.Spell',
    ability = 'Cast.Ability',
    disc = Cast.Disc,
    aa = Cast.AA,
    item = Cast.Item,
}

function Cast.Type(type)
    if string.find(type,'spell') then
        type = 'spell'
    elseif string.find(type,'disc') then
        type = 'disc'
    elseif string.find(type,'ability') then
        type = 'ability'
    elseif string.find(type,'aa') then
        type = 'aa'
    elseif string.find(type,'item') then
        type = 'item'
    end
    return type
end

function Cast.Target(target)
    if string.find(target,'enemy') then
        target = mq.TLO.Spawn(target).ID()
    elseif string.find(target,'self') then
        target = mq.TLO.Me.ID()
    elseif type(target) == 'number' then
        --Keep the id
    else 
        target = mq.TLO.Spawn('pc '..target).ID()
    end 
    Write.Trace('Target is %s %s',target, mq.TLO.Spawn(target)())
    return target
end

function Cast.Events()
    mq.doevents('fizzle')
end

function Cast.StopCast()
    mq.cmd('/stopcast')
end

function Cast.Wait(isheal)--**Need to add in emergency healing and stop healing if healed
    Write.Trace('Wait window %s %s',tobool(mq.TLO.Window('CastingWindow')()),mq.TLO.Window('CastingWindow')())
    mq.delay(200, function() return tobool(mq.TLO.Window('CastingWindow')()) end)
    Write.Trace('Wait window %s %s',tobool(mq.TLO.Window('CastingWindow')()),mq.TLO.Window('CastingWindow')())
    Cast.Events()
    if mq.TLO.Me.BardSongPlaying() then Write.Debug('Returning cause I\'m playing a song') return end
    while tobool(mq.TLO.Window('CastingWindow')()) do
        mq.delay(1)
        Cast.Events()
    end
end

function Cast.Spell(spell,isheal)
    mq.cmdf('/cast "%s"',spell)
    Write.Trace('Casting %s on %s',spell,mq.TLO.Target())
    Cast.Wait(isheal)
end

function Cast.Ability(ability)
    mq.cmdf('/doability %s',ability)
end

function Cast.Disc(disc)
    mq.cmdf('/disc %s',disc)
end

function Cast.AA(aa,isheal)--Type 1-6. Don't know what the issue is. Note about 5 for some reason
    mq.cmdf('/alt activate %s',mq.TLO.Me.AltAbility(aa).ID())
    Cast.Wait(isheal)
end

function Cast.Item(item,isheal)
    mq.cmdf('/cast item "%s"',item)
    Cast.Wait(isheal)
end

function Cast.HaveResources(spell,type)
    local haveResources = false
    local haveReagents = true
    local reagentID = mq.TLO.Spell(spell).ReagentID(1)() or -1
    Write.Trace('spell %s type %s reagent %s',spell,type,reagentID)
    if type == "spell" then haveResources = mq.TLO.Spell(spell).Mana()*1.05 < mq.TLO.Me.CurrentMana() 
    elseif type == "disc" then haveResources = mq.TLO.Spell(spell).EnduranceCost() < mq.TLO.Me.Endurance() 
    else haveResources = true end
    if reagentID > -1 then Write.Debug("need a reagent") --Probably need to change spell to account for the spell that is actually cast from AAs/items etc eventually
        if mq.TLO.FindItemCount(reagentID)() >= mq.TLO.Spell(spell).ReagentCount(1)() then
            Write.Debug("I have enough %s to cast %s",mq.TLO.FindItem(reagentID)(),spell)
        else haveReagents = false end
    end
    return haveReagents and haveResources
end

function Cast.CastTheThing(spell,type,isheal)
    if type == 'ability' then Cast.Ability(spell,isheal) elseif
        type == 'spell' then Cast.Spell(spell,isheal) elseif
        type == 'aa' then Cast.AA(spell,isheal) elseif
        type == 'disc' then Cast.Disc(spell,isheal) elseif
        type == 'item' then Cast.Item(spell,isheal)
    end
end

function Cast.HaveSpell(spell,type)
    local haveIt = false
    if type == 'ability' and mq.TLO.Me.Skill(spell)() > 0 then haveIt = true elseif
        type == 'spell' and mq.TLO.Me.Book(spell)()then haveIt = true elseif --Need to account for Rk? Or always strip? Will always stripping cause issues?
        type == 'aa' and mq.TLO.AltAbility(spell)() then haveIt = true elseif
        type == 'disc' and mq.TLO.Me.CombatAbility(spell)() then haveIt = true elseif
        type == 'item' and mq.TLO.FindItem(spell)() then haveIt = true
    end
    return haveIt
end

function Cast.InRange(spell,target,type) --Do I add LoS here? Is there a spell info where I can check if it's required? MyRange?
    local castRange = false
    local maxMelee = mq.TLO.Target.MaxMeleeTo()
    local targetDistance = mq.TLO.Spawn(target).Distance() or 10000
    Write.Trace(spell)
    if mq.TLO.Me.Spell(spell).TargetType() == 'Self' then castRange = true elseif
        type == 'ability' and maxMelee and targetDistance < maxMelee then castRange = true elseif
        type == 'spell' and targetDistance <  mq.TLO.Me.Spell(spell).Range() then castRange = true elseif --Need to account for Rk? Or always strip? Will always stripping cause issues?
        type == 'aa' and targetDistance <  mq.TLO.AltAbility(spell).Range() then castRange = true elseif
        type == 'disc' and targetDistance <  mq.TLO.Me.CombatAbility(mq.TLO.Me.CombatAbility(spell)()).Range() then castRange = true elseif
        type == 'item' and targetDistance <  mq.TLO.FindItem(spell).Range() then castRange = true
    end
    Write.Trace('CastRange %s',castRange)
    return castRange
end

function Cast.CanCast() --Not stunned silenced etc
    return not mq.TLO.Me.Stunned() and not mq.TLO.Me.Silenced() and not mq.TLO.Me.Feigning()
end
--Need to implement a return on how long the cast lockout is so the caller can call for weaves? Gotta figure out weaving in general
--Figure out how to handle spells I have but aren't memmed. Just combat? Have it as a setting for combat?
function Cast.Cast(spell,targ,type,weave,buff,heal)--Target is either an id,charname,enemy,self,tank
    local count = 0
    local cast_result = "fail"
    DidNotStick = false
    if not type then type = 'spell' end
    type = type:lower()
    Write.Debug('spell %s target %s type %s',spell,targ,type)
    if not Cast.HaveSpell(spell,type) then cast_result = "unknown" else
        type = Cast.Type(type)
        target = Cast.Target(targ) --spawn ID of your target
        readyToCast,cooldownTimer = Cast.IsReady(spell,type)
        if not readyToCast and cooldownTimer == 0 then Write.Debug('delaying 1.5s for non-weave global cooldown',cooldoownTimer) mq.delay(1600, function () return Cast.IsReady(spell,type) == true end) end --Wait for the global cooldown of 1.5s
        if cooldownTimer > 0 and not weave and cooldownTimer < 2 then Write.Debug('delaying %ss for non-weave spell cooldown',cooldoownTimer) mq.delay(cooldownTimer..'s') end
        readyToCast,cooldownTimer = Cast.IsReady(spell,type)
        if readyToCast and Cast.CanCast() and Cast.InRange(spell,target,type) then
            Write.Trace('ready %s cooldownTimer %s',readyToCast,cooldownTimer)
            if Cast.HaveResources(spell,type) then
                Write.Trace('I have the resources')
                if mq.TLO.Target.ID() ~= target then DoTarget(target) end
                if shortName ~= "BRD" then PauseMovement() end
                if not mq.TLO.Me.Standing() then mq.cmd('/stand') end
                Write.Info('Casting %s on ',spell,target)
                Cast.CastTheThing(spell,type,heal)
                mq.doevents('fizzle')
                while fizzled and count <= 3 do
                    Write.Debug('Recasting due to fizzle attempt %s out of 3',count)
                    mq.flushevents('fizzle')
                    Write.Info('Casting \ag%s',spell)
                    Cast.CastTheThing(spell,type,heal)
                    count = count +1
                end
                if buff then mq.delay(1000, function () return DidNotStick end) end --Buff delay for the server to send back info
                mq.doevents('didnotstick') --Not caught cause of server delay
                if DidNotStick then cast_result = 'blocked' else cast_result = 'success' end
                fizzled = false
                mq.flushevents('didnotstick')
                ResumeMovement()
            end
        else Write.Trace("%s isn't ready or global cooldown is active",spell) cast_result = 'not ready' end
    end
    Write.Trace('Returning from Cast.Cast with %s',cast_result)
    return cast_result
end

function Cast.IsReady(spell,type)
    local castready
    local ready
    local castreadytime
    if not type then type = 'spell' end
    Write.Debug('Cast.IsReady spell %s type %s',spell,type)
    type = type:lower()
    ready = (mq.TLO.Navigation.Velocity() < 1 or shortName == "BRD") --eventually account for things bards can't cast while moving
    if type == "spell" then
        castready = mq.TLO.Me.SpellReady(spell)()
        castreadytime = mq.TLO.Me.GemTimer(spell)() or 10
    elseif type == 'disc' then
        castready = mq.TLO.Me.CombatAbilityReady(spell)()
        castreadytime = mq.TLO.Me.CombatAbilityTimer(spell)() or 10
    elseif type == 'ability' then
        castready = mq.TLO.Me.AbilityReady(spell)()
        castreadytime = mq.TLO.Me.AbilityTimer(spell)() or 10
    elseif type == 'aa' then
        castready = mq.TLO.Me.AltAbilityReady(spell)()
        castreadytime = mq.TLO.Me.AltAbilityTimer(spell)() or 10
    elseif type == 'item' then
        castready = mq.TLO.Me.ItemReady(spell)()
        castreadytime = mq.TLO.FindItem(spell).Timer() or 10
    end
    Write.Debug('castready %s ready %s time %s',castready, ready, castreadytime)
    return castready and ready, tonumber(castreadytime)
end

function Cast.MemSpell(spellname, slot)
    if not slot then else
        Write.Debug('/memspell %s %s',slot,spellname)
        mq.cmdf('/memspell %s "%s"',slot,spellname)
        mq.delay(10000, function () return mq.TLO.Window('SpellBookWnd').Open() end)
        mq.delay(25000, function () return not mq.TLO.Window('SpellBookWnd').Open() end)    
    end
end

function Cast.FindOpenSlot()
    for i=1,mq.TLO.Me.NumGems() do
        if mq.TLO.Me.Gem(i)() then
            --Not empty
        else
            return i
        end
    end
    return false
end

function Cast.HasSPA(spa) --Returns the first memmed spell with a matching SPA https://docs.macroquest.org/reference/general/spa-list/?h=spa
    local result = false
    for i=1, mq.TLO.Me.NumGems() do
        --Write.Debug('spa %s gem %s has %s',spa,i,mq.TLO.Me.Gem(i).HasSPA(spa)())
        if mq.TLO.Me.Gem(i).HasSPA(spa)() then
            result = mq.TLO.Me.Gem(i)()
            break
        end
    end
    return result
end

function Cast.HasSpell(spell,target) --Does target have the spell on them
    local hasSpell = false
    local remainingTime = 0
    --printTable(client.data[target].CurrentBuffs)
    Write.Trace('Has spell %s %s %s', spell, target, mq.TLO.Spawn(target).Buff(spell)())
    if mq.TLO.Spawn(target).Buff(spell)() then
        hasSpell = true
        remainingTime = mq.TLO.Spawn(target).Buff(spell).Duration()/1000 --450,000 = 450seconds. Return 450seconds
    else
        if target and client.data[target] and client.data[target].CurrentBuffs then
            for buffname, buffdata in pairs(client.data[target].CurrentBuffs) do
                if buffname == spell then
                    hasSpell = true
                    remainingTime = buffdata.duration
                end
            end
        end
    end
    Write.Trace('HasSpell %s time %s',hasSpell,remainingTime)
    return hasSpell,remainingTime
end

function Event_CastFizzle(line, ...)
    if not fizzled then
        local arg = {...}
        Write.Debug('I fizzed \ar%s',arg[1])
        fizzled = true
    end
end

mq.event('fizzle', 'Your #1# spell fizzles!', Event_CastFizzle)

function Event_CastDidNotStick(line, ...)
    DidNotStick = true
    Write.Debug('Spell Didnt stick')
end
mq.event('didnotstick', '#*#did not take hold on#*#', Event_CastDidNotStick)

function DoTarget(id)
    if not mq.TLO.Spawn(id).ID() then return "NOTARGET" else
        while mq.TLO.Target.ID() ~= id and mq.TLO.Spawn(id)() do --Got stuck here dying mid combat
            Write.Trace('Targeting %s',id)
            mq.cmdf("/target id %s",id)
            mq.delay(1000, function() return mq.TLO.Target.ID() == id end) --Do I want to loop a couple of times? Would do goto or a timer with while
        end
    end
end

function PauseMovement()
    if mq.TLO.Navigation.Active() then mq.cmd('/nav pause') end
    mq.cmd('/stick pause')
end

function ResumeMovement()
    if mq.TLO.Navigation.Paused() then mq.cmd('/nav pause') end
    mq.cmd('/stick unpause')
end

function tobool(str)
    local bool = false
    if str:lower() == "true" then
        bool = true
    end
    return bool
end

return Cast