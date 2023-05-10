ix.phone = ix.phone or {}
ix.phone.switch = ix.phone.switch or {}

-- a volatile table for caching ongoing connections
ix.phone.switch.connections = ix.phone.switch.connections or {}

function ix.phone.switch:ConnectionValid(connID)
    if (!self.connections[connID]) then
        return false
    end

    return istable(self.connections[connID])
end

function ix.phone.switch:buildNewConnectionNode(connID, extID, extNum)
    -- helper function to create source requests for connections
    -- constructs a table that can be used by ix.phone.switch:connect()
    if (!self:ConnectionValid(connID)) then
        return
    end

    if (!self.connections[connID].nodes) then 
        self.connections[connID].nodes = {}
    end

    local nodeID = #self.connections[connID].nodes + 1
    self.connections[connID].nodes[nodeID] = {}
    self.connections[connID].nodes[nodeID]["exchange"] = extID
    self.connections[connID].nodes[nodeID]["extension"] = extNum
end

function ix.phone.switch:buildNewConnection()
    -- helper function to that creates a new connection

    -- attempt to reuse a freshly terminated connection
    for id, conn in ipairs(self.connections) do
        if (conn == false) then
            return id
        end
    end

    -- no terminated connections
    connectionID = #self.connections + 1
    self.connections[connectionID] = {}

    return connectionID
end

function ix.phone.switch:Disconnect(connID, notify)
    -- disconnects provided connection
    -- if notify is set, then it will also notify any of the listeners that
    -- the connection is terminated
    if (!istable(self.connections[connID])) then
        return
    end

    self.connections[connID] = false

    if (!notify) then
        return
    end

    local firstNode = self.connections[connID].nodes[0]
    local listeners = self:GetListeners(firstNode["exchange"], firstNode[extension])

    for _, client in ipairs(listeners) do
        (function ()
            if (!client or !IsValid(client)) then
                return
            end

            local char = client:GetCharacter()
            if (!char) then
                return
            end

            local charMD = char.GetLandlineConnection()
            local charCurExID = charMD["exchange"]
            local charCurExt = charMD["extension"]
            
            -- this setter will notify the targeted client
            char.SetLandlineConnection({
                active = false,
                exchange = charCurExID,
                extension = charCurExt,
            })
        end)()
    end
end

function ix.phone.switch:GetListeners(extID, extNum) 
    local conn = self:GetActiveConnection(extID, extNum)
    if (!istable(conn)) then
        return
    end

    local listeners self:getSourceRecieversFromConnection(
        conn["targetConnID"],
        conn["sourceNodeID"]
    )

    local listeners = {}
    for k, recv in ipairs(recievers) do
        -- there will almost always be one reciever.. but treating this as a list in case we ever do 'conference calls'
        local _listeners = self.endpoints:GetListeners(recv["endID"])
        if (istable(_listeners)) then
            for _, listener in ipairs(listeners) do
                listeners[#listeners] = listener
            end
        end
    end

    return listeners
end

-- returns the active connection in the form of {"targetConnID", "sourceNodeID"} if one is present
function ix.phone.switch:GetActiveConnection(extID, extNum)
    for connID, nodes in ipairs(self.connections) do
        if (nodes != false) then
            for nodeID, node in ipairs(nodes) do
                if (node["exchange"] == extID and node["extension"] == extNum) then
                    -- source is present in this connection
                    return {targetConnID = connID, sourceNodeID = nodeID}
                end
            end
        end
    end
end

-- returns the actively connected (except for the source) recievers for a given connection
function ix.phone.switch:getSourceRecieversFromConnection(connID, sourceNodeID)
    local res = {}
    for nodeID, node in ipairs(self.connections[connID]) do
        if (nodeID != sourceNodeID) then
            -- we want to return this as it exists in the exchange as that will give us 
            -- extra details the node tree does not contain such as name and endID
            res[#res + 1] = self:GetDest(node["exchange"], node["extension"])
        end
    end

    return res
end
