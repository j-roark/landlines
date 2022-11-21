
PLUGIN.name = "Phones"
PLUGIN.description = "Adds landlines, pagers, and ways to route them"
PLUGIN.author = "M!NT"

ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("sv_plugin.lua")

ix.command.Add("HangupPhone", {
    description = "Hangs up the phone you're looking at.",
    arguments = {},
    OnRun = function(self, client)
        local data = {}
            data.start = client:GetShootPos()
            data.endpos = data.start + client:GetAimVector() * 96
            data.filter = client
        local target = util.TraceLine(data).Entity

        if (!IsValid(target) or target.PrintName != "Landline Phone") then
            client:NotifyLocalized("You are not looking at a phone.")
            return
        end

        target:HangUp()
        if (target:InUse()) then
            ix.phone.switch:DisconnectActiveCallIfPresentOnClient(client)
        end
    end
})

ix.command.Add("Phone", {
    description = "Speak into a phone if you're holding one.",
    arguments = ix.type.text,
    OnRun = function(self, client, message)
        local char = client:GetCharacter()
        if (!IsValid(char)) then
            return nil
        end

        if (!character.vars.landlineConnection["active"]) then
            client:NotifyLocalized("You are not in an active phone call.")
            return
        end

        local listeners = ix.phone.switch:GetCharacterActiveListeners(char)
        if (!IsValid(listeners)) then
            return nil
        end
    end
})

ix.command.Add("PhoneWhisper", {
    description = "Whisper into a phone if you're holding one.",
    arguments = ix.type.text,
    OnRun = function(self, client, message)
        local char = client:GetCharacter()
        if (!IsValid(char)) then
            return
        end

        if (!character.vars.landlineConnection["active"]) then
            client:NotifyLocalized("You are not in an active phone call.")
            return
        end

        local listeners = ix.phone.switch:GetCharacterActiveListeners(char)
        if (!IsValid(listeners)) then
            return
        end
    end
})

ix.char.RegisterVar("landlineConnection", {
	field = "landlineConnection",
	fieldType = ix.type.table,
	default = {},
	bNoDisplay = true,
	isLocal = true,
	OnSet = function(character, status, exchange, extension)
		local client = character:GetPlayer()

        if (!IsValid(client)) then
            return nil
        end

        net.Start("ixConnectedCallStatusChange")
            net.WriteBool(status)
        net.Send(client)

        character.vars.landlineConnection = {}
        character.vars.landlineConnection["active"] = status
        if (status) then
            character.vars.landlineConnection["exchange"] = exchange
            character.vars.landlineConnection["extension"] = extension
        else
            character.vars.landlineConnection["exchange"] = nil
            character.vars.landlineConnection["extension"] = nil
        end
	end,
	OnGet = function(character)
        return character.vars.landlineConnection
	end
})
