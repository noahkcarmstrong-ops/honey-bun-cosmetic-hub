-- Runs the production badge renderer against both native menu label shapes.
return function(source)
    local block=assert(source:match("    local function renderVerification%(%)%s*(.-)    local verificationQueued=false"))
    local run=assert(loadstring([[return function(env)
        local verificationBadges,verificationGeometry,renderingVerification={},{},false
        local alive,enabled,verified=true,true,true
        local roots={env.root}
        local rootIndexes={[env.root]={objects={[env.label]=true}}}
        local player={}
        local currentName="Noah"
        local function read(o,k) return o and o[k] end
        local function plainText(t) return t or "" end
        local function verificationText() return true end
        local function hasOwnId() return true end
        local function uniquePeopleRow() return false end
        local function verifiedRosterRow() return false end
        local function clearVerification() end
        local Instance,UDim2,Vector2,Enum=env.Instance,env.UDim2,env.Vector2,env.Enum
        local renderVerification
        renderVerification=function()
    ]]..block..[[
        renderVerification()
        return verificationBadges[env.label],renderVerification
    end]]))()
    local function check(width,textWidth,alignment,expected)
        local label={ClassName="TextLabel",Text="Noah",Parent={},AbsoluteSize={X=width,Y=18},TextBounds={X=textWidth,Y=18},TextXAlignment=alignment,ZIndex=3}
        local badge,refresh=run({root={},label=label,
            Instance={new=function() return {} end},
            UDim2={fromOffset=function(x,y)return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}end,new=function(xs,x,ys,y)return {X={Scale=xs,Offset=x},Y={Scale=ys,Offset=y}}end},
            Vector2={new=function(x,y)return {X=x,Y=y}end},
            Enum={TextXAlignment={Left="Left",Center="Center",Right="Right"}}})
        local x=badge.Position.X.Scale*width+badge.Position.X.Offset
        assert(x==expected,"badge must follow visible name, got "..x.." expected "..expected)
        assert(badge.Size.X.Offset==16 and badge.Size.Y.Offset==16,"native badge size")
        label.TextBounds.X=textWidth+10
        if width==textWidth then label.AbsoluteSize.X=width+10 end
        refresh()
        local updated=badge.Position.X.Scale*width+badge.Position.X.Offset
        assert(updated==expected+10*(alignment=="Left" and 1 or alignment=="Center" and 0.5 or 0),"badge must follow changed text bounds")
    end
    check(128,37,"Left",39)
    check(37,37,"Left",39)
    check(128,37,"Center",84.5)
    check(128,37,"Right",130)
    print("PASS: square/list badge follows visible name and updated text bounds")
end
