-- Lighting editor. Loaded only when its tab is opened.
return function(ui)
    local React,e=ui.React,ui.e
    local skies={
        {name="Game",asset=""},
        {name="Sunset Dawn",asset="325545295",image="rbxassetid://323494130"},
        {name="Grimm Night",asset="332466267",image="rbxassetid://323480314"},
        {name="Sunset",asset="402561625",image="rbxassetid://402559953"},
    }
    local icons={light="sun",colors="palette",atmosphere="cloud",fog="cloud-fog",shadows="sun",bloom="sparkles",sunRays="sun",correction="sliders-horizontal",depth="camera",blur="blend",sky="mountain"}
    local toggles={atmosphere="Enabled",shadows="GlobalShadows",bloom="Enabled",sunRays="Enabled",correction="Enabled",depth="Enabled",blur="Enabled"}
    return function(props)
        local backend=props.backend()
        local values,setValues=React.useState(function()return backend.values()end)
        local working,setWorking=React.useState(false)
        local message,setMessage=React.useState("")
        local custom,setCustom=React.useState(false)
        local model,setModel=React.useState("")
        local saving,setSaving=React.useState(false)
        local name,setName=React.useState("")
        local entries,setEntries=React.useState(props.saved())
        local menu,setMenu=React.useState(nil)
        local deleting,setDeleting=React.useState(nil)
        local renaming,setRenaming=React.useState(nil)
        local query,setQuery=React.useState("")
        local mounted=React.useRef(true)
        React.useEffect(function()mounted.current=true;return function()mounted.current=false end end,{})
        local function persist()props.persist()end
        local function update(group,field,value)
            local ok,result=pcall(backend.update,group,field,value)
            if ok then setValues(result);setMessage("")else setMessage(tostring(result):gsub("^.-:%d+:%s*",""))end
            return ok
        end
        local function run(callback)
            if working then return end
            setWorking(true);setMessage("")
            task.spawn(function()
                local ok,result=pcall(function()callback();persist();return backend.values()end)
                if not mounted.current then return end
                setWorking(false)
                if ok then setValues(result);setEntries(props.saved())
                else setMessage(tostring(result):gsub("^.-:%d+:%s*",""))end
            end)
        end
        local function snapshot(label)
            local legacy=backend.environment()
            return {name=label,asset=backend.currentAsset()or "",daylight=backend.daylightEnabled(),image=backend.previewImage(),environment=legacy,lighting=not legacy and backend.configuration()or nil}
        end
        local function save()
            run(function()
                local label=name:match("^%s*(.-)%s*$")
                assert(#label>0 and #label<=40,"Enter a name with 1–40 characters.")
                local items=props.saved()
                if renaming then items[renaming].name=label
                else assert(#items<30,"You can save up to 30 presets.");items[#items+1]=snapshot(label)end
                props.store(items);setSaving(false);setRenaming(nil);setName("")
            end)
        end
        local function group(section,index)
            local fields={}
            local toggle=toggles[section.id]
            local enabled=toggle and (values[section.id]or {})[toggle]
            for order,field in ipairs(section.fields)do
                if field.key==toggle then continue end
                local value=(values[section.id]or {})[field.key]
                local common={label=field.label,name="Lighting_"..section.id.."_"..field.key,value=value,layoutOrder=order,disabled=working or enabled==false,labelWidth=140,inputWidth=82,textSize=18,swatchWidth=82,
                    onChange=function(nextValue)return update(section.id,field.key,nextValue)end,onCommit=persist}
                if field.type=="number"then
                    common.min=field.min;common.max=field.max;common.step=field.step
                    if field.key=="ClockTime"then
                        common.step=1/60
                        common.format=function(value)local minutes=math.floor(value*60+0.5)%1440;return string.format("%02d:%02d",math.floor(minutes/60),minutes%60)end
                        common.parse=function(text)
                            local hours,minutes=text:match("^(%d%d?):(%d%d)$")
                            if hours then hours=tonumber(hours);minutes=tonumber(minutes);if hours<24 and minutes<60 then return hours+minutes/60 end;return nil end
                            return tonumber(text)
                        end
                    end
                    fields[field.key]=e(ui.NumberField,common)
                elseif field.type=="color"then fields[field.key]=e(ui.ColorField,common)
                elseif field.type=="boolean"then
                    common.onChange=function(nextValue)if update(section.id,field.key,nextValue)then persist()end end
                    fields[field.key]=e(ui.ToggleField,common)
                else
                    fields[field.key]=e(ui.Stack,{layoutOrder=order,gap=4,children={
                        Label=e(ui.Text,{text=field.label,height=22,color=ui.colors.ink}),
                        Input=e(ui.Input,{name=common.name,value=value or "",placeholder="Image asset ID",onChange=function()end,onCommit=function(nextValue)if update(section.id,field.key,nextValue)then persist()end end,layoutOrder=1,disabled=working}),
                    }})
                end
            end
            return e(ui.Section,{name="LightingSection_"..section.id,title=section.id=="shadows"and "Shadows"or section.title,icon=icons[section.id],variant="panel",open=section.open==true,layoutOrder=index,children=fields,enabled=enabled,disabled=working,
                onToggle=toggle and function(value)if update(section.id,toggle,value)then persist()end end or nil})
        end
        local cards={Layout=e("UIGridLayout",{CellSize=UDim2.new(0.5,-6,0,96),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder})}
        local current=backend.currentAsset()or ""
        for index,sky in ipairs(skies)do
            local selected=current==sky.asset
            local image=sky.asset==""and backend.gameSkyImage()or sky.image
            cards[sky.name]=e(ui.Button,{name="ChooseSky_"..(sky.asset~=""and sky.asset or "Game"),label="",layoutOrder=index,width=UDim.new(1,0),height=96,background=Color3.new(1,1,1),hoverColor=ui.editor.header,radius=UDim.new(0,5),borderColor=selected and ui.colors.blue or ui.editor.border,strokeThickness=selected and 2 or 1,disabled=working,onPress=function()setCustom(false);run(function()backend.setSky(sky.asset)end)end,children={
                Image=e("ImageLabel",{Name="SkyThumbnail",BackgroundColor3=ui.colors.button,BorderSizePixel=0,Image=image,Size=UDim2.new(1,-4,1,-28),Position=UDim2.fromOffset(2,2),ScaleType=Enum.ScaleType.Crop},{Corner=e("UICorner",{CornerRadius=UDim.new(0,4)})}),
                Name=e(ui.Text,{text=sky.name,height=26,width=UDim.new(1,-12),position=UDim2.new(0,6,1,-26),color=ui.editor.ink,size=18,font=Enum.Font.SourceSansSemibold,align=Enum.TextXAlignment.Center}),
            }})
        end
        local skyChildren={
            Cards=e("Frame",{Size=UDim2.new(1,0,0,204),BackgroundTransparency=1},cards),
            Custom=e(ui.Button,{label=custom and "Close custom skybox"or "+ Custom skybox",height=30,transparent=true,borderless=true,textColor=ui.colors.blue,textSize=16,layoutOrder=1,disabled=working,onPress=function()setCustom(not custom)end}),
        }
        if custom then
            skyChildren.Input=e(ui.Input,{placeholder="Skybox model link or ID",value=model,onChange=setModel,layoutOrder=2,disabled=working})
            skyChildren.Apply=e(ui.Button,{label="Apply skybox",selected=true,layoutOrder=3,disabled=working or model:match("^%s*$")~=nil,onPress=function()run(function()backend.setSky(model)end)end})
        end
        local left,right={},{}
        for index,section in ipairs(props.schema)do
            if index<=4 then left[section.id]=group(section,index)else right[section.id]=group(section,index)end
        end
        right.Sky=e(ui.Section,{title="Sky",icon="cloud",variant="panel",name="LightingSection_skyLibrary",open=true,layoutOrder=0,children=skyChildren})
        local nodes={
            Header=e("Frame",{Size=UDim2.new(1,-8,0,48),BackgroundTransparency=1},{
                Title=e(ui.Text,{text="Lighting",size=30,font=Enum.Font.SourceSansBold,color=ui.colors.ink,width=UDim.new(1,-250),height=38}),
                Restore=e(ui.Button,{name="RestoreLighting",label="Restore game",width=116,height=36,background=ui.editor.surface,borderColor=ui.editor.border,radius=UDim.new(0,4),textSize=16,position=UDim2.new(1,-244,0,4),disabled=working,onPress=function()run(backend.resetLighting)end}),
                Save=e(ui.Button,{label="Save preset",selected=true,width=116,height=36,radius=UDim.new(0,4),textSize=16,position=UDim2.new(1,-116,0,4),disabled=working,onPress=function()setSaving(not saving);setRenaming(nil);setName("")end}),
            }),
            Columns=e(ui.Columns,{layoutOrder=3,left=left,right=right}),
        }
        if working or message~=""then nodes.Message=e(ui.Text,{text=working and "Loading…"or message,layoutOrder=1,height=40,color=message~=""and Color3.fromRGB(170,45,45)or nil})end
        if saving then
            nodes.Save=e(ui.EntryRow,{layoutOrder=2,placeholder="Preset name",value=name,onChange=setName,action=renaming and "Rename"or "Save",onApply=save,disabled=working})
        end
        if #entries>0 then
            nodes.Presets=e(ui.Section,{title="Saved presets",icon="bookmark",variant="panel",layoutOrder=4,open=true,children={
                Grid=e(ui.SkyboxGrid,{entries=entries,query=query,menu=menu,deleting=deleting,disabled=working,onSearch=setQuery,
                    onMenu=function(id)setMenu(menu~=id and id or nil);setDeleting(nil)end,onCancel=function()setMenu(nil);setDeleting(nil)end,
                    onRequestDelete=setDeleting,
                    onLoad=function(id)run(function()
                        local entry=props.saved()[id]
                        if entry.lighting then backend.loadConfiguration(entry.lighting)
                        else
                            backend.resetLighting();backend.setDaylight(entry.daylight)
                            if entry.asset~=""then local ok,err=backend.apply(entry.asset);assert(ok,err)end
                            if entry.environment then local ok,err=backend.applyEnvironment(entry.environment);assert(ok,err)end
                        end
                    end)end,
                    onUpdate=function(id)run(function()local items=props.saved();items[id]=snapshot(items[id].name);props.store(items);setMenu(nil)end)end,
                    onRename=function(id)setRenaming(id);setSaving(true);setName(entries[id].name);setMenu(nil)end,
                    onDelete=function(id)run(function()local items=props.saved();table.remove(items,id);props.store(items);setMenu(nil);setDeleting(nil)end)end,
                }),
            }})
        end
        return e(ui.Stack,{name="LightingPage",layoutOrder=props.layoutOrder,gap=14,children=nodes})
    end
end
