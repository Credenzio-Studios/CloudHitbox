local DEBUG_DURATION = 3 -- seconds
local DEBUG_COLOR_HIT = Color3.new(0.1, 0.65, 0.1)
local DEBUG_COLOR_NOHIT = Color3.new(0.75, 0.75, 0.75)
local EMPTY_VECTOR3 = Vector3.new(0, 0, 0)
local VELOCITY_EXTRAPOLATION = 1 / 10

local RunService = game:GetService("RunService")

--local Gizmos = require(script:WaitForChild("Gizmos").Value)

local isServer = RunService:IsServer()
local actor = script:GetActor()
local hitboxData, managerSettings, hits, debugLines, filter = {}, {}, {}, {}, {}
local lastCFrame

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true
raycastParams.FilterDescendantsInstances = {}

local function setRaycastFilter()
    table.clear(filter)

    if hitboxData._ignoreList then
        for _, v in ipairs(hitboxData._ignoreList) do
            if typeof(v) == "Instance" then
                table.insert(filter, v)
            end
        end
    end

    raycastParams.FilterDescendantsInstances = filter
end

local onHeartbeat -- defined below; connected only while the hitbox is enabled (setUpdating)
local heartbeatConnection

-- The per-frame sweep runs only while the hitbox is enabled. It used to run on every frame for every hitbox,
-- enabled or not, only to track lastCFrame; with a hitbox per NPC weapon on every client that was one parallel
-- callback per NPC per frame. The sweep of an enabled hitbox starts from where it is when it is enabled.
local function setUpdating(enabled)
    if enabled and not heartbeatConnection then
        local primaryPart = hitboxData.primaryPart

        lastCFrame = primaryPart and primaryPart.CFrame + (isServer and primaryPart.Velocity * VELOCITY_EXTRAPOLATION or EMPTY_VECTOR3) or nil
        heartbeatConnection = RunService.Heartbeat:ConnectParallel(onHeartbeat)
    elseif not enabled and heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
end

local function onUpdate(newData, newSettings)
    if newData._isEnabled ~= nil and newData._isEnabled ~= hitboxData._isEnabled then
        table.clear(hits)
    end

    for k, v in pairs(newData) do
        hitboxData[k] = v

        if k == "_ignoreList" then
            setRaycastFilter()
        end
    end

    if newSettings then
        managerSettings = newSettings
    end

    setUpdating(hitboxData._isEnabled == true)
end

local function onEnable(enabled)
    if enabled ~= hitboxData._isEnabled then
        hitboxData._isEnabled = enabled
        table.clear(hits)
    end

    setUpdating(enabled)
end

actor:BindToMessage("Update", onUpdate)
-- Serial, not parallel: it connects and disconnects the per-frame sweep.
actor:BindToMessage("Enable", onEnable)

--[[Gizmos.onDraw:Connect(function(g)
    if managerSettings.DebugMode then
        local currentTime = os.clock()
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
end)]]

local lastUpdate = 0
function onHeartbeat(_deltaTime)
    local currentTime = os.clock()

    if not managerSettings.UpdateFrequency or currentTime - lastUpdate < 1 / managerSettings.UpdateFrequency then
        return
    end

    lastUpdate = currentTime

    if lastCFrame and hitboxData._isEnabled then
        for _, point in ipairs(hitboxData.pointCloud) do
            local lastPosition = lastCFrame * point
            local currentPosition = hitboxData.primaryPart.CFrame * point + (isServer and hitboxData.primaryPart.Velocity * VELOCITY_EXTRAPOLATION or EMPTY_VECTOR3)
            local dir = currentPosition - lastPosition

            local raycastResult = workspace:Raycast(lastPosition, dir, raycastParams)

            local didHit = false
            local hitColor
            
            if managerSettings.DebugMode then
                table.insert(debugLines, {
                    os.clock() + DEBUG_DURATION,
                    didHit and (hitColor or DEBUG_COLOR_HIT) or DEBUG_COLOR_NOHIT,
                    0,
                    lastPosition,
                    currentPosition
                })
            end

            if raycastResult and not hits[raycastResult.Instance] then
                didHit = true
                hits[raycastResult.Instance] = true

                local touchedBindable = hitboxData._touchedBindable
                if touchedBindable then
                    task.synchronize()

                    hitColor = touchedBindable:Invoke(raycastResult, dir)
                end
            end
        end
    end

    if hitboxData.primaryPart then
        lastCFrame = hitboxData.primaryPart.CFrame + (isServer and hitboxData.primaryPart.Velocity * VELOCITY_EXTRAPOLATION or EMPTY_VECTOR3)
    end
end