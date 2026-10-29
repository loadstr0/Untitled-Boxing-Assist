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
    Name = "UBGAssist", Title = "Boxing Assist", Size = UDim2.fromOffset(650, 510),
    ToggleKeybind = Enum.KeyCode.RightControl, AutoSaveConfig = "settings",
})
local cfg = {enabled=false, dodge=false, block=false, box=false, ultimate=false,
    dodgeChance=65, blockChance=80, reaction=140, range=9, interval=360,
    stamina=25, blockFloor=20, hold=350, ultimateThreshold=100, heavyChance=0}
local dead = false
local connection
local held = {}
local pending
local previousOpponent
local wasPunching = false
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
    for key in pairs(held) do
        pcall(keyrelease,key)
        held[key] = nil
    end
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
local master=home:Toggle({Title="Master switch",Value=false,Callback=function(value)
    cfg.enabled=value
    if not value then stop() end
end})
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
slider(defense,"Reaction delay (ms)","reaction",0,500,10)
slider(defense,"Block hold (ms)","hold",100,1000,25)
slider(defense,"Minimum block energy (%)","blockFloor",0,100,5)
defense:Paragraph({Title="Chance behavior",Desc="One random decision per observed Punching transition. Missed attacks are not rerolled every frame. Detection depends on the opponent's replicated Punching attribute; multi-hit moves may count as one attack."})
toggle(offense,"Auto boxing","box")
slider(offense,"Punch interval (ms)","interval",150,1000,10)
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
    return {char=char,target=target,data=data,occupied=occupied},"Ready"
end
local lastStatus=0
local function tickAssist()
    local now=os.clock()
    for key,untilTime in pairs(held) do
        if now>=untilTime then keyrelease(key); held[key]=nil end
    end
    local ctx,message=context()
    if now-lastStatus>0.35 then
        lastStatus=now
        status:SetTitle(message)
        status:SetDesc(string.format("Detected %d | Dodge inputs %d | Blocks %d | Punches %d | Ultimates %d",
            counts.attacks,counts.dodges,counts.blocks,counts.punches,counts.ultimates))
    end
    if not ctx then
        pending=nil; previousOpponent=nil; wasPunching=false; releaseAll()
        return
    end
    local punching=ctx.target:GetAttribute("Punching")==true
    if previousOpponent~=ctx.target then
        previousOpponent=ctx.target; wasPunching=punching; pending=nil
    elseif punching and not wasPunching then
        counts.attacks+=1
        local action
        if cfg.dodge and random:NextNumber(0,100)<cfg.dodgeChance then action="Dash"
        elseif cfg.block and random:NextNumber(0,100)<cfg.blockChance then action="Block" end
        if action then pending={action=action,at=now+cfg.reaction/1000,target=ctx.target} end
    end
    wasPunching=punching
    if pending and now>=pending.at then
        local decision=pending
        pending=nil
        if decision.target==ctx.target and punching and not value(ctx.occupied,"Punching",false)
            and not value(ctx.data,"Dashing",false) then
            if decision.action=="Dash" and now>=nextDodge then
                releaseAll()
                if press(keys.Dash,0.07,now) then counts.dodges+=1; nextDodge=now+0.6 end
            elseif decision.action=="Block" and value(ctx.occupied,"CanBlock",false) then
                local energy=100*value(ctx.data,"BlockEnergy",0)/math.max(1,value(ctx.data,"MaxBlockEnergy",50))
                if energy>=cfg.blockFloor and press(keys.Block,cfg.hold/1000,now) then counts.blocks+=1 end
            end
        end
    end
    if next(held) or pending or value(ctx.data,"Blocking",false) or value(ctx.occupied,"Punching",false)
        or value(ctx.data,"Dashing",false) then return end
    if cfg.ultimate and now>=nextUltimate and value(ctx.data,"UltimateEnergy",0)>=cfg.ultimateThreshold then
        if press(keys.Ultimate,0.08,now) then counts.ultimates+=1; nextUltimate=now+2 end
        return
    end
    if cfg.box and now>=nextPunch and value(ctx.occupied,"CanPunch",false) and not punching then
        if random:NextNumber(0,100)<cfg.heavyChance then mouse2click() else mouse1click() end
        counts.punches+=1
        nextPunch=now+cfg.interval/1000
    end
end
pcall(function() window:LoadConfig("settings") end)
cfg.enabled=false
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

