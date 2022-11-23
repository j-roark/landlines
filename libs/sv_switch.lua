-- this is a loose implementation of a virtual private business exchange (vPBX) and a switch
ix.phone = ix.phone or {}
ix.phone.switch = ix.phone.switch or {}
 -- a table used for managing pbxs and their members
ix.phone.switch.exchanges = ix.phone.switch.exchanges or {}
 -- a table used for switching
ix.phone.switch.connections = ix.phone.switch.connections or {}
-- a flat list of all the entities. each entity has an associated 'listeners' table which contains all of the players actively connected to that entity
ix.phone.switch.endpoints = ix.phone.switch.endpoints or {}

function ix.phone.switch.endpoints:exists(id)
    return self[id] != nil
end

function ix.phone.switch.endpoints:entExists(entIdx)
    for id, ent in ipairs(self) do
        if (entIdx == ent:EntIndex()) then
            return id
        end
    end
    return nil
end

function ix.phone.switch.endpoints:Register(ent)
    -- assigns an ID. if the ent already exists then it will return the existing id
    -- we need to have our own ID here rather than the index because the entity index might change but
    -- in that case the id shouldn't

    local entExists = self:entExists(ent:EntIndex())
    if (entExists != nil) then
        return entExists
    end

    local newID = math.random(1000, 9999)
    if (self:exists(newID)) then
        return nil
    end
    
    self[newID] = ent
    return newID
end

function ix.phone.switch.endpoints:DeRegister(id)
    self[id] = nil
end

function ix.phone.switch.endpoints:GetEndpoint(id)
    -- returns the associated entity table
    if (self:exists(id)) then
        return self[id]
    end
end

function ix.phone.switch.endpoints:AddListener(id, client)
    if (!istable(self[id].listeners)) then
        self[id].listeners = {}
    end

    self[id].listeners[#self[id].listeners] = client
end

function ix.phone.switch.endpoints:RmListener(id, client)
    if (!istable(self[id].listeners)) then
        return
    end

    for k, listener in ipairs(self[id].listeners) do
        if (listener == client) then
            self[id].listeners[k] = nil
        end
    end
end

function ix.phone.switch.endpoints:GetListeners(id)
    return self[id].listeners
end

function ix.phone.switch.endpoints:RingEndpoint(id, callback)
    -- rings and endpoint and, if the phone is picked up, it will call callback as true. otherwise false
    -- if the destination is unavailable or busy then it will return nil
    local ent = self:GetEndpoint(id)

    if (ent.inUse or ent.isRinging) then
        return nil
    end

    ent:EnterRing(callback)
end

function ix.phone.switch:AddExchange(exID)
    if (self:ExchangeExists(exID)) then
        return false
    end

    self.exchanges[exID] = {}
    return true
end

function ix.phone.switch:RmExchange(exID)
    if (!self:ExchangeExists(exID)) then
        return false
    end

    self.exchanges[exID] = nil
    return true
end

function ix.phone.switch:ExchangeExists(exID)
    return self.exchanges[exID] != nil
end

function ix.phone.switch:DestExists(exID, extNum)
    if (self.exchanges[exID] != nil) then
        return self.exchanges[exID][extNum] != nil
    else
        return false
    end
end

function ix.phone.switch:AddDest(exID, extNum, extName, endID)
    -- returns false if destination exists or exchange doesn't
    if (self:DestExists(exID, extNum)) then
        return false
    end

    self.exchanges[exID][extNum] = {}
    self.exchanges[exID][extNum]["name"] = extName
    self.exchanges[exID][extNum]["endID"] = endID
    
    return true
end

function ix.phone.switch:GetDest(exID, extNum)
    if (!self:DestExists(exID, extNum)) then
        return false
    end

    return self.exchanges[exID][extNum]
end

function ix.phone.switch:RmDest(exID, extNum)
    -- returns false if destination does not exist
    if (!self:DestExists(exID, extNum)) then
        return false
    end

    self.exchanges[exID][extNum] = nil

    return true
end

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

function ix.phone.switch:Disconnect(connID)
    if (!istable(self.connections[connID])) then
        return
    end

    self.connections[connID] = false
end

-- returns the active connection in the form of {"targetConnID", "sourceNodeID"} if one is present
function ix.phone.switch:GetActiveConnection(extID, extNum)
    for connID, nodes in ipairs(self.connections) do
        for nodeID, node in ipairs(nodes) do
            if (node["exchange"] == extID and node["extension"] == extNum) then
                -- source is present in this connection
                return {targetConnID = connID, sourceNodeID = nodeID}
            end
        end
    end
end

-- returns the actively connected recievers to a source exchange and extension
-- returns nil if there are no active connections
-- if there are listeners, we will return a list of all listeners as their endpoint ids
function ix.phone.switch:GetSourceRecievers(extID, extNum)
    local res = {}
    local targetConn = nil
    local sourceNodeID = nil

    local conn = self:GetActiveConnection(extID, extNum)
    if (!istable(conn)) then
        return
    end

    return self:getSourceRecieversFromConnection(conn["targetConnID"], conn["sourceNodeID"])
end

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

--                                           (optional)
-- takes in a dial sequence in the format of (exchange)(extension)
--                                        ex:     1        234
-- it returns it into a table as {"exchange", "extension"}
function ix.phone.switch:decodeSeq(dialSeq)
    -- dial sequences must be strings, but must be a real number as well and must be 4 digits
    if (type(dialSeq) != "string" or tonumber(dialSeq) == nil) then
        return nil
    elseif (string.len(dialSeq) > 4 or string.len(dialSeq) < 3) then
        return nil
    end
    
    local exchange = nil
    if (string.len(dialSeq) != 3) then -- otherwise it is a local dial (to endpoint in own exchange)
        exchange = tonumber(string.sub(dialSeq, 0, 1))
        if (exchange == nil or exchange < 1) then
            return nil
        end
    end

    -- the remaining digits should be the extension
    local ext = tonumber(string.sub(dialSeq, 2, 4))
    if (ext == nil or ext < 1) then
        return nil
    end

    return {["exchange"] = exchange, ["extension"] = ext}
end

-- dials from source to the destination in the provided dial sequence
-- if the call goes through the callback will be called true
-- if not then the callback will be called false
function ix.phone.switch:Dial(sourceExchange, sourceExt, sourceCallback, dialSeq)
    if (!self:DestExists(sourceExchange, sourceExt)) then
        return -- source does not exist or is not valid
    end

    local decodedDest = self:decodeSeq(dialSeq)
    if (!istable(decodedDest)) then
        return -- cannot decode the dial sequence provided
    end

    if (decodedDest["exchange"] == nil) then
        decodedDest["exchange"] = sourceExchange
    end

    if (!self:DestExists(decodedDest["exchange"], decodedDest["extension"])) then
        return -- destination does not exist or is not valid
    end
    local connID = self:buildNewConnection()

    self:buildNewConnectionNode(connID, sourceExchange, sourceExt)
    self:buildNewConnectionNode(connID, decodedDest["exchange"], decodedDest["extension"])

    -- 'dial' the endpoint entity
    local destination = self:GetDest(decodedDest["exchange"], decodedDest["extension"])

    if (!istable(destination)) then
        self:Disconnect(connID) -- destination dissapeared for some reason
        return
    end
    local destEndID = destination["endID"]

    local _callback = (function(status)
        if (!status) then -- call did not go through so we need to clean up
            self:Disconnect(connID)
        end

        pcall(self.ringCallback, status) -- send the status back to the source
    end)

    self.endpoints:GetEndpoint(tonumber(destEndID)):EnterRing(_callback)
end

-- returns back a list of player entities that are listening to the phone that (character) is speaking into
function ix.phone.switch:GetCharacterActiveListeners(character)
    if (!IsValid(character)) then
        return
    end

    local connMD = character.GetLandlineConnection()
    if (!connMD) then
        return
    end
    
    -- if there is a connection active then we need to go through the connection tree
    -- and get all of the connected nodes to said connection
    local recievers = self:GetSourceRecievers(connMD["exchange"], connMD["extension"])

    if (!istable(recievers) or #recievers < 1) then
        return
    end

    -- NOTE: Usually these will both be a for loop of 1

    -- for each node we need to get the list of active listeners from the ent and collect them
    -- into one list for the caller
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

function ix.phone.switch:GetPlayerActiveListeners(client)
    local character = client:GetCharacter()
    if (!IsValid(character)) then
        return nil
    end

    return self:GetCharacterActiveListeners(character)
end

function ix.phone.switch:DisconnectActiveCallIfPresentOnClient(client)
    local character = client:GetCharacter()
    if (!IsValid(character)) then
        return
    end

    local connMD = character:GetLandlineConnection()
    if (!istable(connMD) and !connMD["active"]) then
        -- probably ran hangup on a phone someone else was speaking on
        -- we should allow this in the future (maybe?) but for now we exit
        client:NotifyLocalized("You are not speaking on the phone.")
        return
    end

    -- terminate any existing connections here 
    local conn = self:GetActiveConnection(connMD["exchange"], connMD["extension"])
    if (!istable(conn)) then
        client:NotifyLocalized("Error: AttemptedHangupOnActivePhoneNoConn")
        -- This shouldn't be possible but if it happens then there is some lingering issue with
        -- this character's var being active when they are not in an active connection and
        -- the target entity being in use.
        -- This is an edge case and might happen if the connections table is reloaded or if something
        -- weird happens with the character's vars.
        character:SetLandlineConnection("landlineConnection", false)
        return
    end
    
    local recievers = self:getSourceRecieversFromConnection(
        conn["targetConnID"],
        conn["sourceNodeID"]
    )

    for _, recv in ipairs(recievers) do
        local _char = recv:GetCharacter()
        if (IsValid(_char)) then
            _char:SetLandlineConnection("landlineConnection", false)
        end
    end

    self:Disconnect(conn["targetConnID"])
end

-- returns whether or not the 'listener' is in an active phone call with 'speaker'
function ix.phone.switch:ListenerCanHearSpeaker(speaker, listener)
    local speakerChar = speaker:GetCharacter()
    local listeners = self:GetCharacterActiveListeners(speakerChar)
    if (!IsValid(listeners)) then
        -- doubly make sure that the call activity is set correctly on the caller
        speakerChar:SetLandlineConnection({
            active = false,
            exchange = nil,
            extension = nil
        })
        return false
    end

    for _, _listener in ipairs(listeners) do
        if (_listener == listener) then
            return true
        end
    end

    return false
end
