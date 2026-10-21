local fs=require('@lune/fs')
local luau=require('@lune/luau')
local source=fs.readFile('avatar.lua')
assert(luau.load(source),'avatar module must compile')
local first=assert(source:find('    local function bunnyExplosion',1,true))
local last=assert(source:find('    local api={}',first,true))
local make=luau.load([[return function(task,Instance,Enum,workspace,game)
local alive,current=true,true
local function valid()return current end
]]..source:sub(first,last-1)..[[
return bunnyExplosion,function()alive=false end,function()current=false end
end]])()
local jobs,created={},{}
local cleaned=0
local world={}
local function setup()
 local f,stop,invalidate=make({delay=function(seconds,fn)assert(seconds==5);table.insert(jobs,fn)end},
 {new=function(class)assert(class=='Explosion');local e={};table.insert(created,e);return e end},
 {ExplosionType={NoCraters='NoCraters'}},world,
 {GetService=function(_,name)assert(name=='Debris');return {AddItem=function(_,e,seconds)assert(seconds==3);cleaned+=1 end}end})
 local ctx={character={}}
 local hat={Parent=ctx.character,FindFirstChild=function(_,name)assert(name=='Handle');return {Position='hat-position'}end}
 return f,stop,invalidate,ctx,hat
end
local f,stop,invalidate,ctx,hat=setup()
f(ctx,hat);assert(#created==0);table.remove(jobs,1)()
assert(#created==1 and cleaned==1)
local e=created[1]
assert(e.Parent==world and e.Position=='hat-position' and e.BlastRadius==32)
assert(e.BlastPressure==0 and e.DestroyJointRadiusPercent==0 and e.ExplosionType=='NoCraters')
for _,mode in {'removed','destroyed','respawn'} do
 f,stop,invalidate,ctx,hat=setup();f(ctx,hat)
 if mode=='removed' then hat.Parent=nil elseif mode=='destroyed' then stop() else invalidate() end
 table.remove(jobs,1)();assert(#created==1,mode..' must cancel explosion')
end
assert(source:find('if id==1527622 then bunnyExplosion(ctx,candidate) end',1,true))
print('PASS: Bunny Ears delayed visual explosion, zero damage/terrain effects, cleanup, removal/respawn/destroy cancellation.')
