local ANIMATIONS = {
    R15Slash = 522635514
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CloudHitbox = require(ReplicatedStorage.CloudHitbox)

local weaponRemotes = ReplicatedStorage:WaitForChild("WeaponRemotes")
local registerWeapon = weaponRemotes.RegisterWeaponFunction
local activateWeapon = weaponRemotes.ActivateWeaponEvent

local player = Players.LocalPlayer

repeat
    wait()
until player.Character

local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

local animTracks = {}
local tool = script.Parent
local handle = tool:FindFirstChild("Handle")
local toolEquipped = false
local debounce = false

local hitboxPoints = CloudHitbox.getPointCloud(handle, "HitboxPoint")
local hitbox = CloudHitbox.new(handle, hitboxPoints, { player.Character })

local function isHumanoidAlive()
    if humanoid then
        return humanoid.Health > 0
    else
        return false
    end
end

local function getAnimTrack(animationId)
    assert(type(animationId) == "number", "animation must be a number")

    local animTrack = animTracks[animationId]

    if not animTrack then
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://"..animationId

        animTrack = humanoid:LoadAnimation(animation)

        animTracks[animationId] = animTrack
    end

    return animTrack
end

local function attack()
    if debounce then
        return
    end

    debounce = true

    local animTrack = getAnimTrack(ANIMATIONS.R15Slash)
    animTrack:Play()

    hitbox:setEnabled(true)
    activateWeapon:FireServer(tool, animTrack.Length)

    wait(animTrack.Length)
    
    hitbox:setEnabled(false)

    debounce = false
end

local function onEquipped()
    local registerResults = registerWeapon:InvokeServer(tool)

    if registerResults.success then
        print("Registered weapon: "..tool.Name)
    else
        warn("Could not register weapon: "..tool.Name, "\n"..registerResults.error)
    end

    toolEquipped = true
end

local function onUnequipped()
    toolEquipped = false
end

local function onActivated()
    if toolEquipped and isHumanoidAlive() then
        attack()
    end
end

local function onTouched(raycastResult)
    print('Hitbox detected a hit: ', raycastResult.Instance:GetFullName())
end

tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)
tool.Activated:Connect(onActivated)
hitbox.Touched:Connect(onTouched)