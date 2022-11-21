util.AddNetworkString("StartDial")

net.Receive("StartDial", function ()
    local dialSeq = net.ReadString()
    if (string.len(dialSeq) != 4 or tonumber(dialSeq) == nil) then
        return
    end
end)

-- PHONE CLEANUP
local function cleanupActivePhoneConnectionsForClient(client)
    local char = client:GetCharacter()
    if (IsValid(char) and char:GetVar("landlineConnection")["active"]) then
        ix.phone.switch:DisconnectActiveCallIfPresentOnClient(char)
    end
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
