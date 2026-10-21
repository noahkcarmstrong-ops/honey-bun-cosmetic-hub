-- Exercise the published appearance copier without the unrelated accessory fixtures.
local apply=applyPartAppearance
local function part(class,name)
    local node={ClassName=class,Name=name,children={}}
    function node:IsA(kind)return self.ClassName==kind end
    function node:GetChildren()local out={};for _,v in ipairs(self.children)do out[#out+1]=v end;return out end
    function node:Destroy()for i,v in ipairs(self.Parent.children)do if v==self then table.remove(self.Parent.children,i);break end end end
    function node:Clone()local copy=part(self.ClassName,self.Name);copy.ColorMap=self.ColorMap;copy.Texture=self.Texture;return copy end
    function node:ApplyMesh(other)self.MeshId=other.MeshId;self.TextureID=other.TextureID end
    return setmetatable(node,{__newindex=function(self,key,value)
        if key=="Parent"then value.children[#value.children+1]=self end;rawset(self,key,value)
    end})
end
local target=part("MeshPart","Head");local original=part("Decal","face");original.Texture="original-face";original.Parent=target
local dynamic=part("MeshPart","Head");local surface=part("SurfaceAppearance","SurfaceAppearance");surface.ColorMap="dynamic-face-map";surface.Parent=dynamic
apply(target,dynamic)
assert(#target.children==1 and target.children[1].ColorMap=="dynamic-face-map","dynamic face map must survive mesh copy")
assert(target.children[1]~=surface,"surface must be cloned rather than moved")
local classic=part("MeshPart","Head");original:Clone().Parent=classic
apply(target,classic)
assert(#target.children==1 and target.children[1].Texture=="original-face","restore removes dynamic surface and returns classic face")
apply(target,part("MeshPart","Head"))
assert(#target.children==0,"a head with no face must clear the old surface")
print("PASS: dynamic face surfaces copy, classic faces restore, and stale face layers clear.")
