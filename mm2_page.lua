-- MM2's page uses the shared editor controls and the existing weapon controllers.
return function(ui)
    local React,e=ui.React,ui.e
    return function(props)
        local selected,setSelected=React.useState(props.player or "")
        local kinds,setKinds=React.useState({Gun=true,Knife=true,Effect=true})
        local crosshair,setCrosshair=React.useState(props.crosshair or "")
        local changing,setChanging=React.useState(false)
        local query,setQuery=React.useState("")
        local weaponName,setWeaponName=React.useState("")
        local rename,setRename=React.useState(nil)
        local draft,setDraft=React.useState("")
        local removing,setRemoving=React.useState(nil)
        local menu,setMenu=React.useState(nil)
        local players,setPlayers=React.useState({})
        local saved,setSaved=React.useState(props.saved or {})
        local loadError,setLoadError=React.useState("")
        React.useEffect(function()setSaved(props.saved or {})end,{props.saved})
        React.useEffect(function()
            local active=true
            task.spawn(function()
                local ok,items=pcall(props.loadSaved)
                if active then if ok then setSaved(items)else setLoadError(tostring(items))end end
            end)
            return function()active=false end
        end,{})
        React.useEffect(function()
            local service=game:GetService("Players")
            local function refresh()
                local result={}
                for _,player in ipairs(service:GetPlayers())do result[#result+1]={value=player.Name,label=player.DisplayName==player.Name and player.Name or player.DisplayName.." (@"..player.Name..")"}end
                table.sort(result,function(a,b)return a.label:lower()<b.label:lower()end)
                setPlayers(result)
            end
            refresh()
            local added=service.PlayerAdded:Connect(refresh);local removed=service.PlayerRemoving:Connect(refresh)
            return function()added:Disconnect();removed:Disconnect()end
        end,{})
        local function button(label,callback,order,extra)
            local p=extra or {};p.label=label;p.onPress=callback;p.layoutOrder=order;p.disabled=props.busy or p.disabled
            return e(ui.Button,p)
        end
        local checks={Layout=e("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})}
        for index,kind in ipairs({"Gun","Knife","Effect"})do checks[kind]=button((kinds[kind]and "✓ "or "+ ")..kind,function()local nextKinds=table.clone(kinds);nextKinds[kind]=not nextKinds[kind];setKinds(nextKinds)end,index,{selected=kinds[kind],width=UDim.new(1/3,-7),height=34})end
        local left={
            Capture=e(ui.Section,{title="Save a look",open=true,layoutOrder=1,children={
                Player=e(ui.SelectRow,{name="MM2Player",label="Player",placeholder="Choose a player",options=players,value=selected,onChange=setSelected,disabled=props.busy,layoutOrder=1}),
                Types=e("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,34),LayoutOrder=2},checks),
                Hint=e(ui.Text,{text="Save while they hold the weapon to capture its appearance and sounds.",height=40,layoutOrder=3}),
                Save=button("Save selected",function()props.capture(selected,kinds)end,4,{selected=true,disabled=selected==""or not(kinds.Gun or kinds.Knife or kinds.Effect)}),
            }}),
        }
        local right={}
        local crosshairNodes={
            Preview=e("Frame",{Size=UDim2.new(1,0,0,96),BackgroundColor3=ui.colors.button,BorderSizePixel=0},{
                Image=e("ImageLabel",{Name="CrosshairPreview",BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(72,72),Image=props.crosshair,ScaleType=Enum.ScaleType.Fit}),
                Empty=props.crosshair==""and e(ui.Text,{text="Default crosshair",height=96,align=Enum.TextXAlignment.Center})or nil,
            }),
            Actions=e("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,LayoutOrder=1},{
                Change=button(changing and "Cancel"or "Change",function()setChanging(not changing)end,1,{width=UDim.new(0.5,-6),height=34}),
                Reset=button("Reset",props.resetCrosshair,2,{width=UDim.new(0.5,-6),height=34,position=UDim2.new(0.5,6,0,0)}),
            }),
            Size=e(ui.NumberField,{label="Size",value=props.crosshairSize,min=8,max=200,step=1,layoutOrder=4,onChange=props.resizeCrosshair,onCommit=props.persist,disabled=props.busy}),
        }
        if changing then
            crosshairNodes.Input=e(ui.Input,{placeholder="Image or decal link / ID",value=crosshair,onChange=setCrosshair,layoutOrder=2,disabled=props.busy})
            crosshairNodes.Apply=button("Apply",function()props.applyCrosshair(crosshair)end,3,{selected=true})
        end
        right.Crosshair=e(ui.Section,{title="Crosshair",open=true,layoutOrder=1,children=crosshairNodes})
        right.Options=e(ui.Section,{title="Options",open=true,layoutOrder=2,children={
            Knife=e("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,38),LayoutOrder=1},{
                Label=e(ui.Text,{text="Knife position",width=112,height=38,color=ui.colors.ink}),
                Back=button("Back",function()props.setKnifeSide(false)end,1,{selected=not props.knifeSide,width=UDim.new(0.5,-62),height=34,position=UDim2.fromOffset(116,2)}),
                Side=button("Side",function()props.setKnifeSide(true)end,2,{selected=props.knifeSide,width=UDim.new(0.5,-62),height=34,position=UDim2.new(0.5,62,0,2)}),
            }),
            Weapons=e(ui.ToggleField,{label="Show all weapons",value=props.allWeapons,onChange=props.toggleWeapons,disabled=props.busy,layoutOrder=2}),
            Emotes=e(ui.ToggleField,{label="Show MM2 emotes",value=props.emotes,onChange=props.toggleEmotes,disabled=props.busy,layoutOrder=3}),
        }})
        right.More=e(ui.Section,{title="More options",open=false,layoutOrder=3,children={
            Refresh=button("Refresh saved weapons",props.refreshWeapons,1),
            Restore=button("Remove saved weapon appearances",props.restoreWeapons,2),
            Input=e(ui.Input,{placeholder="Original weapon name or item ID",value=weaponName,onChange=setWeaponName,layoutOrder=3,disabled=props.busy}),
            Knife=button("Match equipped knife",function()props.identify(weaponName,"Knife")end,4),
            Gun=button("Match equipped gun",function()props.identify(weaponName,"Gun")end,5),
            Effects=button("Refresh saved effects",props.refreshEffects,6),
            Collect=button("Collect server effects",function()props.collectEffects(selected)end,7),
            Stop=button("Stop emote",props.stopEmote,8),
            Report=button("Copy MM2 report",props.report,9),
        }})
        local cards={Layout=e("UIGridLayout",{CellSize=UDim2.new(0.5,-6,0,150),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder})}
        local count=0
        for _,entry in ipairs(saved)do
            if entry.name:lower():find(query:lower(),1,true)then
                count=count+1
                local image=entry.image
                if type(image)=="number"or type(image)=="string"and image:match("^%d+$")then image="rbxassetid://"..tostring(image)end
                local nodes={
                    Equip=e(ui.Button,{name="EquipSaved_"..entry.id,label="",width=UDim.new(1,0),height=150,disabled=props.busy,onPress=function()props.equip(entry)end,children={
                        Image=e("ImageLabel",{BackgroundTransparency=1,Image=type(image)=="string"and image or "",Size=UDim2.new(1,-20,0,102),Position=UDim2.fromOffset(10,6),ScaleType=Enum.ScaleType.Fit}),
                        Name=e(ui.Text,{text=entry.name,height=26,width=UDim.new(1,-16),position=UDim2.new(0,8,1,-40),color=ui.colors.ink,truncate=true}),
                        Kind=e(ui.Text,{text=entry.kind,height=18,width=UDim.new(1,-16),position=UDim2.new(0,8,1,-18),size=12}),
                    }}),
                    Menu=button("⋯",function()setMenu(menu~=entry.id and entry.id or nil);setRemoving(nil)end,2,{name="SavedOptions_"..entry.id,width=28,height=28,position=UDim2.new(1,-32,0,4)}),
                }
                if menu==entry.id then
                    nodes.Options=e("Frame",{Size=UDim2.new(1,-12,0,84),Position=UDim2.fromOffset(6,34),BackgroundColor3=ui.colors.paper,BorderSizePixel=0,ZIndex=5},{
                        Rename=button("Rename",function()setRename(entry);setDraft(entry.name);setMenu(nil)end,1,{height=34,width=UDim.new(1,0),zIndex=6}),
                        Remove=button(removing==entry.id and "Confirm delete"or "Delete",function()if removing==entry.id then props.remove(entry);setMenu(nil)else setRemoving(entry.id)end end,2,{height=34,width=UDim.new(1,0),position=UDim2.fromOffset(0,44),zIndex=6}),
                    })
                end
                cards[entry.id]=e("Frame",{BackgroundTransparency=1,LayoutOrder=count},nodes)
            end
        end
        local savedNodes={Search=e(ui.Input,{value=query,onChange=setQuery,placeholder="Search saved weapons",layoutOrder=1}),
            Grid=e("Frame",{Size=UDim2.new(1,0,0,math.ceil(count/2)*162),BackgroundTransparency=1,LayoutOrder=3},cards)}
        if count==0 then savedNodes.Empty=e(ui.Text,{text=loadError~=""and loadError or "No saved weapons yet.",height=36,layoutOrder=2})end
        if rename then savedNodes.Rename=e(ui.EntryRow,{value=draft,onChange=setDraft,placeholder="Weapon name",action="Rename",layoutOrder=2,onApply=function()props.rename(rename,draft);setRename(nil)end})end
        left.Saved=e(ui.Section,{title="Saved weapons",layoutOrder=2,open=true,children=savedNodes})
        return e(ui.Stack,{name="MM2Page",layoutOrder=props.layoutOrder,gap=14,children={
            Title=e(ui.Text,{text="Murder Mystery 2",size=24,height=42,color=ui.colors.ink,font=Enum.Font.SourceSansSemibold}),
            Columns=e(ui.Columns,{layoutOrder=1,left=left,right=right}),
        }})
    end
end
