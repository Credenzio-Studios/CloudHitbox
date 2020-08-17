local settings = require(script.settings)
local hitboxManager = require(script.hitboxManager)
local debugFolder = hitboxManager:run(settings)

local CloudHitbox = {
    version = "0.1",
    settings = settings
} do
    CloudHitbox.__index = CloudHitbox

    function CloudHitbox.new(instance, pointCloud, ignoreList)
        assert(typeof(instance) == "Instance", "instance must be a Model or BasePart instance, got "..typeof(instance))
        assert(instance:IsA("Model") and instance.PrimaryPart or instance:IsA("BasePart"), "instance must be a Model or BasePart instance, got "..instance.ClassName)
        assert(type(pointCloud) == "table" and #pointCloud > 0, "pointCloud must be a table with n > 0, got "..typeof(pointCloud))
        assert(typeof(ignoreList) == "table", "ignoreList must be a table, got "..typeof(ignoreList))

        local self = hitboxManager:getHitbox(instance)
        if self then
            return self
        end
        
        table.insert(ignoreList, debugFolder)

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.IgnoreWater = true
        raycastParams.FilterDescendantsInstances = ignoreList

        self = {
            primaryPart = instance,
            pointCloud = pointCloud,
            _ignoreList = ignoreList,
            _raycastParams = raycastParams,
            _touchedEvent = Instance.new("BindableEvent"),
            _enabledEvent = Instance.new("BindableEvent"),
            _isEnabled = false,
            _wasEnabled = false
        }

        self.Touched = self._touchedEvent.Event
        self.Enabled = self._enabledEvent.Event

        setmetatable(self, CloudHitbox)
        
        hitboxManager:addHitbox(self)

        return self
    end

    function CloudHitbox:isEnabled()
        assert(self, "Missing 'self' argument")

        return self._isEnabled
    end

    function CloudHitbox:setEnabled(enabled)
        assert(self, "Missing 'self' argument")
        assert(type(enabled) == "boolean", "enabled must be a boolean, got "..typeof(enabled))

        hitboxManager:setActiveHitbox(self, enabled)
        self._isEnabled = enabled

        self._enabledEvent:Fire(self._isEnabled)
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