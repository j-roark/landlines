local PLUGIN = PLUGIN

util.AddNetworkString("BeginDialToPeer")
util.AddNetworkString("ixConnectedCallStatusChange")
util.AddNetworkString("RunHangupLandline")
util.AddNetworkString("RunGetPeerName")
util.AddNetworkString("OnGetPeerName")

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

net.Receive("RunHangupLandline", function (len, client)
    PLUGIN:runHangupOnClient(client)
end)

net.Receive("RunGetPeerName", function (len, client)
    if (!client or !IsValid(client)) then
        return
    end

    local char = client:GetCharacter()
    local charMD = char:GetLandlineConnection()

    if (charMD.active) then
        if (!charMD.extension or !charMD.exchange) then
            return
        end

        listeners = ix.phone.switch:GetListeners(charMD.exchange, charMD.extension) 
        if (!listeners or #listeners < 1) then
            return
        end

        net.Start("OnGetPeerName")
            net.WriteString(listeners[0]["name"])
        net.Send(client)
    end
end)

function PLUGIN:runHangupOnClient(client)
    if (!client or !IsValid(client)) then
        return
    end
    local data = {}
        data.start = client:GetShootPos()
        data.endpos = data.start + client:GetAimVector() * 96
        data.filter = client
    local target = util.TraceLine(data).Entity

    if (!target or target.PrintName != "Landline Phone") then
        return
    end

    target:HangUp()
    if (target:InUse() or target:IsRinging()) then
        client:GetCharacter():SetLandlineConnection({
            active = false,
            exchange = target.currentPBX,
            extension = target.currentExtension
        })
        ix.phone.switch:DisconnectActiveCallIfPresentOnClient(client)
    end
end

-- PHONE CLEANUP
-- this function literally just dumps all current ongoing connections that happen to have this client in them
local function cleanupActivePhoneConnectionsForClient(client)
    if (!client or !IsValid(client)) then
        return
    end

    local char = client:GetCharacter()
    local charCallMD = nil
    -- why do I have to do all this checking?? UGH thanks helix
    if (char and char.GetLandlineConnection) then
        charCallMD = char:GetLandlineConnection()
    end
    if (istable(charCallMD) and charCallMD["active"]) then
        ix.phone.switch:DisconnectActiveCallIfPresentOnClient(client)
    end

    if (char) then
        char:SetLandlineConnection({
            active = false,
            exchange = nil,
            extension = nil
        })
    end
end

-- peak laziness:
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
