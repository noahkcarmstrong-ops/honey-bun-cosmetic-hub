-- Adds local catalog pages beside MM2's original Game Emotes pages.
return function(playerGui,catalog,onStatus,gameObject)
    local api,enabled,dead={},false,false
    local bar,pagesRoot,header,caption,template
    local originals,owned,links,controls={},{},{},{}
    local index,entries,nativeCount=1,{},0
    local last="Waiting for the Game Emotes bar."
    local cas=gameObject:GetService("ContextActionService")
    local input=gameObject:GetService("UserInputService")
    local run=gameObject:GetService("RunService")
    local function read(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
    local function is(o,c)local ok,v=pcall(function()return o:IsA(c)end);return ok and v end
    local function kids(o)return o and o:GetChildren() or {} end
    local function desc(o)return o and o:GetDescendants() or {} end
    local function child(o,n)return o and o:FindFirstChild(n) end
    local function find(o,n)for _,v in ipairs(desc(o))do if v.Name==n then return v end end end
    local function ours(o)while o and o~=playerGui do if tostring(o.Name):sub(1,14)=="HoneyBunLocal_" then return true end;o=o.Parent end;return false end
    local function visible(o)while o and o~=playerGui do if read(o,"Visible")==false or read(o,"Enabled")==false then return false end;o=o.Parent end;return o==playerGui end
    local function status(s)last=s;if onStatus then pcall(onStatus,s)end end
    local function disconnect(list)for _,v in ipairs(list)do v:Disconnect()end end
    local function strip(o)for _,v in ipairs(desc(o))do if is(v,"LuaSourceContainer") then v:Destroy()end end end
    local function play(entry)
        local ok,result=pcall(catalog.preview,entry.id,"Emote")
        status(ok and (result or "Playing "..entry.name) or "Could not play: "..tostring(result))
    end
    local function selected()
        return bar and visible(bar) and header and tostring(header.Text):match("^Game Emotes")~=nil
    end
    local function total()return nativeCount+math.ceil(#entries/8)end
    local function paint()
        if not pagesRoot then return end
        local active=selected()
        for i,v in ipairs(originals)do v.object.Visible=active and index==i or (not active and false)end
        for i,v in ipairs(owned)do v.Visible=active and index==nativeCount+i end
        if caption then caption.Visible=active;caption.Text="Game Emotes ("..index.."/"..total()..")" end
        if header then header.TextTransparency=active and 1 or template.headerTransparency end
        for _,v in ipairs(controls)do v.Visible=active end
    end
    local function change(delta)index=(index-1+delta)%math.max(1,total())+1;paint()end
    local function reset()
        disconnect(links);links={}
        local active=header and tostring(header.Text):match("^Game Emotes")~=nil
        local restoreIndex=math.min(index,nativeCount)
        for i,v in ipairs(originals)do pcall(function()v.object.Visible=active and i==restoreIndex or false end)end
        for _,v in ipairs(owned)do v:Destroy()end
        for _,v in ipairs(controls)do v:Destroy()end
        if caption then caption:Destroy()end
        if header and template then pcall(function()header.TextTransparency=template.headerTransparency end)end
        originals,owned,controls={},{},{};bar,pagesRoot,header,caption,template=nil,nil,nil,nil,nil
    end
    local function sourceCard(page)
        local box=child(page,"Container") or page
        for _,v in ipairs(kids(box))do if is(v,"GuiObject") and find(v,"EmoteName") and find(v,"Button") then return v end end
    end
    local function navButton(key,delta)
        for _,label in ipairs(desc(bar))do
            if not ours(label) and (is(label,"TextLabel") or is(label,"TextButton")) and tostring(label.Text):gsub("%s","")==key then
                local target=label
                local ancestor=label
                while ancestor and ancestor~=bar do
                    if is(ancestor,"GuiButton") then target=ancestor;break end
                    ancestor=ancestor.Parent
                end
                if target==label and not is(label,"GuiButton") and is(label.Parent,"GuiObject") then target=label.Parent end
                if not is(target,"GuiObject") then return end
                local button=Instance.new("TextButton");button.Name="HoneyBunLocal_Emote"..key
                button.Text="";button.BackgroundTransparency=1;button.Size=target.Size;button.Position=target.Position;button.AnchorPoint=target.AnchorPoint
                button.ZIndex=(read(target,"ZIndex") or 1)+10;button.Parent=target.Parent
                links[#links+1]=button.Activated:Connect(function()change(delta)end);controls[#controls+1]=button
                return
            end
        end
    end
    local function mount()
        local cp=child(playerGui,"CrossPlatform");local b=child(cp,"Emotes");local body=child(b,"_")
        local ep=child(body,"EmotePages")
        if not ep then return false end
        local h
        for _,v in ipairs(desc(body))do
            if not ours(v) and (is(v,"TextLabel") or is(v,"TextButton")) then
                local text=tostring(read(v,"Text") or "")
                if text:match("^Game Emotes") or text:match("^Your Emotes") or text:match("^Default Emotes") or text:match("^Avatar Emotes") then
                    local ancestor=v.Parent;local inside=false
                    while ancestor and ancestor~=body do if ancestor==ep then inside=true;break end;ancestor=ancestor.Parent end
                    if not inside then h=v;break end
                end
            end
        end
        if not h then return false end
        local sources={};local card
        for _,v in ipairs(kids(ep))do if not ours(v) and tostring(v.Name):match("^Game Emotes") then sources[#sources+1]=v;card=card or sourceCard(v)end end
        table.sort(sources,function(a,b)return (tonumber(a.Name:match("%((%d+)")) or 1)<(tonumber(b.Name:match("%((%d+)")) or 1)end)
        if #sources==0 or not card then return false end
        bar,pagesRoot,header=b,ep,h;nativeCount=#sources;index=1
        template={headerTransparency=h.TextTransparency or 0}
        for _,v in ipairs(sources)do originals[#originals+1]={object=v,visible=v.Visible}end
        caption=header:Clone();caption.Name="HoneyBunLocal_EmotePageTitle";strip(caption)
        caption.TextTransparency=0;caption.Active=false;caption.Parent=header.Parent
        pcall(function()caption.Interactable=false end)
        for p=1,math.ceil(#entries/8)do
            local page=sources[1]:Clone();page.Name="HoneyBunLocal_EmotePage_"..p;strip(page)
            local box=child(page,"Container") or page
            for _,v in ipairs(kids(box))do if is(v,"GuiObject") then v:Destroy()end end
            if not box:FindFirstChildOfClass("UIListLayout") and not box:FindFirstChildOfClass("UIGridLayout") then
                local layout=Instance.new("UIListLayout");layout.FillDirection=Enum.FillDirection.Horizontal
                layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.VerticalAlignment=Enum.VerticalAlignment.Center
                layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Padding=UDim.new(0,4);layout.Parent=box
            end
            for i=(p-1)*8+1,math.min(p*8,#entries)do
                local entry=entries[i];local c=card:Clone();strip(c);c.Name="HoneyBunLocal_EmoteCard_"..entry.id;c.LayoutOrder=(i-1)%8+1;c.Visible=true
                local name=find(c,"EmoteName");name.Text=entry.name
                local icon=find(c,"Icon");local image=entry.image or "";if type(image)=="number" or tostring(image):match("^%d+$") then image="rbxassetid://"..image end
                if icon then icon.Image=image end
                local hotkey=find(c,"Hotkey");if hotkey and is(hotkey,"TextLabel") then hotkey.Text=tostring((i-1)%8+1)end
                local button=find(c,"Button");links[#links+1]=button.Activated:Connect(function()play(entry)end)
                c.Parent=box
            end
            page.Visible=false;page.Parent=ep;owned[#owned+1]=page
        end
        navButton("Q",-1);navButton("E",1)
        paint();status("Game Emotes bar: "..#entries.." catalog emotes across "..total().." pages.")
        return true
    end
    local keyNumbers={One=1,Two=2,Three=3,Four=4,Five=5,Six=6,Seven=7,Eight=8}
    local function keyAction(_,state,event)
        if not enabled or not selected() or (input and input:GetFocusedTextBox()) then return Enum.ContextActionResult.Pass end
        local key=event.KeyCode.Name
        local number=keyNumbers[key]
        if key~="Q" and key~="E" and (not number or index<=nativeCount) then return Enum.ContextActionResult.Pass end
        if state==Enum.UserInputState.Begin then
            if key=="Q" then change(-1)elseif key=="E" then change(1)
            else local entry=entries[(index-nativeCount-1)*8+number];if entry then play(entry)end end
        end
        return Enum.ContextActionResult.Sink
    end
    local heartbeat;local elapsed=0
    function api.enable()
        assert(not dead,"Emote bar is closed.")
        if enabled then return true,last end
        entries=catalog.list("Emote");enabled=true
        cas:BindActionAtPriority("LarpbloxMM2Emotes",keyAction,false,3000,Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,Enum.KeyCode.Seven,Enum.KeyCode.Eight)
        mount()
        heartbeat=run.Heartbeat:Connect(function(dt)
            elapsed=elapsed+dt;if elapsed<0.15 then return end;elapsed=0
            if pagesRoot and (not pagesRoot:IsDescendantOf(playerGui) or not header:IsDescendantOf(playerGui)
                or (owned[1] and owned[1].Parent~=pagesRoot) or (originals[1] and originals[1].object.Parent~=pagesRoot)) then reset()end
            if not pagesRoot then mount()else paint()end
        end)
        return true,last
    end
    function api.disable()
        enabled=false;if heartbeat then heartbeat:Disconnect();heartbeat=nil end
        cas:UnbindAction("LarpbloxMM2Emotes");reset();last="Original Game Emotes bar restored."
    end
    function api.destroy()api.disable();dead=true end
    function api.report()return last end
    return api
end

