local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CloudHitbox = require(ReplicatedStorage.CloudHitbox)

local registeredWeapons = {}

local weaponRemotes = Instance.new("Folder")
weaponRemotes.Name = "WeaponRemotes"

local registerWeaponFunction = Instance.new("RemoteFunction")
registerWeaponFunction.Name = "RegisterWeaponFunction"
registerWeaponFunction.Parent = weaponRemotes
local activateWeaponEvent = Instance.new("RemoteEvent")
activateWeaponEvent.Name = "ActivateWeaponEvent"
activateWeaponEvent.Parent = weaponRemotes

local function getWeapon(tool)
    for index, weapon in pairs(registeredWeapons) do
        if weapon.tool == tool then
            return index, weapon
        end
    end

    return 0, nil
end

local function activateWeapon(player, tool, duration)
    assert(typeof(tool) == "Instance" and tool:IsA("Tool"), "tool must be a Tool instance")
    assert(type(duration) == "number", "duration must be a number")

    local _, weapon = getWeapon(tool)

    if weapon and weapon.player == player then
        weapon.hitbox:setEnabled(true)
        print("Enabled hitbox for: "..tool.Name)

        wait(duration)

        weapon.hitbox:setEnabled(false)
        print("Disabled hitbox for: "..tool.Name)
    end
end

local function registerWeapon(player, tool)
    assert(typeof(tool) == "Instance" and tool:IsA("Tool"), "tool must be a Tool instance")

    local handle = assert(tool:FindFirstChild("Handle"), "tool must contain a Handle")

    if handle:IsDescendantOf(player.Character) == false then
        return { success = false, error = "tool.Handle must be a descendant of the player's character"}
    end

    if getWeapon(tool) > 0 then
        return { success = false, error = "Weapon already registered"}
    end

    local hitboxPoints = CloudHitbox.getPointCloud(handle, "HitboxPoint")

    local hitbox = CloudHitbox.new(handle, hitboxPoints, { player.Character })

    local weapon = {
        tool = tool,
        player = player,
        hitbox = hitbox,
        connections = {}
    }

    local function unregister()
        local index, _weapon = getWeapon(tool)

        if index > 0 then
            table.remove(registeredWeapons, index)

            for _, connection in pairs(weapon.connections) do
                connection:Disconnect()
            end

            print("Unregistered weapon: "..tool.Name)
        end
    end

    weapon.connections.unequipped = tool.Unequipped:Connect(unregister)

    table.insert(registeredWeapons, weapon)

    return { success = true, error = nil }
end

registerWeaponFunction.OnServerInvoke = registerWeapon
activateWeaponEvent.OnServerEvent:Connect(activateWeapon)

weaponRemotes.Parent = ReplicatedStorage