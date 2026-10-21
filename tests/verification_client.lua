-- Run in a Roblox client, passing the native_avatar_views module as the chunk argument.
local viewsModule=...
local player=game:GetService("Players").LocalPlayer
local screen=Instance.new("ScreenGui");screen.Name="LarpbloxVerificationTest";screen.Parent=player.PlayerGui
local row=Instance.new("Frame");row.Name="PlayerEntry_"..player.UserId;row.Parent=screen
local label=Instance.new("TextLabel");label.Text=player.Name;label.Size=UDim2.fromOffset(100,20);label.Parent=row
local api=viewsModule.create(player,function()return{}end)
local ok,result=pcall(function()
    api.update({enabled=true,verified=true,name=player.Name})
    local badge=label:FindFirstChild("LarpbloxVerifiedBadge")
    assert(badge and badge.Image=="rbxasset://textures/ui/VerifiedBadgeNameIcon.png","Native row badge missing")
    local head=player.Character.Head
    local overhead=head:FindFirstChild("LarpbloxVerification")
    assert(overhead,"Head badge missing")
    api.update({enabled=true,verified=true,name=player.Name})
    assert(label:FindFirstChild("LarpbloxVerifiedBadge")==badge,"Repeated update recreated row badge")
    assert(head:FindFirstChild("LarpbloxVerification")==overhead,"Repeated update recreated head badge")
    api.update({enabled=true,verified=false,name=player.Name})
    assert(not label:FindFirstChild("LarpbloxVerifiedBadge"),"Disabled row badge stayed visible")
    assert(not head:FindFirstChild("LarpbloxVerification"),"Disabled head badge stayed visible")
    assert(label.Text==player.Name,"Native text changed")
    api.update({enabled=true,verified=true,name=player.Name})
    api.destroy()
    assert(not label:FindFirstChild("LarpbloxVerifiedBadge") and not head:FindFirstChild("LarpbloxVerification"),"Destroy leaked badges")
    return "PASS: live native row/head badges render, reuse instances, disable, and clean up without changing text."
end)
pcall(api.destroy);screen:Destroy()
assert(ok,result)
return result
