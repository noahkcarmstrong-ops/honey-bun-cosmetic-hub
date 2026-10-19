local create=dofile('mm2.lua')
local function node(name,class,items)
    return {Name=name,ClassName=class,GetFullName=function()return name end,GetChildren=function()return items or {} end,GetDescendants=function()return items or {} end,IsA=function(self,c)return self.ClassName==c end}
end
local db=node('ReplicatedStorage.Database.Items','ModuleScript')
local ui=node('PlayerGui.Inventory.Equip','LocalScript')
local tool=node('Character.Knife','Tool')
local player={Name='Fixture',PlayerGui=node('PlayerGui','PlayerGui',{ui}),Character=node('Character','Model',{tool})}
local services={ReplicatedStorage=node('ReplicatedStorage','ReplicatedStorage',{db}),Players={LocalPlayer=player}}
local game={GameId=66654135,PlaceId=142823291,PlaceVersion=123,GetService=function(_,name)return services[name]end}
local report=create(game).report()
assert(report:find('ReplicatedStorage.Database.Items',1,true),'Reports item data module')
assert(report:find('PlayerGui.Inventory.Equip',1,true),'Reports inventory UI scripts without executing them')
assert(report:find('Character.Knife',1,true),'Reports equipped weapon')
assert(create({}).report():find('missing',1,true),'Handles unavailable game services')
print('MM2 read-only discovery checks passed.')
