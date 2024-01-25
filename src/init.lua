local IGNORE_PROPERTIES = {
    _isEnabled = true,
    _pendingUpdate = true,
    _touchedFunction = true
}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local settings = require(script.settings)

local hitboxWorkerScript = script.hitboxWorker
local isServer = RunService:IsServer()

local workerFolder = Instance.new("Folder")
workerFolder.Archivable = false
workerFolder.Name = "HitboxWorkers"

if isServer then
    workerFolder.Parent = game:GetService("ServerScriptService")
else
    workerFolder.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
end

local CloudHitbox = {
    version = "0.2",
    settings = settings
} do
    CloudHitbox.__index = CloudHitbox
    CloudHitbox.hitboxes = {}

    function CloudHitbox.new(instance, pointCloud, ignoreList)
        assert(typeof(instance) == "Instance", "instance must be a Model or BasePart instance, got "..typeof(instance))
        assert(instance:IsA("Model") and instance.PrimaryPart or instance:IsA("BasePart"), "instance must be a Model or BasePart instance, got "..instance.ClassName)
        assert(type(pointCloud) == "table" and #pointCloud > 0, "pointCloud must be a table with n > 0, got "..typeof(pointCloud))
        assert(typeof(ignoreList) == "table", "ignoreList must be a table, got "..typeof(ignoreList))

        local self = CloudHitbox.hitboxes[instance]
        if self then
            return self
        end

        local properties = {
            primaryPart = instance,
            pointCloud = pointCloud,
            _ignoreList = ignoreList,
            _enabledEvent = Instance.new("BindableEvent"),
            _touchedBindable = Instance.new("BindableFunction"),
            _isEnabled = false,
            _touchedFunction = nil,
            _actor = nil,
            _workerScript = nil,
            _pendingUpdate = nil
        }

        properties.Enabled = properties._enabledEvent.Event

        setmetatable(properties, CloudHitbox)

        local actor = Instance.new("Actor")
        actor.Name = instance:GetFullName()

        local workerScript = hitboxWorkerScript:Clone()
        workerScript.Disabled = false
        workerScript.Parent = actor

        local gizmosValue = Instance.new("ObjectValue")
        gizmosValue.Name = "Gizmos"
        gizmosValue.Value = script.Gizmos
        gizmosValue.Parent = workerScript

        actor.Parent = workerFolder

        properties._actor = actor
        properties._workerScript = workerScript

        task.defer(actor.SendMessage, actor, "Update", properties, CloudHitbox.settings)

        self = setmetatable({
            properties = properties
        }, {
            __index = properties,
            __newindex = function(_t, k, v)
                properties[k] = v

                if not IGNORE_PROPERTIES[k] then
                    actor:SendMessage("Update", {
                        [k] = v
                    })
                end
            end
        })

        CloudHitbox.hitboxes[instance] = self

        local destroyingConn
        local ancestryChangedConn

        local function OnDestroying()
            destroyingConn:Disconnect()
            ancestryChangedConn:Disconnect()

            self:destroy()
        end

        local function OnAncestryChanged()
            if not instance:IsDescendantOf(game) then
                OnDestroying()
            end
        end

        destroyingConn = instance.Destroying:Connect(OnDestroying)
        ancestryChangedConn = instance.AncestryChanged:Connect(OnAncestryChanged)

        return self
    end

    function CloudHitbox:isEnabled()
        assert(self, "Missing 'self' argument")

        return self._isEnabled
    end

    function CloudHitbox:setEnabled(enabled)
        assert(self, "Missing 'self' argument")
        assert(type(enabled) == "boolean", "enabled must be a boolean, got "..typeof(enabled))

        if self._isEnabled ~= enabled then
            self._isEnabled = enabled

            self._actor:SendMessage("Enable", enabled)

            self._enabledEvent:Fire(self._isEnabled)
        end
    end

    function CloudHitbox:setTouchedFunction(func)
        assert(self, "Missing 'self' argument")
        assert(type(func) == "function" or func == nil, "func must be a function or nil, got "..typeof(func))

        self._touchedFunction = func
        self._touchedBindable.OnInvoke = func
    end

    function CloudHitbox:destroy()
        CloudHitbox.hitboxes[self.primaryPart] = nil

        self._enabledEvent:Destroy()
        self._touchedBindable:Destroy()
        self._workerScript.Disabled = true
        self._actor:Destroy()
    end

    function CloudHitbox.getPointCloud(modelOrPart, attachmentName)
        assert(typeof(modelOrPart) == "Instance" and (modelOrPart:IsA("Model") or modelOrPart:IsA("BasePart")), "modelOrPart must be a Model or BasePart instance, got "..typeof(modelOrPart))
        assert(type(attachmentName) == "string", "attachmentName must be a string, got "..typeof(attachmentName))

        local primaryPart = modelOrPart

        if modelOrPart:IsA("Model") then
            primaryPart = assert(modelOrPart.PrimaryPart, "modelOrPart.PrimaryPart must be set")
        end

        local pointCloud = {}

        local connectedParts = primaryPart:GetConnectedParts(true)
        table.insert(connectedParts, primaryPart)

        for _, part in pairs(connectedParts) do
            for _, attachment in pairs(part:GetDescendants()) do
                if attachment:IsA("Attachment") and attachment.Name == attachmentName then
                    local attachmentPosition = primaryPart.CFrame:PointToObjectSpace(attachment.WorldPosition)
                    table.insert(pointCloud, attachmentPosition)
                end
            end
        end

        return pointCloud
    end
end

return CloudHitbox