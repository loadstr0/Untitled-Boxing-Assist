-- Untitled Boxing Assist | LumenUI | Real
-- Build for place 13621938427. Live combat validation is pending.
-- Run through Real live-reload with label "ubg-lumen-assist".
if game.PlaceId ~= 13621938427 then error("Open Untitled Boxing Game first.") end
local reloadState = ...
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local random = Random.new()
local LumenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/Loader.lua"))()
local window = LumenUI:Require("Window").new({
    Name = "UBGAssist", Title = "Boxing Assist v3 — Fight Log", Size = UDim2.fromOffset(650, 510),
    ToggleKeybind = Enum.KeyCode.RightControl, AutoSaveConfig = "preset-v3",
})
local cfg = {enabled=true, dodge=true, block=true, box=true, ultimate=false,
    dodgeChance=85, blockChance=100, reaction=40, range=9, interval=400, punchRange=5.5,
    stamina=25, blockFloor=20, hold=350, ultimateThreshold=100, heavyChance=0}
local dead = false
local connection
local held = {}
local blockThread
local blockEnv
local blockUntil=0
local controls=getsenv(player.PlayerScripts:WaitForChild("CustomControls"))
local HttpService=game:GetService("HttpService")
local logPath="UBGAssist/Fights/"..os.time().."-"..HttpService:GenerateGUID(false)..".json"
local fightLog={version=3,started=os.time(),events={}}
local logError
local logDirty=true
local logClock=0
local function record(kind,details)
    table.insert(fightLog.events,{t=os.clock(),kind=kind,data=details})
    if #fightLog.events>10000 then table.remove(fightLog.events,1) end
    logDirty=true
end
local function flushLog()
    if not logDirty then return end
    local ok,err=pcall(function() writefile(logPath,HttpService:JSONEncode(fightLog)) end)
    if ok then logDirty=false;logError=nil else logError=tostring(err) end
end
record("session_start",{settings=table.clone(cfg)})
local pending
local previousOpponent
local lastAttack
local activeAttack
local attackStartedAt=0
local attackWasActive=false
local wasStunned = false
local openingUntil = 0
local openingUsed = true
local nextPunch, nextDodge, nextUltimate = 0, 0, 0
local counts = {attacks=0,dodges=0,blocks=0,punches=0,ultimates=0}
local keys = {Dash="Space",Block="F",Ultimate="Q"}
-- Dash and Block are confirmed names in the game's Keybinds module.
pcall(function()
    local module = game:GetService("ReplicatedStorage"):FindFirstChild("Keybinds")
    local binds = (require :: any)(module)
    for _, name in ipairs({"Dash","Block"}) do
        local key = binds.GetKeybind(name)
        if typeof(key) == "EnumItem" then keys[name] = key.Name end
    end
end)
local function vk(name)
    if name == "Space" then return 32 end
    if #name == 1 then return string.byte(string.upper(name)) end
    return nil
end
local function releaseAll()
    if blockThread then pcall(task.cancel,blockThread);blockThread=nil end
    if blockEnv then pcall(blockEnv.TryUnblock);blockEnv=nil end
    blockUntil=0
    for key in pairs(held) do
        pcall(keyrelease,key)
        held[key] = nil
    end
end
local function beginBlock(now)
    local char=player.Character
    local scriptObject=char and char:FindFirstChild("Block")
    if not scriptObject or blockEnv then return false end
    blockEnv=getsenv(scriptObject)
    if type(blockEnv.TryBlock)~="function" or type(blockEnv.TryUnblock)~="function" then
        blockEnv=nil; record("block_error",{reason="Block entry points unavailable"}); return false
    end
    local current=blockEnv
    blockUntil=now+cfg.hold/1000
    blockThread=task.spawn(function()
        local ok,err=pcall(current.TryBlock)
        if not ok then record("block_error",{reason=tostring(err)}) end
    end)
    return true
end
local function press(name,duration,now)
    local key = vk(name)
    if not key or held[key] then return false end
    keypress(key)
    held[key] = now + duration
    return true
end
local function stop()
    cfg.enabled=false
    pending=nil
    releaseAll()
end
local function cleanup()
    if dead then return end
    dead=true
    stop()
    if connection then connection:Disconnect() end
    record("session_stop",{})
    flushLog()
end
local originalDestroy = window.Destroy
window.Destroy = function(self)
    cleanup()
    return originalDestroy(self)
end
if reloadState and reloadState.onCleanup then
    reloadState.onCleanup(function() window:Destroy() end)
end
local home=window:Tab("home","Overview","activity")
local defense=window:Tab("defense","Defense","shield")
local offense=window:Tab("offense","Offense","swords")
local settings=window:Tab("settings","Controls","settings")
home:Paragraph({Title="Combat preview",Desc="Live combat validation pending. Assists pause while this menu is open. Right Ctrl hides it; F8 stops everything. Movement and aiming remain manual."})
local status=home:Paragraph({Title="Paused",Desc="Enable only the assists you want."})
local master=home:Toggle({Title="Master switch",Value=cfg.enabled,Callback=function(value)
    cfg.enabled=value
    if not value then stop() end
end})
local logStatus=home:Paragraph({Title="Fight recording on",Desc=logPath})
home:Button({Title="Save fight log now",Callback=flushLog})
local function toggle(tab,title,key)
    tab:Toggle({Title=title,Value=cfg[key],Flag=key,Callback=function(value)
        cfg[key]=value
        pending=nil
        releaseAll()
    end})
end
local function slider(tab,title,key,min,max,step)
    tab:Slider({Title=title,Min=min,Max=max,Increment=step,Value=cfg[key],Flag=key,
        Callback=function(value) cfg[key]=value end})
end
toggle(defense,"Dodge assist","dodge")
slider(defense,"Dodge chance (%)","dodgeChance",0,100,1)
toggle(defense,"Block assist (fallback when dodge is not selected)","block")
slider(defense,"Block chance (%)","blockChance",0,100,1)
defense:Slider({Title="Reaction delay (ms)",Min=0,Max=300,Increment=10,Value=cfg.reaction,Flag="reactionV2",
    Callback=function(v) cfg.reaction=v end})
slider(defense,"Block hold (ms)","hold",100,1000,25)
slider(defense,"Minimum block energy (%)","blockFloor",0,100,5)
defense:Paragraph({Title="Chance behavior",Desc="One decision per numeric attack timestamp. Defense is scheduled before the replicated impact time when available. Counts show attempted inputs, not confirmed successful dodges."})
toggle(offense,"Punish openings","box")
slider(offense,"Minimum time between punish attempts (ms)","interval",150,1000,10)
slider(offense,"Punch range (studs)","punchRange",3,9,0.25)
offense:Paragraph({Title="One punch per opening",Desc="Attempt one punish after a detected attack ends or a new opponent stun. No idle timer punches or automatic combo spam. Opponent must be in range, in front, and not blocking. Attack-end recovery is a heuristic, not a guaranteed hit."})
slider(offense,"Heavy punch chance (%)","heavyChance",0,100,1)
toggle(offense,"Auto ultimate","ultimate")
slider(offense,"Ultimate energy threshold","ultimateThreshold",1,200,1)
offense:Paragraph({Title="Ultimate setup",Desc="Confirm your ultimate key and the full meter value before enabling. Q and 100 are editable defaults, not live-verified values."})
slider(settings,"Opponent range (studs)","range",3,15,0.5)
slider(settings,"Minimum stamina (%)","stamina",0,80,5)
local options={"Space","Q","E","R","F","G","Z","X","C","V"}
for _,action in ipairs({"Dash","Block","Ultimate"}) do
    local actionName=action
    local choices=table.clone(options)
    if not table.find(choices,keys[actionName]) then table.insert(choices,keys[actionName]) end
    settings:Dropdown({Title=actionName.." key",Options=choices,Value=keys[actionName],Flag="key"..actionName,
        Callback=function(value) releaseAll(); keys[actionName]=value end})
end
settings:Button({Title="Stop and unload",Icon="power",Callback=function() window:Destroy() end})
home:Keybind({Title="Emergency stop",Value=Enum.KeyCode.F8,Callback=function()
    stop(); master:Set(false)
end})
local function value(folder,name,default)
    local item=folder and folder:FindFirstChild(name)
    if item and item:IsA("ValueBase") then return item.Value end
    return default
end
local function modelOf(opponent)
    if typeof(opponent)=="Instance" then
        if opponent:IsA("Player") then return opponent.Character end
        if opponent:IsA("Model") then return opponent end
        local p=Players:FindFirstChild(opponent.Name)
        if p then return p.Character end
        local live=workspace:FindFirstChild("Live")
        return live and live:FindFirstChild(opponent.Name)
    end
    return nil
end
local function context()
    if not cfg.enabled then return nil,"Master switch off" end
    if window.Visible then return nil,"Menu open — Right Ctrl to resume" end
    if not isrbxactive() or UIS:GetFocusedTextBox() then return nil,"Waiting for game focus" end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local states=workspace:FindFirstChild("States")
    local state=states and states:FindFirstChild(player.Name)
    local data=state and state:FindFirstChild("CharacterData")
    local occupied=state and state:FindFirstChild("Occupied")
    if not hum or hum.Health<=0 or not root or not data or not occupied then return nil,"Waiting for character" end
    if not value(data,"Equipped",false) or value(occupied,"Spectating",false)
        or value(data,"Cutscene",false) or value(data,"InSafezone",true)
        or value(data,"Stunned",false) or value(occupied,"Stunned",false)
        or value(state:FindFirstChild("PlayerData"),"Disable",false) then return nil,"Waiting for active combat" end
    local target=modelOf(value(data,"Opponent",nil))
    local targetRoot=target and target:FindFirstChild("HumanoidRootPart")
    local targetHum=target and target:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHum or targetHum.Health<=0 then return nil,"Waiting for assigned opponent" end
    if (root.Position-targetRoot.Position).Magnitude>cfg.range then return nil,"Opponent outside assist range" end
    local stamina=100*value(data,"Stamina",0)/math.max(1,value(data,"MaxStamina",100))
    if stamina<cfg.stamina then return nil,"Recovering stamina" end
    local opponentState=states:FindFirstChild(target.Name)
    return {char=char,target=target,data=data,occupied=occupied,root=root,targetRoot=targetRoot,
        opponentData=opponentState and opponentState:FindFirstChild("CharacterData")},"Ready"
end
local lastStatus=0
local lastGate
local observedOpponent
local previousSnapshot
local sampleClock=0
local confirmedBlocks,confirmedDashes=0,0
local function observeFight(now)
    if now-sampleClock<0.05 then return end
    sampleClock=now
    local states=workspace:FindFirstChild("States")
    local state=states and states:FindFirstChild(player.Name)
    local data=state and state:FindFirstChild("CharacterData")
    local occupied=state and state:FindFirstChild("Occupied")
    local opponent=modelOf(value(data,"Opponent",nil))
    if opponent~=observedOpponent then
        if observedOpponent then record("fight_end",{opponent=observedOpponent.Name,health=value(data,"Health",0)}) end
        observedOpponent=opponent;previousSnapshot=nil
        if opponent then record("fight_start",{opponent=opponent.Name}) end
    end
    local char=player.Character
    if not char then return end
    local opponentState=opponent and states:FindFirstChild(opponent.Name)
    local otherData=opponentState and opponentState:FindFirstChild("CharacterData")
    local snapshot={opponent=opponent and opponent.Name or "",health=value(data,"Health",0),
        stamina=value(data,"Stamina",0),blockEnergy=value(data,"BlockEnergy",0),
        blocking=value(data,"Blocking",false),localBlocking=value(occupied,"Blocking",false),
        dashing=value(data,"Dashing",false),lastDash=char:GetAttribute("LastDashTime"),
        lastBlocked=char:GetAttribute("LastBlocked"),lastPerfectDodge=char:GetAttribute("LastPerfectDodged"),
        stunned=value(data,"Stunned",false),opponentHealth=value(otherData,"Health",0),
        attack=opponent and opponent:GetAttribute("Punching"),
        opponentStyle=opponentState and value(opponentState:FindFirstChild("PlayerData"),"Style",""),
        outcome=opponent and opponent:GetAttribute("ResolvedAttackOutcome")}
    if previousSnapshot then
        if snapshot.blocking and not previousSnapshot.blocking then confirmedBlocks+=1 end
        if snapshot.lastDash and snapshot.lastDash~=previousSnapshot.lastDash then confirmedDashes+=1 end
    end
    local changed=not previousSnapshot
    if previousSnapshot then
        for k,v in pairs(snapshot) do if previousSnapshot[k]~=v then changed=true;break end end
        for k,v in pairs(previousSnapshot) do if snapshot[k]~=v then changed=true;break end end
    end
    if changed then record("state",snapshot);previousSnapshot=snapshot end
    if now-logClock>=5 then logClock=now;flushLog() end
end
local function tickAssist()
    local now=os.clock()
    observeFight(now)
    if blockEnv and now>=blockUntil then releaseAll() end
    for key,untilTime in pairs(held) do
        if now>=untilTime then keyrelease(key); held[key]=nil end
    end
    local ctx,message=context()
    if message~=lastGate then record("assist_gate",{reason=message});lastGate=message end
    if now-lastStatus>0.35 then
        lastStatus=now
        status:SetTitle(message)
        status:SetDesc(string.format("Detected %d | Dodge inputs %d | Blocks %d | Punches %d | Ultimates %d",
            counts.attacks,counts.dodges,counts.blocks,counts.punches,counts.ultimates))
        logStatus:SetTitle(logError and "Fight log save error" or "Fight recording on")
        logStatus:SetDesc(logError or string.format("Server block starts: %d | Observed dashes: %d\n%s",confirmedBlocks,confirmedDashes,logPath))
    end
    if not ctx then
        pending=nil; previousOpponent=nil; lastAttack=nil; activeAttack=nil
        attackWasActive=false; wasStunned=false; openingUntil=0; openingUsed=true; releaseAll()
        return
    end
    local attack=ctx.target:GetAttribute("Punching")
    local punching=attack~=nil and attack~=false
    local stunned=value(ctx.opponentData,"Stunned",false)
    if previousOpponent~=ctx.target then
        previousOpponent=ctx.target; lastAttack=nil; activeAttack=nil; pending=nil
        attackWasActive=false; wasStunned=stunned; openingUntil=0; openingUsed=true
    end
    if punching and attack~=lastAttack then
        lastAttack=attack; activeAttack=attack; attackStartedAt=now; openingUntil=0; openingUsed=true
        counts.attacks+=1
        record("attack_detected",{opponent=ctx.target.Name,id=attack,distance=(ctx.root.Position-ctx.targetRoot.Position).Magnitude})
        local action
        if cfg.dodge and random:NextNumber(0,100)<cfg.dodgeChance then action="Dash"
        elseif cfg.block and random:NextNumber(0,100)<cfg.blockChance then action="Block" end
        record("defense_choice",{attack=attack,action=action or "Skip"})
        if action then
            local delay=cfg.reaction/1000
            local impact=ctx.target:GetAttribute("PreviousLandTime")
            if type(impact)=="number" then
                -- Use a duration between server timestamps; local tick() has a different clock.
                local remaining=type(attack)=="number" and impact-attack or 0
                if remaining>0 and remaining<2 then delay=math.min(delay,math.max(0,remaining-0.10)) end
            end
            pending={action=action,at=now+delay,expires=now+0.35,target=ctx.target,attack=attack}
        end
    end
    if attackWasActive and not punching and activeAttack and now-attackStartedAt>=0.18 then
        openingUntil=now+0.25; openingUsed=false
    end
    attackWasActive=punching
    if stunned and not wasStunned then openingUntil=now+0.35; openingUsed=false end
    wasStunned=stunned
    if pending and now>=pending.at then
        local decision=pending
        if now>decision.expires or not punching or attack~=decision.attack then
            record("defense_expired",{action=decision.action,ownPunching=value(ctx.occupied,"Punching",false),ownDash=value(ctx.data,"Dashing",false)})
            pending=nil
        elseif decision.target==ctx.target and not value(ctx.occupied,"Punching",false)
            and not value(ctx.data,"Dashing",false) then
            if decision.action=="Dash" and now>=nextDodge then
                releaseAll()
                local ok,err=pcall(controls.TryDash)
                record("dash_attempt",{ok=ok,error=not ok and tostring(err) or nil})
                if ok then counts.dodges+=1; nextDodge=now+0.6; pending=nil end
            elseif decision.action=="Block" and value(ctx.occupied,"CanBlock",false) then
                local energy=100*value(ctx.data,"BlockEnergy",0)/math.max(1,value(ctx.data,"MaxBlockEnergy",50))
                if energy>=cfg.blockFloor and beginBlock(now) then
                    record("block_attempt",{attack=attack,energy=energy})
                    counts.blocks+=1;pending=nil
                end
            end
        end
    end
    if blockEnv or next(held) or pending or value(ctx.data,"Blocking",false) or value(ctx.occupied,"Punching",false)
        or value(ctx.data,"Dashing",false) then return end
    local delta=ctx.targetRoot.Position-ctx.root.Position
    local facing=delta.Magnitude>0.01 and ctx.root.CFrame.LookVector:Dot(delta.Unit)>0.5
    local opening=not openingUsed and now<=openingUntil and not punching
        and not value(ctx.opponentData,"Blocking",false) and not value(ctx.opponentData,"Dashing",false)
        and facing and delta.Magnitude<=cfg.punchRange
    if cfg.ultimate and opening and now>=nextUltimate and value(ctx.data,"UltimateEnergy",0)>=cfg.ultimateThreshold then
        if press(keys.Ultimate,0.08,now) then counts.ultimates+=1; nextUltimate=now+2; openingUsed=true end
        return
    end
    if cfg.box and opening and now>=nextPunch and value(ctx.occupied,"CanPunch",false) then
        if random:NextNumber(0,100)<cfg.heavyChance then mouse2click() else mouse1click() end
        counts.punches+=1
        record("punish_attempt",{opponent=ctx.target.Name,range=delta.Magnitude})
        openingUsed=true
        nextPunch=now+cfg.interval/1000
    end
end
pcall(function() window:LoadConfig("preset-v3") end)
cfg.enabled=true
master:Set(true)
window:SaveConfig("preset-v3")
window:SetVisible(false)
flushLog()
connection=RunService.Heartbeat:Connect(function()
    if dead then return end
    local ok,err=pcall(tickAssist)
    if not ok then
        stop();master:Set(false)
        status:SetTitle("Paused after error")
        status:SetDesc(tostring(err))
        warn("Boxing Assist: "..tostring(err))
    end
end)

