-- this is a loose implementation of a virtual private business exchange (vPBX)
ix.phone = ix.phone or {}
ix.phone.switch = ix.phone.switch or {}


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

-- returns back a list of player entities that are listening to the phone this character is speaking into
function ix.phone.switch:GetCharacterActiveListeners(character)
    if (!IsValid(character)) then
        return
    end

    local connMD = character.GetLandlineConnection()
    if (!connMD) then
        return
    end
    
    return self:GetListeners(connMD["exchange"], connMD["extension"])
end

function ix.phone.switch:GetPlayerActiveListeners(client)
    local character = client:GetCharacter()
    if (!IsValid(character)) then
        return nil
    end

    return self:GetCharacterActiveListeners(character)
end

-- rudely hangs up every single active call related to this character
-- typically used when the player disconnects or switches chars mid call
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
