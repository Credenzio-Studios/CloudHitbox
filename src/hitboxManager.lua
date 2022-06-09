local DEBUG_DURATION = 3 -- seconds
local DEBUG_COLOR_HIT = Color3.new(0.1, 0.65, 0.1)
local DEBUG_COLOR_NOHIT = Color3.new(0.75, 0.75, 0.75)
local EMPTY_VECTOR3 = Vector3.new(0, 0, 0)
local VELOCITY_EXTRAPOLATION = 1 / 10

local RunService = game:GetService("RunService")

local Gizmos = require(script.Parent.Gizmos)

local isServer = RunService:IsServer()

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

    local debugLines = {}

    Gizmos.onDraw:Connect(function(g)
        if HitboxManager._settings.DebugMode then
            local currentTime = time()
            local camera = workspace.CurrentCamera
            local cameraPosition = camera.CFrame.Position
            local startPos, endPos

            for i = #debugLines, 1, -1 do
                local debugLine = debugLines[i]

                if debugLine[1] < currentTime then
                    table.remove(debugLines, i)
                else
                    startPos, endPos = debugLine[4], debugLine[5]

                    local distToCamera = (cameraPosition - (startPos + endPos) / 2).Magnitude
                    local width = math.log10(distToCamera) * 0.01

                    g.setColor(debugLine[2])
                    g.setTransparency(debugLine[3])
                    g.drawLine(startPos, endPos, width)
                end
            end
        end
    end)

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
                    local dir = currentPosition - lastPosition

                    setRaycastFilter(hitbox)
                    local raycastResult = workspace:Raycast(lastPosition, dir, hitbox._raycastParams)

                    local didHit = false
                    local hitColor

                    if raycastResult and not hitbox._hits[raycastResult.Instance] then
                        didHit = true
                        hitbox._hits[raycastResult.Instance] = true

                        local touchedFunction = hitbox._touchedFunction
                        if type(touchedFunction) == "function" then
                            hitColor = touchedFunction(raycastResult)
                        end
                    end

                    if HitboxManager._settings.DebugMode then
                        table.insert(debugLines, {
                            currentTime + DEBUG_DURATION,
                            didHit and (hitColor or DEBUG_COLOR_HIT) or DEBUG_COLOR_NOHIT,
                            0,
                            lastPosition,
                            currentPosition
                        })
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