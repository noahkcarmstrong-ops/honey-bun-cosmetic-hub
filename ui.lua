-- Larpblox's classic control styling over Prism's React-Luau components.
return function(runtime, colors, gui, content, tabs, hideHost, callbacks)
    local React, Prism, ReactRoblox = runtime.React, runtime.Prism, runtime.ReactRoblox
    local e = React.createElement
    local ui = {React = React, Prism = Prism, e = e, colors=colors}
    -- React clears its root on first commit. The existing shell and portal
    -- targets belong to the menu controller, so they must be outside that root.
    local container = Instance.new("Folder")
    container.Name = "PrismRoot"
    container.Parent = gui
    local root = ReactRoblox.createRoot(container)
    local alive, mounted, rows, options = true, false, {}, nil
    local refreshLabel = "Refresh"
    local status, setStatus = React.createBinding("")
    local persistence, setPersistence = React.createBinding("")
    ui.status, ui.setStatus = status, setStatus
    ui.persistence, ui.setPersistence = persistence, setPersistence

    local theme = {
        fontFamily = Enum.Font.SourceSans,
        radius = {xs = 2, sm = 2, md = 2, lg = 3, xl = 3},
        colors = {
            primary = {main = colors.blue, light = colors.hover, dark = colors.blueHover, contrast = Color3.new(1, 1, 1)},
            text = {primary = colors.ink, secondary = colors.muted},
            background = {default = colors.paper, surface = colors.paper, raised = colors.button},
            border = {subtle = colors.edge, default = colors.edge, strong = colors.blue},
        },
    }

    function ui.Button(props)
        local header = props.header
        local base = props.background or (props.selected and colors.blue or colors.button)
        local hover = props.hoverColor or (props.selected and colors.blueHover or colors.hover)
        if header then base = props.background or colors.blue; hover = colors.blueHover end
        return e(Prism.Button, {
            label = props.label, onPress = props.onPress, disabled = props.disabled,
            width = props.width or UDim.new(1, -8), height = props.height or 36,
            position = props.position, anchor = props.anchor, layoutOrder = props.layoutOrder,
            size = "sm", variant = "outline", px = 0, py = 0,
            styleOverrides = function(_, context)
                return {
                    backgroundColor = context.state == "hovered" and hover or base,
                    backgroundTransparency = props.transparent and 1 or 0,
                    textColor = props.textColor or ((props.selected or header) and Color3.new(1, 1, 1) or colors.ink),
                    strokeColor = props.borderColor or colors.edge, strokeTransparency = props.borderless and 1 or 0,
                    shouldRenderStroke = not props.borderless,
                    scale = context.state == "pressed" and 0.98 or 1,
                }
            end,
            slotProps = {
                root = {Name = props.name or "Button", Font = props.font or Enum.Font.SourceSansSemibold,
                    FontFace = Font.fromEnum(props.font or Enum.Font.SourceSansSemibold),
                    TextSize = props.textSize or 15, ZIndex = props.zIndex,
                    TextTruncate = props.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None},
                corner = {CornerRadius = props.radius or UDim.new(0, 2)},
                stroke = {Thickness = props.strokeThickness or 1},
            },
        }, props.children and {
            Content=e("Frame",{Name="ButtonContent",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1)},props.children),
        }or nil)
    end

    function ui.Text(props)
        return e(Prism.Text, {
            text = props.text or "", size = props.size or 14, color = props.color or colors.muted,
            font = props.font or Enum.Font.SourceSans,
            width = props.width or UDim.new(1, -8), height = props.height or 36,
            position = props.position, layoutOrder = props.layoutOrder, wrap = true,
            slotProps = {root = {
                Name = props.name or "TextLabel", Font = props.font or Enum.Font.SourceSans,
                Text = props.binding, TextWrapped = props.wrap ~= false,
                TextXAlignment = props.align or Enum.TextXAlignment.Left,
                TextYAlignment = props.top and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
                TextTruncate = props.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
                AutomaticSize = props.autoSize and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                Visible = props.visible, ZIndex = props.zIndex,
            }},
        })
    end

    function ui.Input(props)
        local value, setValue = React.useState(props.value or "")
        React.useEffect(function() setValue(props.value or "") end, {props.value})
        return e(Prism.Input, {
            value = value, placeholder = props.placeholder, disabled = props.disabled,
            width = props.width or UDim.new(1, -8), height = props.height or 38, layoutOrder = props.layoutOrder,
            position = props.position,
            size = "sm", px = 12, py = 8, ref = props.inputRef,
            onChange = function(nextValue)
                setValue(nextValue)
                props.onChange(nextValue)
            end,
            Event = {FocusLost = function() if props.onCommit then props.onCommit(value)end;callbacks.save() end},
            styleOverrides = function(_, context)
                return {backgroundColor = Color3.new(1, 1, 1), textColor = colors.ink,
                    placeholderColor = colors.muted, strokeColor = context.state == "focused" and colors.blue or colors.edge,
                    strokeTransparency = 0, strokeThickness = 1}
            end,
            slotProps = {
                root = {Name = props.name or "Input"},
                textbox = {Font = Enum.Font.SourceSans, TextSize = props.textSize or 15,
                    MultiLine = props.multiline or false, TextWrapped = props.multiline or false,
                    TextTruncate = Enum.TextTruncate.None},
                corner = {CornerRadius = UDim.new(0, 2)},
            },
        })
    end

    function ui.KeybindRow(props)
        return e(Prism.Box,{width=UDim.new(1,-8),height=48,layoutOrder=props.layoutOrder},{
            Label=e(ui.Text,{text=props.label,width=UDim.new(1,-156),height=props.capturing and 26 or 48,size=16,color=colors.ink}),
            Hint=props.capturing and e(ui.Text,{text="Esc to cancel",width=UDim.new(1,-156),height=18,size=13,position=UDim2.fromOffset(0,26)}) or nil,
            Key=e(ui.Button,{name=props.name,label=props.capturing and "Press a key..." or props.value,
                width=144,height=32,position=UDim2.new(1,-144,0,8),selected=props.capturing,
                disabled=props.disabled,onPress=props.onPress}),
        })
    end

    function ui.Stack(props)
        local nodes=table.clone(props.children or {})
        nodes.Layout=e("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,props.gap or 10),FillDirection=props.horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical})
        if props.padding then nodes.Padding=e("UIPadding",{PaddingTop=UDim.new(0,props.padding),PaddingBottom=UDim.new(0,props.padding),PaddingLeft=UDim.new(0,props.padding),PaddingRight=UDim.new(0,props.padding)})end
        return e("Frame",{Name=props.name or "Stack",Size=UDim2.new(props.width or UDim.new(1,0),UDim.new(0,0)),Position=props.position,AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=props.layoutOrder},nodes)
    end
    function ui.Columns(props)
        local wide,setWide=React.useState(false)
        return e("Frame",{Name="ResponsiveColumns",Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=props.layoutOrder,
            [React.Change.AbsoluteSize]=function(object)local value=object.AbsoluteSize.X>=740;if value~=wide then setWide(value)end end},{
            Layout=e("UIListLayout",{FillDirection=wide and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,16)}),
            Left=e(ui.Stack,{width=wide and UDim.new(props.ratio or 0.56,-8)or UDim.new(1,0),layoutOrder=1,gap=14,children=props.left}),
            Right=e(ui.Stack,{width=wide and UDim.new(1-(props.ratio or 0.56),-8)or UDim.new(1,0),layoutOrder=2,gap=14,children=props.right}),
        })
    end
    local editor={surface=Color3.fromRGB(247,249,252),header=Color3.fromRGB(230,236,243),border=Color3.fromRGB(202,212,224),ink=Color3.fromRGB(35,48,68)}
    ui.editor=editor
    function ui.Switch(props)
        return e(Prism.Switch,{checked=props.value,onChange=props.onChange,disabled=props.disabled,size="md",width=44,height=28,position=props.position,
            styleOverrides=function(_,context)return {trackColor=context.checked and colors.blue or Color3.fromRGB(177,188,202),thumbColor=Color3.new(1,1,1),trackStrokeTransparency=1}end,
            slotProps={root={Name=props.name or "Toggle",ZIndex=4}},
        })
    end
    function ui.Section(props)
        local open,setOpen=React.useState(props.open~=false)
        local panel=props.variant=="panel"
        local headerHeight=panel and 40 or 38
        local nodes={
            Header=e(ui.Button,{name=props.name,label="",width=UDim.new(1,0),height=headerHeight,borderless=panel,background=panel and editor.header or nil,onPress=function()setOpen(not open)end,children={
                Icon=props.icon and e(Prism.Icon,{name=props.icon,size=21,color=editor.ink,position=UDim2.fromOffset(14,9)})or nil,
                Title=e(ui.Text,{text=props.title,size=panel and 21 or 17,font=Enum.Font.SourceSansSemibold,color=panel and editor.ink or colors.ink,position=UDim2.fromOffset(props.icon and 46 or 12,0),width=UDim.new(1,props.enabled~=nil and -134 or -76),height=headerHeight}),
                Arrow=e(Prism.Icon,{name=open and "chevron-up"or "chevron-right",size=17,color=editor.ink,position=UDim2.new(1,-30,0,(headerHeight-17)/2)}),
            }}),
            Toggle=props.enabled~=nil and e(ui.Switch,{name=(props.name or props.title).."Enabled",value=props.enabled,onChange=props.onToggle,disabled=props.disabled,position=UDim2.new(1,-86,0,6)})or nil,
            Body=open and e(ui.Stack,{layoutOrder=1,padding=panel and 14 or 12,gap=panel and 6 or 10,children=props.children})or nil,
        }
        -- Header and body share one surface; the switch stays outside the disclosure button.
        local stackChildren={Header=e("Frame",{Size=UDim2.new(1,0,0,headerHeight),BackgroundTransparency=1},{Header=nodes.Header,Toggle=nodes.Toggle}),Body=nodes.Body}
        if panel then
            stackChildren.Corner=e("UICorner",{CornerRadius=UDim.new(0,5)})
            stackChildren.Border=e("UIStroke",{Color=editor.border,Thickness=1})
        end
        return e("Frame",{Name=props.name and props.name.."Panel"or "Section",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=editor.surface,BackgroundTransparency=panel and 0 or 1,BorderSizePixel=0,LayoutOrder=props.layoutOrder},{
            Layout=e("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder}),
            Header=stackChildren.Header,Body=stackChildren.Body,Corner=stackChildren.Corner,Border=stackChildren.Border,
        })
    end
    function ui.NumberField(props)
        local function format(number)
            if props.format then return props.format(number)end
            return (string.format("%.2f",number):gsub("%.?0+$",""))
        end
        local value,setValue=React.useState(props.value or props.min)
        local draft,setDraft=React.useState(format(props.value or props.min))
        React.useEffect(function()setValue(props.value or props.min);setDraft(format(props.value or props.min))end,{props.value})
        local function change(nextValue)
            nextValue=math.clamp(nextValue,props.min,props.max)
            if props.onChange(nextValue)~=false then setValue(nextValue);setDraft(format(nextValue))end
        end
        local labelWidth=props.labelWidth or 112
        local inputWidth=props.inputWidth or 74
        return e("Frame",{Size=UDim2.new(1,0,0,38),BackgroundTransparency=1,LayoutOrder=props.layoutOrder},{
            Label=e(ui.Text,{text=props.label,width=labelWidth,height=38,size=props.textSize or 14,color=props.textSize and editor.ink or colors.ink}),
            Slider=e(Prism.Slider,{value=value,min=props.min,max=props.max,step=props.step or 0.01,size="lg",width=UDim.new(1,-labelWidth-inputWidth-20),height=30,position=UDim2.fromOffset(labelWidth+4,4),disabled=props.disabled,onChange=change,onChangeEnd=props.onCommit,
                styleOverrides=function()return {thumbColor=Color3.new(1,1,1),thumbStrokeColor=colors.blue,thumbStrokeTransparency=0,trackColor=editor.border,rangeColor=colors.blue}end,
                slotProps={thumbStroke={Thickness=1},track={Size=UDim2.new(1,0,0,6)}}}),
            Value=e(ui.Input,{name=props.name,value=draft,onChange=setDraft,textSize=props.textSize,onCommit=function(text)
                local number=props.parse and props.parse(text)or tonumber(text)
                if number and number==number then change(number)else setDraft(format(value))end
                if props.onCommit then props.onCommit()end
            end,width=inputWidth,height=34,position=UDim2.new(1,-inputWidth,0,2),disabled=props.disabled}),
        })
    end
    function ui.ToggleField(props)
        return e("Frame",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,LayoutOrder=props.layoutOrder},{
            Label=e(ui.Text,{text=props.label,color=colors.ink,width=UDim.new(1,-78),height=34,size=15}),
            Toggle=e(ui.Button,{label=props.value and "On"or "Off",selected=props.value,width=64,height=30,position=UDim2.new(1,-64,0,2),disabled=props.disabled,onPress=function()props.onChange(not props.value)end}),
        })
    end
    function ui.ColorField(props)
        local open,setOpen=React.useState(false)
        local draft,setDraft=React.useState(props.value or "#FFFFFF")
        React.useEffect(function()setDraft(props.value or "#FFFFFF")end,{props.value})
        local hex=(props.value or "#FFFFFF"):gsub("#","")
        local channels={tonumber(hex:sub(1,2),16)or 255,tonumber(hex:sub(3,4),16)or 255,tonumber(hex:sub(5,6),16)or 255}
        local labelWidth=props.labelWidth or 112
        local swatchWidth=props.swatchWidth or 38
        local nodes={Row=e("Frame",{Size=UDim2.new(1,0,0,38),BackgroundTransparency=1},{
            Label=e(ui.Text,{text=props.label,width=labelWidth,height=38,size=props.textSize or 14,color=editor.ink}),
            Swatch=e(ui.Button,{label="",disabled=props.disabled,background=Color3.fromRGB(channels[1],channels[2],channels[3]),width=swatchWidth,height=32,position=UDim2.fromOffset(labelWidth+4,3),onPress=function()setOpen(not open)end}),
            Hex=e(ui.Input,{value=draft,textSize=props.textSize,onChange=setDraft,onCommit=function(value)props.onChange(value);if props.onCommit then props.onCommit()end end,width=UDim.new(1,-labelWidth-swatchWidth-16),height=34,position=UDim2.fromOffset(labelWidth+swatchWidth+16,2),disabled=props.disabled}),
        })}
        if open then for index,label in ipairs({"Red","Green","Blue"})do local channel=index;nodes[label]=e(ui.NumberField,{label=label,value=channels[index],min=0,max=255,step=1,layoutOrder=index,onChange=function(value)
            local nextChannels=table.clone(channels);nextChannels[channel]=math.floor(value+0.5);return props.onChange(string.format("#%02X%02X%02X",nextChannels[1],nextChannels[2],nextChannels[3]))end,onCommit=props.onCommit,disabled=props.disabled})end end
        return e(ui.Stack,{layoutOrder=props.layoutOrder,gap=4,children=nodes})
    end

    function ui.SelectRow(props)
        return e(Prism.Box,{width=props.width or UDim.new(1,-8),height=40,layoutOrder=props.layoutOrder,position=props.position},{
            Label=props.label and e(ui.Text,{text=props.label,width=100,height=38,size=16,color=colors.ink}) or nil,
            Select=e(Prism.Select,{
                options=props.options,value=props.value,onChange=props.onChange,disabled=props.disabled,placeholder=props.placeholder,
                width=props.label and UDim.new(1,-108) or UDim.new(1,0),height=38,
                position=UDim2.fromOffset(props.label and 108 or 0,0),size="sm",maxVisibleOptions=7,
                styleOverrides={trigger=function()return {backgroundColor=Color3.new(1,1,1),textColor=colors.ink,strokeColor=colors.edge,strokeTransparency=0}end},
                slotProps={root={Name=props.name or "AnimationChoice"},trigger={Name=(props.name or "AnimationChoice").."_Trigger"},
                    triggerText={Font=Enum.Font.SourceSans,TextSize=16},optionText={Font=Enum.Font.SourceSans,TextSize=16}},
            }),
        })
    end

    function ui.Switcher(props)
        return e(Prism.Box,{width=UDim.new(1,-8),height=36,layoutOrder=props.layoutOrder},{
            First=e(ui.Button,{label="Animations",selected=props.value=="Animations",width=UDim.new(0.5,-3),height=34,disabled=props.disabled,onPress=function()props.onChange("Animations")end}),
            Second=e(ui.Button,{label="Emotes",selected=props.value=="Emotes",width=UDim.new(0.5,-3),height=34,position=UDim2.new(0.5,3,0,0),disabled=props.disabled,onPress=function()props.onChange("Emotes")end}),
        })
    end

    function ui.StatusNotice(props)
        local expanded,setExpanded=React.useState(false)
        local dismissed,setDismissed=React.useState(nil)
        if dismissed==props.message then return nil end
        local summary=props.message:find("Browser outfit failed",1,true)and "Some outfit items couldn’t load."or "An appearance change couldn’t finish."
        return e(ui.Stack,{layoutOrder=props.layoutOrder,gap=6,children={
            Summary=e("Frame",{Size=UDim2.new(1,-8,0,32),BackgroundColor3=Color3.fromRGB(255,246,235),BorderSizePixel=0},{
                Corner=e("UICorner",{CornerRadius=UDim.new(0,4)}),
                Icon=e(Prism.Icon,{name="alert-circle",size=17,color=Color3.fromRGB(148,91,36),position=UDim2.fromOffset(10,7)}),
                Text=e(ui.Text,{text=summary,size=15,color=Color3.fromRGB(119,74,32),position=UDim2.fromOffset(36,0),height=32,width=UDim.new(1,-154)}),
                Details=e(ui.Button,{label=expanded and "Hide details"or "Details",width=78,height=28,position=UDim2.new(1,-112,0,2),transparent=true,borderless=true,onPress=function()setExpanded(not expanded)end}),
                Close=e(ui.Button,{name="DismissNotice",label="×",width=28,height=28,textSize=20,position=UDim2.new(1,-30,0,2),transparent=true,borderless=true,onPress=function()setDismissed(props.message)end}),
            }),
            Details=expanded and e(ui.Text,{text=props.message,layoutOrder=1,height=0,autoSize=true,color=Color3.fromRGB(140,70,40),size=14})or nil,
        }})
    end

    function ui.PersistenceError(props)
        local function failed(value)return value:lower():find("failed",1,true)~=nil end
        return e("TextLabel",{Name="SaveError",LayoutOrder=props.layoutOrder,BackgroundTransparency=1,
            Text=persistence,Visible=persistence:map(failed),Size=persistence:map(function(value)return UDim2.new(1,-8,0,failed(value) and 40 or 0)end),
            Font=Enum.Font.SourceSans,TextSize=14,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.fromRGB(170,45,45)})
    end

    function ui.EntryRow(props)
        return e(Prism.Box,{width=UDim.new(1,-8),height=40,layoutOrder=props.layoutOrder},{
            Input=e(ui.Input,{name=props.name,placeholder=props.placeholder,value=props.value,onChange=props.onChange,width=UDim.new(1,-86),height=38,disabled=props.disabled,inputRef=props.inputRef}),
            Apply=e(ui.Button,{label=props.action or "Add",width=78,height=38,position=UDim2.new(1,-78,0,0),disabled=props.disabled,selected=true,onPress=props.onApply}),
        })
    end

    local backgroundCache={}
    function ui.AvatarPreview(props)
        local ref=React.useRef(nil)
        local height,setHeight=React.useState(props.height or 210)
        local background,setBackground=React.useState(nil)
        local backgroundError,setBackgroundError=React.useState("")
        React.useEffect(function()
            local cancelled=false
            setBackground(nil);setBackgroundError("")
            if not props.backgroundId or props.backgroundId<=0 then return end
            task.spawn(function()
                local ok,value=pcall(function()
                    if backgroundCache[props.backgroundId]then return backgroundCache[props.backgroundId]end
                    local roots=game:GetObjects("rbxassetid://"..props.backgroundId)
                    local data={}
                    for _,root in ipairs(roots)do
                        local id=root:FindFirstChild("ImageId",true)
                        local color=root:FindFirstChild("Color",true)
                        if id and id:IsA("IntValue")then data.image="rbxassetid://"..string.format("%.0f",id.Value) end
                        if color and color:IsA("Color3Value")then data.color=color.Value end
                        root:Destroy()
                    end
                    assert(data.image,"Background image unavailable")
                    backgroundCache[props.backgroundId]=data
                    return data
                end)
                if not cancelled then if ok then setBackground(value)else setBackgroundError("This background could not load. Choose another in Settings.")end end
            end)
            return function()cancelled=true end
        end,{props.backgroundId})
        local errorMessage,setError=React.useState("")
        React.useEffect(function()
            local previous
            local function resize()
                local viewport=ref.current
                local scroll=viewport and viewport:FindFirstAncestorWhichIsA("ScrollingFrame")
                if not scroll then return end
                local top=viewport.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
                local available=math.max(180,math.floor(scroll.AbsoluteSize.Y-top-8))
                if available~=previous then previous=available;setHeight(available) end
            end
            local viewport=ref.current
            local connections={}
            if viewport then
                for _,property in ipairs({"AbsoluteSize","AbsolutePosition"})do connections[#connections+1]=viewport:GetPropertyChangedSignal(property):Connect(resize)end
                local scroll=viewport:FindFirstAncestorWhichIsA("ScrollingFrame")
                if scroll then
                    for _,property in ipairs({"AbsoluteSize","CanvasPosition"})do connections[#connections+1]=scroll:GetPropertyChangedSignal(property):Connect(resize)end
                end
            end
            resize()
            return function()for _,connection in ipairs(connections)do connection:Disconnect()end end
        end,{})
        React.useEffect(function()
            setError("")
            if not ref.current then return end
            return props.start(ref.current,function(message)setError(message)end)
        end,{props.sourceKey})
        return e(Prism.Box,{width=UDim.new(1,-8),height=height,layoutOrder=props.layoutOrder},{
            Backdrop=e("ImageLabel",{Name="PreviewBackdrop",Size=UDim2.fromScale(1,1),BackgroundColor3=background and background.color or Color3.fromRGB(234,234,234),Image=background and background.image or "",ScaleType=Enum.ScaleType.Crop,BorderSizePixel=0}),
            View=e("ViewportFrame",{Name="AnimationAvatar",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2,ref=ref}),
            Error=(errorMessage~="" or backgroundError~="") and e(ui.Text,{text=errorMessage~="" and errorMessage or backgroundError,color=Color3.fromRGB(170,45,45),height=48,position=UDim2.new(0,8,1,-52),width=UDim.new(1,-16),zIndex=3}) or nil,
        })
    end

    function ui.EmotePicker(props)
        local noun=props.noun or "emotes"
        local mode,setMode=React.useState("Browse")
        local query,setQuery=React.useState("")
        local draft,setDraft=React.useState("")
        local selected,setSelected=React.useState(nil)
        local items,setItems=React.useState({})
        local more,setMore=React.useState(false)
        local page,setPage=React.useState(1)
        local sort,setSort=React.useState("Relevance")
        local requestedPage=React.useRef(1)
        local resultsRef=React.useRef(nil)
        local loading,setLoading=React.useState(true)
        local saving,setSaving=React.useState(false)
        local catalogError,setCatalogError=React.useState("")
        local errorMessage,setError=React.useState("")
        local request=React.useRef(0)
        local mounted=React.useRef(true)
        local function close()
            if not saving then props.onClose() end
        end
        local function load(nextPage)
            request.current=request.current+1
            local ticket=request.current
            requestedPage.current=nextPage
            setLoading(true);setCatalogError("")
            task.spawn(function()
                local ok,result,hasMore=pcall(props.loadEmotes,query,nextPage,sort)
                if not mounted.current or request.current~=ticket then return end
                setLoading(false)
                if ok then
                    setItems(result);setMore(hasMore);setPage(nextPage);setSelected(nil)
                    if resultsRef.current then resultsRef.current.CanvasPosition=Vector2.zero end
                else setCatalogError("Could not load "..noun..". Try again.") end
            end)
        end
        React.useEffect(function()
            mounted.current=true
            return function()mounted.current=false;request.current=request.current+1 end
        end,{})
        React.useEffect(function()
            if mode~="Browse" then return end
            request.current=request.current+1
            local ticket=request.current
            setLoading(true);setItems({});setMore(false);setPage(1);setSelected(nil);setCatalogError("")
            task.delay(query=="" and 0 or 0.35,function()
                if mounted.current and ticket==request.current then load(1) end
            end)
        end,{query,mode,sort})
        React.useEffect(function()
            local connection=game:GetService("UserInputService").InputBegan:Connect(function(input)
                if input.KeyCode==Enum.KeyCode.Escape then close() end
            end)
            return function()connection:Disconnect()end
        end,{saving})
        local value=mode=="Browse" and selected and tostring(selected.id) or mode=="Link or ID" and draft or ""
        local function submit()
            if saving or value:match("^%s*$") then return end
            setSaving(true);setError("")
            task.spawn(function()
                local ok,message=pcall(props.onAssign,props.slot,value)
                if not mounted.current then return end
                setSaving(false)
                if ok then props.onClose() else setError(tostring(message):gsub("^.-:%d+:%s*","")) end
            end)
        end
        local cards={Layout=e("UIGridLayout",{CellSize=UDim2.new(0.25,-9,0,150),CellPadding=UDim2.fromOffset(12,12),SortOrder=Enum.SortOrder.LayoutOrder})}
        for index,item in ipairs(items) do
            local chosen=selected and selected.id==item.id
            cards["Emote"..item.id]=e("TextButton",{
                Name="ChooseEmote_"..item.id,Text="",LayoutOrder=index,AutoButtonColor=true,
                BackgroundColor3=chosen and colors.hover or Color3.new(1,1,1),BorderSizePixel=0,
                Active=not saving and not loading,[React.Event.Activated]=function()if not saving and not loading then setSelected(item);setError("") end end,
            },{
                Corner=e("UICorner",{CornerRadius=UDim.new(0,3)}),
                Stroke=e("UIStroke",{Color=chosen and colors.blue or colors.edge,Thickness=chosen and 2 or 1}),
                Image=e("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(1,-12,0,104),Position=UDim2.fromOffset(6,6),Image="rbxthumb://type="..(item.itemType=="Bundle" and "BundleThumbnail" or "Asset").."&id="..item.id.."&w=150&h=150",ScaleType=Enum.ScaleType.Fit}),
                Label=e("TextLabel",{BackgroundTransparency=1,Position=UDim2.fromOffset(8,114),Size=UDim2.new(1,-16,0,30),Font=Enum.Font.SourceSansSemibold,TextSize=15,TextColor3=colors.ink,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,Text=item.name}),
            })
        end
        local children={
            Corner=e("UICorner",{CornerRadius=UDim.new(0,4)}),
            Limit=e("UISizeConstraint",{MaxSize=Vector2.new(560,mode=="Browse" and 620 or 290)}),
            Title=e(ui.Text,{text=props.title or ((props.current and "Replace emote" or "Add emote").." - Slot "..props.slot),size=22,font=Enum.Font.SourceSansSemibold,color=colors.ink,position=UDim2.fromOffset(20,14),width=UDim.new(1,-74),height=30}),
            Close=e(ui.Button,{label="x",name="CloseEmoteDialog",width=30,height=30,position=UDim2.new(1,-42,0,12),transparent=true,borderless=true,disabled=saving,onPress=close}),
            Browse=e(ui.Button,{label="Browse",width=100,height=30,position=UDim2.fromOffset(20,54),selected=mode=="Browse",disabled=saving,onPress=function()setMode("Browse");setError("")end}),
            Link=e(ui.Button,{label="Link or ID",width=100,height=30,position=UDim2.fromOffset(130,54),selected=mode=="Link or ID",disabled=saving,onPress=function()setMode("Link or ID");setError("")end}),
            Error=errorMessage~="" and e(ui.Text,{text=errorMessage,color=Color3.fromRGB(170,45,45),position=UDim2.new(0,20,1,-112),width=UDim.new(1,-40),height=40}) or nil,
            Selected=not props.onRestore and mode=="Browse" and selected and e(ui.Text,{text=selected.name,color=colors.ink,position=UDim2.new(0,20,1,-54),width=UDim.new(1,-270),height=36,truncate=true}) or nil,
            Cancel=e(ui.Button,{label="Cancel",width=96,height=36,position=UDim2.new(1,-232,1,-54),disabled=saving,onPress=close}),
            Add=e(ui.Button,{label=saving and "Applying..." or props.confirmLabel or (props.current and "Replace" or "Add"),name="ConfirmEmote",width=104,height=36,position=UDim2.new(1,-124,1,-54),selected=true,disabled=saving or (mode=="Browse" and loading) or value:match("^%s*$")~=nil,onPress=submit}),
        }
        if props.onRestore then
            children.Restore=e(ui.Button,{label="Current avatar",width=136,height=36,position=UDim2.new(0,20,1,-54),disabled=saving,onPress=function()
                setSaving(true);setError("")
                task.spawn(function()
                    local ok,message=pcall(props.onRestore)
                    if not mounted.current then return end
                    setSaving(false)
                    if ok then props.onClose() else setError(tostring(message)) end
                end)
            end})
        end
        if mode=="Browse" then
            children.Search=e(ui.Input,{name="SearchEmotes",placeholder="Search "..noun,value=query,onChange=setQuery,disabled=saving,position=UDim2.fromOffset(20,96),width=UDim.new(1,-40),height=38})
            children.Sort=e(ui.SelectRow,{name="CatalogSort",label="Sort by",value=sort,disabled=saving,position=UDim2.fromOffset(20,144),width=UDim.new(1,-40),options={
                {value="Relevance",label="Relevance"},{value="MostFavorited",label="Most favorited"},
                {value="Bestselling",label="Best selling"},{value="RecentlyCreated",label="Newest"},
                {value="PriceLowToHigh",label="Price: low to high"},{value="PriceHighToLow",label="Price: high to low"},
            },onChange=function(value)setSort(value);setError("")end})
            children.Grid=e("ScrollingFrame",{Name="EmoteResults",ref=resultsRef,Visible=catalogError=="",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,196),Size=UDim2.new(1,-40,1,-326),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=4,ScrollBarImageColor3=colors.edge},cards)
            if catalogError~="" then
                children.CatalogError=e(ui.Text,{text=catalogError,position=UDim2.fromOffset(20,204),width=UDim.new(1,-40),height=40})
                children.Retry=e(ui.Button,{label="Retry",width=90,height=32,position=UDim2.fromOffset(20,250),onPress=function()load(requestedPage.current)end})
            elseif loading and #items==0 then
                children.Loading=e(ui.Text,{text="Loading "..noun.."...",position=UDim2.fromOffset(20,204),width=UDim.new(1,-40),height=32})
            elseif #items==0 then
                children.Empty=e(ui.Text,{text="No results. Try another search.",position=UDim2.fromOffset(20,204),width=UDim.new(1,-40),height=32})
            end
            if errorMessage=="" then
                children.Previous=e(ui.Button,{name="PreviousCatalogPage",label="Previous",width=96,height=30,position=UDim2.new(0,20,1,-110),disabled=loading or saving or page<=1,onPress=function()load(page-1)end})
                children.Page=e(ui.Text,{name="CatalogPage",align=Enum.TextXAlignment.Center,text=loading and "Loading..." or "Page "..page,width=UDim.new(1,-252),height=30,position=UDim2.new(0,126,1,-110)})
                children.Next=e(ui.Button,{name="NextCatalogPage",label="Next",width=96,height=30,position=UDim2.new(1,-116,1,-110),disabled=loading or saving or not more,onPress=function()load(page+1)end})
            end
        else
            children.Input=e(ui.Input,{name="EmoteLink",placeholder=props.linkPlaceholder or "Roblox emote link or ID",value=draft,onChange=setDraft,disabled=saving,position=UDim2.fromOffset(20,104),width=UDim.new(1,-40),height=40})
        end
        return ReactRoblox.createPortal(e("ScreenGui",{Name="EmoteDialog",DisplayOrder=gui.DisplayOrder+10,IgnoreGuiInset=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},{
            Backdrop=e("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.4,Size=UDim2.fromScale(1,1),[React.Event.Activated]=close}),
            Dialog=e("Frame",{Name="AddEmoteDialog",BackgroundColor3=colors.paper,BorderSizePixel=0,Size=UDim2.new(1,-48,0.85,0),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Active=true,ZIndex=2},children),
        }),gui.Parent)
    end

    function ui.EmoteWheel(props)
        local hovered,setHovered=React.useState(nil)
        local editing,setEditing=React.useState(nil)
        local ref=React.useRef(nil)
        local function edit(index)
            if props.disabled then return end
            props.onSelect(index);setEditing(index)
        end
        local function slotAt(instance,point)
            local gui=instance:FindFirstAncestorWhichIsA("ScreenGui")
            local inset=gui and gui.IgnoreGuiInset and Vector2.zero or game:GetService("GuiService"):GetGuiInset()
            local delta=Vector2.new(point.X,point.Y)-inset-instance.AbsolutePosition-instance.AbsoluteSize/2
            if delta.Magnitude<instance.AbsoluteSize.X*0.225 or delta.Magnitude>instance.AbsoluteSize.X/2 then return nil end
            return math.floor(((math.deg(math.atan2(delta.Y,delta.X))+112.5)%360)/45)+1
        end
        React.useEffect(function()
            local previous=nil
            if editing then setHovered(nil);if props.onHover then props.onHover(nil) end end
            local function updateHover()
                local instance=ref.current
                local nextSlot=nil
                if instance and not props.disabled and not editing then
                    local visible=true
                    local ancestor=instance
                    while ancestor do
                        if ancestor:IsA("GuiObject") and not ancestor.Visible or ancestor:IsA("ScreenGui") and not ancestor.Enabled then visible=false;break end
                        ancestor=ancestor.Parent
                    end
                    if visible then nextSlot=slotAt(instance,game:GetService("UserInputService"):GetMouseLocation()) end
                end
                if nextSlot~=previous then previous=nextSlot;setHovered(nextSlot);if props.onHover then props.onHover(nextSlot) end end
            end
            local connections={game:GetService("UserInputService").InputChanged:Connect(updateHover)}
            local ancestor=ref.current
            while ancestor do
                if ancestor:IsA("GuiObject")then
                    for _,property in ipairs({"Visible","AbsoluteSize","AbsolutePosition"})do connections[#connections+1]=ancestor:GetPropertyChangedSignal(property):Connect(updateHover)end
                elseif ancestor:IsA("ScreenGui")then connections[#connections+1]=ancestor:GetPropertyChangedSignal("Enabled"):Connect(updateHover)end
                ancestor=ancestor.Parent
            end
            updateHover()
            return function()for _,connection in ipairs(connections)do connection:Disconnect()end end
        end,{props.disabled,editing})
        local active=hovered
        local activeSlot=active and props.slots[active] or nil
        local wheel={
            Disc=e("Frame",{BackgroundColor3=Color3.fromRGB(20,22,24),BackgroundTransparency=0.4,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=1},{Corner=e("UICorner",{CornerRadius=UDim.new(1,0)})}),
            Background=e("ImageLabel",{Name="NativeWheelArtwork",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="rbxasset://textures/ui/Emotes/Large/SegmentedCircle.png",ZIndex=2}),
            Hover=e("Frame",{Name="HoveredWedge",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Rotation=((hovered or 1)-1)*45-90,Visible=hovered~=nil,ZIndex=2},{
                Gradient=e("ImageLabel",{BackgroundTransparency=1,Image="rbxasset://textures/ui/Emotes/Large/SelectedGradient.png",ImageTransparency=0.5,AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.5,1),ZIndex=2},{Aspect=e("UIAspectRatioConstraint",{AspectRatio=183/141})}),
                Arc=e("ImageLabel",{BackgroundTransparency=1,Image="rbxasset://textures/ui/Emotes/Large/SelectedLine.png",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(0.725,-4,0.5,0),Size=UDim2.new(1,0,0.172207549,-4),ZIndex=4},{Aspect=e("UIAspectRatioConstraint",{AspectRatio=11/67})}),
            }),
            Center=e("Frame",{BackgroundColor3=Color3.fromRGB(23,25,27),BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.45,0.45),ZIndex=3},{
                Corner=e("UICorner",{CornerRadius=UDim.new(1,0)}),
                Label=e("TextLabel",{Name="SelectedSlot",BackgroundTransparency=1,Size=UDim2.new(1,-10,1,0),Position=UDim2.fromOffset(5,0),Font=Enum.Font.SourceSans,TextSize=18,TextWrapped=true,TextColor3=Color3.new(1,1,1),Text=activeSlot and activeSlot.name or "Select an Emote",ZIndex=4}),
            }),
        }
        for index=1,8 do
            local angle=math.rad((index-1)*45-90)
            local x,y=math.cos(angle),math.sin(angle)
            local slot=props.slots[index]
            wheel["Slot"..index]=e("ImageButton",{Name="WheelSlot"..index,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5+x*0.3875,0.5+y*0.3875),Size=UDim2.fromScale(0.15,0.15),Image=slot and "rbxthumb://type=Asset&id="..slot.id.."&w=420&h=420" or "",ImageColor3=Color3.new(1,1,1),AutoButtonColor=false,Active=not props.disabled,Selectable=not props.disabled,ZIndex=4,
                [React.Event.Activated]=function()edit(index) end})
            if not slot then
                wheel["Add"..index]=e("TextLabel",{Name="AddEmote"..index,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5+x*0.3875,0.5+y*0.3875),Size=UDim2.fromScale(0.15,0.15),Text="+",Font=Enum.Font.SourceSansLight,TextSize=34,TextColor3=Color3.new(1,1,1),ZIndex=5})
            end
            wheel["Number"..index]=e("TextLabel",{Name="SlotNumber"..index,BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5+x*0.275,0.5+y*0.275),Size=UDim2.fromScale(0.1,0.1),Text=tostring(index),Font=index==hovered and Enum.Font.SourceSansBold or Enum.Font.SourceSans,TextSize=index==hovered and 21 or 18,TextColor3=Color3.new(1,1,1),ZIndex=5})
        end
        local modal=editing and e(ui.EmotePicker,{
            slot=editing,current=props.slots[editing],loadEmotes=props.loadEmotes,
            onAssign=props.onAssign,onClose=function()setEditing(nil)end,
        }) or nil
        return e(Prism.Box,{width=UDim.new(1,-8),height=300,layoutOrder=props.layoutOrder},{
            Modal=modal,
            Wheel=e("TextButton",{Name="EmoteWheel",ref=ref,Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromOffset(300,300),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(0.5,0),
                [React.Event.Activated]=function(instance,input)
                    if props.disabled then return end
                    local point=input and input.Position or game:GetService("UserInputService"):GetMouseLocation()
                    local slot=slotAt(instance,point)
                    if slot then edit(slot) end
                end},wheel),
        })
    end

    function ui.CrosshairSlider(props)
        local value, setValue = React.useState(props.value)
        return e(Prism.Box, {width = UDim.new(1, -8), height = 48, layoutOrder = props.layoutOrder}, {
            Slider = e(Prism.Slider, {
                value = value, min = 8, max = 200, step = 1, size = "sm", disabled = props.disabled,
                width = UDim.new(1, -80), height = 28, position = UDim2.fromOffset(0, 8),
                onChange = function(nextValue)
                    if props.onChange(nextValue) then setValue(nextValue) end
                end,
                onChangeEnd = callbacks.save,
                slotProps = {
                    root = {Name = "CrosshairSizeSlider"},
                    track = {BackgroundColor3 = colors.edge, Size = UDim2.new(1, 0, 0, 6)},
                    range = {BackgroundColor3 = colors.blue},
                    thumb = {BackgroundColor3 = colors.blue, Size = UDim2.fromOffset(18, 18)},
                },
            }),
            Value = e(ui.Text, {text = value .. " px", width = 66, height = 28, size = 14,
                color = colors.ink, position = UDim2.new(1, -66, 0, 8)}),
        })
    end

    function ui.PaletteRow(props)
        local children = {}
        for column, shade in ipairs(props.colors) do
            local r, g, b = shade[1], shade[2], shade[3]
            local selected = tonumber(props.rgb[1]) == r and tonumber(props.rgb[2]) == g and tonumber(props.rgb[3]) == b
            children["Color" .. column] = e(ui.Button, {
                name = string.format("Color_%02X%02X%02X", r, g, b), label = "",
                width = 36, height = 36, position = UDim2.new((column - 0.5) / 5, 0, 0.5, 0),
                anchor = Vector2.new(0.5, 0.5), radius = UDim.new(1, 0), disabled = props.disabled,
                background = Color3.fromRGB(r, g, b), borderless = not selected,
                hoverColor = Color3.fromRGB(r, g, b), strokeThickness = selected and 2 or 1,
                borderColor = Color3.fromRGB(68, 130, 255),
                onPress = function() props.onPick(r, g, b) end,
            })
        end
        return e(Prism.Box, {width = UDim.new(1, -8), height = 46, layoutOrder = props.layoutOrder}, children)
    end

    local function SkyboxCard(props)
        local entry, id = props.entry, props.id
        local open = props.menu == id
        local rotation = Prism.useMotion({values = {rotation = open and 90 or 0}, transition = {duration = 0.26}})
        local children = {}
        local assetId = entry.asset:match("^%d+$") or entry.asset:match("rbxassetid://(%d+)")
            or entry.asset:match("/asset/(%d+)") or entry.asset:match("/library/(%d+)")
            or entry.asset:match("/catalog/(%d+)") or entry.asset:match("[?&]id=(%d+)")
        local image = type(entry.image) == "string" and entry.image
            or (assetId and "rbxthumb://type=Asset&id=" .. assetId .. "&w=420&h=420" or "")
        children.Load = e(ui.Button, {
            name = "LoadSkybox_" .. id, label = "", height = UDim.new(1, -38), width = "100%",
            borderless = true, disabled = props.disabled, onPress = function() props.onLoad(id) end,
            children = {
                Image = e(Prism.Image, {src = image, width = "100%", height = "100%",
                    slotProps = {root = {Name = "SkyboxPreview_" .. id, ScaleType = Enum.ScaleType.Crop}}}),
            },
        })
        children.Title = e(ui.Text, {text = entry.name, size = 16, height = 32, width = UDim.new(1, -2),
            position = UDim2.new(0, 0, 1, -32), font = Enum.Font.SourceSansBold, color = colors.ink,
            top = true, truncate = true})
        children.Cog = e(Prism.Button, {
            label = "⚙", width = 30, height = 30, size = "xs", px = 0, py = 0,
            position = UDim2.new(1, -31, 0, 1), disabled = props.disabled,
            onPress = function() props.onMenu(id) end,
            styleOverrides = function() return {backgroundTransparency = 1, textColor = colors.ink,
                strokeTransparency = 1} end,
            slotProps = {root = {Name = "SkyboxOptions_" .. id, Font = Enum.Font.SourceSans,
                TextSize = 20, ZIndex = 5, Rotation = rotation.rotation}},
        })
        if open then
            local menu = {}
            local function option(key, label, position, callback)
                menu[key] = e(ui.Button, {label = label, width = "100%", height = UDim.new(0.20, 0),
                    position = UDim2.fromScale(0, position), textSize = 12, zIndex = 4,
                    borderless = true, disabled = props.disabled, onPress = callback})
            end
            if props.deleting == id then
                option("Delete", "Confirm delete", 0.34, function() props.onDelete(id) end)
                option("Cancel", "Cancel", 0.56, props.onCancel)
            else
                option("Update", "Update", 0.17, function() props.onUpdate(id) end)
                option("Rename", "Rename", 0.37, function() props.onRename(id) end)
                option("Delete", "Delete", 0.57, function() props.onRequestDelete(id) end)
                option("Cancel", "Cancel", 0.77, props.onCancel)
            end
            children.Menu = e(Prism.Box, {width = "100%", height = UDim.new(1, -38),
                bg = colors.paper, bgTransparency = 0.04, radius = 2, zIndex = 3,
                slotProps = {root = {Name = "SkyboxMenu_" .. id, Active = true}}}, menu)
        end
        return e(Prism.Box, {layoutOrder = id, width = "100%", height = "100%",
            slotProps = {root = {Name = "SkyboxCard_" .. id}}}, children)
    end

    function ui.SkyboxGrid(props)
        local query, setQuery = React.useState(props.query)
        local width, setWidth = React.useState(440)
        local columns = math.max(1, math.floor((width + 10) / 134))
        local cell = (width - (columns - 1) * 10) / columns
        local cards, count = {}, 0
        for id, entry in ipairs(props.entries) do
            if entry.name:lower():find(query:lower(), 1, true) then
                local cardProps = table.clone(props)
                cardProps.id, cardProps.entry = id, entry
                cards["Skybox" .. id] = e(SkyboxCard, cardProps)
                count = count + 1
            end
        end
        cards.Layout = e("UIGridLayout", {SortOrder = Enum.SortOrder.LayoutOrder,
            CellPadding = UDim2.fromOffset(10, 20), FillDirectionMaxCells = columns,
            CellSize = UDim2.new(1 / columns, -10 * (columns - 1) / columns, 0, cell + 38)})
        return e(Prism.Box, {width = UDim.new(1, -8), layoutOrder = props.layoutOrder,
            slotProps = {root = {AutomaticSize = Enum.AutomaticSize.Y}}}, {
            Layout = e("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}),
            Search = e(ui.Input, {placeholder = "Search saved atmospheres...", value = query, width = "100%",
                disabled = props.disabled, layoutOrder = 1, onChange = function(value)
                    setQuery(value); props.onSearch(value)
                end}),
            Grid = e(Prism.Box, {width = "100%", height = math.max(0, math.ceil(count / columns) * (cell + 58) - 20),
                layoutOrder = 2, slotProps = {root = {Name = "SkyboxGrid"}},
                Change = {AbsoluteSize = function(instance)
                    if instance.AbsoluteSize.X > 0 and instance.AbsoluteSize.X ~= width then setWidth(instance.AbsoluteSize.X) end
                end}}, cards),
            Empty = count == 0 and e(ui.Text, {text = "No atmospheres found.", height = 32, layoutOrder = 3}) or nil,
        })
    end

    local function draw()
        if not alive or not options then return end
        local tabNodes = {}
        for index, page in ipairs(options.pages) do
            tabNodes[page] = e(ui.Button, {
                name = page, label = page, selected = page == options.page,
                width = UDim.new(1/#options.pages,-8),
                height = 32, layoutOrder = index, disabled = options.busy,
                onPress = function() callbacks.selectPage(page) end,
            })
        end
        local tree = e(Prism.ThemeProvider, {theme = theme, density = "compact"}, {
            Content = ReactRoblox.createPortal(e(React.Fragment, {key = options.page}, rows), content),
            Tabs = ReactRoblox.createPortal(e(React.Fragment, nil, tabNodes), tabs),
            Hide = ReactRoblox.createPortal(e(ui.Button, {label = "−", name = "Hide", width = "100%", height = "100%",
                header = true, transparent = true, borderless = true, textSize = 24, font = Enum.Font.SourceSans,
                onPress = callbacks.hide}), hideHost),

        })
        if mounted then
            root:render(tree)
        else
            -- Finish the first commit before the controller retires the old UI.
            ReactRoblox.flushSync(function() root:render(tree) end)
            mounted = true
        end
    end
    function ui.render(children, state) rows, options = children, state; draw() end
    function ui.setRefreshLabel(label) refreshLabel = label; draw() end
    function ui.destroy()
        if not alive then return end
        alive = false
        root:unmount()
        container:Destroy()
    end
    return ui
end
