local DEBUG_COLOR_SERVER = Color3.new(0.1, 0.1, 0.1)
local DEBUG_COLOR_CLIENT = Color3.new(0.65, 0.65, 0.65)
local EMPTY_VECTOR3 = Vector3.new(0, 0, 0)
local VELOCITY_EXTRAPOLATION = 1 / 10

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

local debugFolder = Instance.new("Folder")
debugFolder.Name = "CloudHitboxDebug_"..(isClient and "Client" or "Server")
debugFolder.Archivable = false
debugFolder.Parent = workspace

local serverDebugFolder
if not isServer then
    serverDebugFolder = workspace:WaitForChild("CloudHitboxDebug_Server")
end

local HitboxManager = {} do
    HitboxManager._hitboxes = {}
    HitboxManager._activeHitboxes = {}
    HitboxManager._running = false
    HitboxManager._connections = {}
    HitboxManager._settings = nil
    HitboxManager._lastUpdate = -math.huge

    local function setRaycastFilter(hitbox)
        local filter = hitbox._filter
        table.clear(filter)

        table.insert(filter, debugFolder)
        table.insert(filter, serverDebugFolder)

        for _, v in ipairs(hitbox._ignoreList) do
            if typeof(v) == "Instance" then
                table.insert(filter, v)
            end
        end

        hitbox._raycastParams.FilterDescendantsInstances = filter
    end

    local function getHitbox(primaryPartOrModel)
        return HitboxManager._hitboxes[primaryPartOrModel]
    end

    local function disconnectAll()
        for index, connection in pairs(HitboxManager._connections) do
            connection:Disconnect()
            HitboxManager._connections[index] = nil
        end
    end

    local function onHeartbeat(_step)
        local currentTime = time()

        if currentTime - HitboxManager._lastUpdate < (1 / HitboxManager._settings.UpdateFrequency) then
            return
        end
        
        for hitboxIndex = #HitboxManager._activeHitboxes, 1, -1 do
            local hitbox = HitboxManager._activeHitboxes[hitboxIndex]

            if hitbox.primaryPart == nil then
                HitboxManager._activeHitboxes[hitboxIndex] = nil
            else
                for _, point in pairs(hitbox.pointCloud) do
                    local lastPosition = hitbox._lastCFrame * point
                    local currentPosition = hitbox.primaryPart.CFrame * point + (isServer and hitbox.primaryPart.Velocity * VELOCITY_EXTRAPOLATION or EMPTY_VECTOR3)
                    local dir = (currentPosition - lastPosition)
                    local magnitude = dir.magnitude

                    if HitboxManager._settings.DebugMode then
                        local debugLine = Instance.new("Part")
                        debugLine.Name = "DebugLine"
                        debugLine.Material = Enum.Material.Neon
                        debugLine.Anchored = true
                        debugLine.CanCollide = false
                        debugLine.Locked = true
                        debugLine.Color = isServer and DEBUG_COLOR_SERVER or DEBUG_COLOR_CLIENT
                        debugLine.CFrame = CFrame.new(lastPosition, currentPosition) * CFrame.new(0, 0, -magnitude * 0.5)
                        debugLine.Size = Vector3.new(0, 0, magnitude)

                        debugLine.Parent = debugFolder

                        Debris:AddItem(debugLine, 5)
                    end

                    setRaycastFilter(hitbox)
                    local raycastResult = workspace:Raycast(lastPosition, dir, hitbox._raycastParams)

                    if raycastResult and not hitbox._hits[raycastResult.Instance] then
                        hitbox._hits[raycastResult.Instance] = true
                        hitbox._touchedEvent:Fire(raycastResult)
                    end
                end
            end
        end

        for _, hitbox in pairs(HitboxManager._hitboxes) do
            if hitbox.primaryPart then
                hitbox._lastCFrame = hitbox.primaryPart.CFrame + (isServer and hitbox.primaryPart.Velocity * VELOCITY_EXTRAPOLATION or EMPTY_VECTOR3)
            end
        end
        
        HitboxManager._lastUpdate = currentTime
    end

    function HitboxManager:setActiveHitbox(hitbox, isActive)
        assert(self, "Missing 'self' argument")

        if isActive then
            if not table.find(HitboxManager._activeHitboxes, hitbox) then
                hitbox._hits = {}

                table.insert(HitboxManager._activeHitboxes, hitbox)
            end
        else
            local index = table.find(HitboxManager._activeHitboxes, hitbox)

            if index then
                table.remove(HitboxManager._activeHitboxes, index)
            end
        end
    end

    function HitboxManager:run(settings)
        assert(self, "Missing 'self' argument")

        if not self._running then
            self._running = true

            disconnectAll()

            self._activeHitboxes = {}
            self._settings = settings

            self._connections.Heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
        end

        return debugFolder
    end

    function HitboxManager:stop()
        assert(self, "Missing 'self' argument")

        if self._running then
            self._running = false

            disconnectAll()
        end
    end

    function HitboxManager:addHitbox(hitbox)
        assert(self, "Missing 'self' argument")

        self._hitboxes[hitbox.primaryPart] = hitbox
    end

    function HitboxManager:getHitbox(primaryPartOrModel)
        assert(self, "Missing 'self' argument")
        assert(typeof(primaryPartOrModel) == "Instance" and (primaryPartOrModel:IsA("Model") or primaryPartOrModel:IsA("BasePart")), "Invalid type for argument 'primaryPartOrModel'; expected a Model or BasePart instance")

        return getHitbox(primaryPartOrModel)
    end
end

return HitboxManager