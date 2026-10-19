-- Approximate local fallbacks. Originals are resolved by mm2_effects.lua first.
return function(entry)
    local name=(tostring(entry.id).." "..tostring(entry.name)):lower()
    local function has(word)return name:find(word,1,true)~=nil end
    local style="sparkles"
    if has("fire")or has("flam")or has("burn")or has("blaze")or has("smolder")or has("heatwave")then style="fire"
    elseif has("snow")or has("ice")or has("frost")or has("arctic")or has("blizzard")or has("chilly")then style="frost"
    elseif has("toxic")or has("poison")or has("radioactive")or has("zombie")then style="toxic"
    elseif has("void")or has("dark")or has("phantom")or has("ghost")or has("wraith")or has("cursed")or has("vamp")then style="shadow"
    elseif has("rainbow")or has("confetti")or has("retro")or has("synth")or has("aurora")or has("northern")then style="rainbow"
    elseif has("water")or has("ocean")or has("aquatic")or has("bubble")or has("bubbly")or has("jellyfish")then style="water"
    elseif has("bat")then style="bats"
    elseif has("heart")or has("pink")or has("sweet")or has("strawberr")or has("candy")or has("candies")then style="pink"
    elseif has("flower")or has("floral")or has("bloom")or has("petal")or has("leaves")or has("spring")then style="garden"
    elseif has("electric")or has("plasma")or has("matrix")or has("gear")or has("dual")or has("knifeception")then style="trail"
    elseif has("star")or has("sun")or has("glow")or has("light")or has("gold")or has("ornament")or has("jingle")then style="gold"
    elseif has("money")or has("carrot")then style="green"end
    local palettes={
        fire={{255,100,20},{255,225,90}},frost={{90,190,255},{235,255,255}},
        toxic={{80,255,40},{220,255,40}},shadow={{90,40,150},{20,10,35}},
        water={{25,130,255},{95,255,240}},bats={{150,120,190},{50,25,70}},
        pink={{255,70,150},{255,190,225}},garden={{120,240,100},{255,150,210}},
        trail={{110,120,255},{70,245,255}},gold={{255,190,30},{255,250,175}},
        green={{30,210,90},{175,255,70}},sparkles={{175,150,255},{90,210,255}},
        rainbow={{255,70,80},{100,120,255}}
    }
    local hash=0;for i=1,#tostring(entry.id)do hash=(hash*31+tostring(entry.id):byte(i))%997 end
    local palette=palettes[style]
    if style=="sparkles"then
        palette={{90+hash%166,90+math.floor(hash/3)%166,90+math.floor(hash/7)%166},{210,225,255}}
    end
    local function color(rgb)return Color3.fromRGB(rgb[1],rgb[2],rgb[3])end
    local colors=ColorSequence.new(color(palette[1]),color(palette[2]))
    if style=="rainbow"then
        local keys={};for i,rgb in ipairs({{255,60,70},{255,190,45},{70,255,90},{55,190,255},{190,75,255}})do
            keys[#keys+1]=ColorSequenceKeypoint.new((i-1)/4,color(rgb))
        end
        colors=ColorSequence.new(keys)
    end
    local root=Instance.new("Folder");root.Name="HoneyBunRecreation_"..tostring(entry.id)
    local ok,err=pcall(function()
        local origin=Instance.new("Attachment");origin.Name="EffectOrigin";origin.Parent=root
        local particle=Instance.new("ParticleEmitter");particle.Name="RecreatedParticles"
        particle.Texture=style=="bats" and "rbxassetid://5858070133" or (style=="shadow"or style=="water")and "rbxasset://textures/particles/smoke_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
        particle.Color=colors;particle.LightEmission=style=="shadow" and 0.15 or 0.65
        particle.Rate=style=="bats" and 2 or 5+hash%3
        particle.Lifetime=NumberRange.new(0.7,1.3);particle.Speed=NumberRange.new(0.3,1)
        particle.SpreadAngle=Vector2.new(70,70);particle.Rotation=NumberRange.new(-180,180)
        particle.RotSpeed=NumberRange.new(-35,35)
        particle.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.12),NumberSequenceKeypoint.new(0.35,style=="bats" and 0.65 or 0.28),NumberSequenceKeypoint.new(1,0)})
        particle.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(0.65,0.35),NumberSequenceKeypoint.new(1,1)})
        particle.Enabled=true;particle.Parent=origin
        if style=="fire"then
            local fire=Instance.new("Fire");fire.Name="RecreatedFlame";fire.Size=1.8;fire.Heat=1.5
            local flameColor=color(palette[1])
            if has("blue")then flameColor=Color3.fromRGB(20,90,255)
            elseif has("green")then flameColor=Color3.fromRGB(40,255,70)
            elseif has("pink")then flameColor=Color3.fromRGB(255,70,170)
            elseif has("dark")or has("wraith")then flameColor=Color3.fromRGB(140,40,230)
            elseif has("frost")then flameColor=Color3.fromRGB(100,220,255)end
            fire.Color=flameColor
            fire.SecondaryColor=fire.Color;fire.Parent=root
        end
        if style=="trail"or style=="rainbow"or style=="frost"or style=="water"then
            local a=Instance.new("Attachment");a.Name="TrailTop";a.Position=Vector3.new(0,0.7,0);a.Parent=root
            local b=Instance.new("Attachment");b.Name="TrailBottom";b.Position=Vector3.new(0,-0.7,0);b.Parent=root
            local trail=Instance.new("Trail");trail.Name="RecreatedTrail";trail.Attachment0=a;trail.Attachment1=b
            trail.Color=colors;trail.Lifetime=0.22;trail.LightEmission=0.65
            trail.Transparency=NumberSequence.new(0.35,1);trail.Enabled=true;trail.Parent=root
        end
    end)
    if not ok then root:Destroy();error(err)end
    return root,"local recreation: "..style.." theme; approximate visuals, no kill behavior"
end
