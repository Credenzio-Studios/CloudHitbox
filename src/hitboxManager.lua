local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

local debugFolder = Instance.new("Folder")
debugFolder.Name = "CloudHitboxDebug_"..(isClient and "Client" or "Server")
debugFolder.Archivable = false
debugFolder.Parent = workspace

local HitboxManager = {} do
    HitboxManager._hitboxes = {}
    HitboxManager._activeHitboxes = {}
    HitboxManager._running = false
    HitboxManager._connections = {}
    HitboxManager._settings = nil
    HitboxManager._lastUpdate = -math.huge

    local function getHitbox(primaryPartOrModel)
        return HitboxManager._hitboxes[primaryPartOrModel]
    end

    local function disconnectAll()
        for index, connection in pairs(HitboxManager._connections) do
            connection:Disconnect()
            HitboxManager._connections[index] = nil
        end
    end

    local function onClientHeartbeat()
        for hitboxIndex = #HitboxManager._activeHitboxes, 1, -1 do
            local hitbox = HitboxManager._activeHitboxes[hitboxIndex]

            if hitbox.primaryPart == nil then
                HitboxManager._activeHitboxes[hitboxIndex] = nil
            else
                for _, point in pairs(hitbox.pointCloud) do
                    local lastPosition = hitbox._lastCFrame * point
                    local currentPosition = hitbox.primaryPart.CFrame * point
                    local dir = (currentPosition - lastPosition)
                    local magnitude = dir.magnitude

                    if HitboxManager._settings.DebugMode then
                        local debugLine = Instance.new("Part")
                        debugLine.Name = "DebugLine"
                        debugLine.Material = Enum.Material.Neon
                        debugLine.Anchored = true
                        debugLine.CanCollide = false
                        debugLine.Locked = true
                        debugLine.CFrame = CFrame.new(lastPosition, currentPosition) * CFrame.new(0, 0, -magnitude * 0.5)
                        debugLine.Size = Vector3.new(0, 0, magnitude)

                        debugLine.Parent = debugFolder

                        Debris:AddItem(debugLine, 5)
                    end

                    local raycastResult = workspace:Raycast(lastPosition, dir, hitbox._raycastParams)

                    if raycastResult then
                        hitbox._touchedEvent:Fire(raycastResult)
                    end
                end
            end
        end

        for _, hitbox in pairs(HitboxManager._hitboxes) do
            if hitbox.primaryPart then
                hitbox._lastCFrame = hitbox.primaryPart.CFrame
            end
        end
    end

    local function onServerHeartbeat()
    end

    local function onHeartbeat(_step)
        local currentTime = time()

        if currentTime - HitboxManager._lastUpdate < (1 / HitboxManager._settings.UpdateFrequency) then
            return
        end

        if isServer then
            onServerHeartbeat()
        end

        if isClient then
            onClientHeartbeat()
        end
        
        HitboxManager._lastUpdate = currentTime
    end

    function HitboxManager:run(settings)
        assert(self, "Missing 'self' argument")

        if not self._running then
            self._running = true

            disconnectAll()

            self._activeHitboxes = {}
            self._settings = settings

            for _, hitboxInstance in pairs(CollectionService:GetTagged(settings.CollectionTag)) do
                local hitbox = getHitbox(hitboxInstance)

                if hitbox then
                    table.insert(self._activeHitboxes, hitbox)
                end
            end

            local instanceAddedSignal = CollectionService:GetInstanceAddedSignal(settings.CollectionTag)
            local instanceRemovedSignal = CollectionService:GetInstanceRemovedSignal(settings.CollectionTag)

            self._connections.CollectionInstanceAdded = instanceAddedSignal:Connect(function(object)
                if object:IsA("Model") or object:IsA("BasePart") then
                    local hitbox = getHitbox(object)

                    if hitbox and not table.find(self._activeHitboxes, hitbox) then
                        table.insert(self._activeHitboxes, hitbox)
                    end
                end
            end)
            
            self._connections.CollectionInstanceRemoved = instanceRemovedSignal:Connect(function(object)
                if object:IsA("Model") or object:IsA("BasePart") then
                    local hitbox = getHitbox(object)

                    local index = table.find(self._activeHitboxes, hitbox)

                    if index then
                        table.remove(self._activeHitboxes, index)
                    end
                end
            end)

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