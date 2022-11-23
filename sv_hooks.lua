util.AddNetworkString("BeginDialToPeer")
util.AddNetworkString("ixConnectedCallStatusChange")

net.Receive("BeginDialToPeer", function (len, client)
    local dialSeq = net.ReadString()
    if (string.len(dialSeq) < 3 or string.len(dialSeq) > 4 or tonumber(dialSeq) == nil) then
        return
    end

    local exchange = net.ReadInt(5)
    local extension = net.ReadInt(11)
    local character = client:GetCharacter()
    local vars = character:GetLandlineConnection()
    
    -- verify that this is coming from the correct place (or that no one is trying to manually call the hook)
    if (vars["exchange"] != exchange and vars["extension"] != extension) then
        return
    end
    
    ix.phone.switch:Dial(exchange, extension, function(status)
        character:SetLandlineConnection({
            active = status,
            exchange = exchange,
            extension = extension
        })
    end, dialSeq)
end)

-- PHONE CLEANUP
local function cleanupActivePhoneConnectionsForClient(client)
    local char = client:GetCharacter()
    if (char:GetLandlineConnection()["active"]) then
        ix.phone.switch:DisconnectActiveCallIfPresentOnClient(char)
    end

    char:SetLandlineConnection({
        active = false,
        exchange = nil,
        extension = nil
    })
end

function PLUGIN:PlayerDisconnected(client)
    cleanupActivePhoneConnectionsForClient(client)
end

function PLUGIN:OnCharacterFallover(client, entity, bFallenOver)
    cleanupActivePhoneConnectionsForClient(client)
end

function PLUGIN:PlayerDeath(client)
    cleanupActivePhoneConnectionsForClient(client)
end

function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
    cleanupActivePhoneConnectionsForClient(client)
end
