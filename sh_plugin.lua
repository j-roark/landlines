local PLUGIN = PLUGIN

PLUGIN.name = "Phones"
PLUGIN.description = "Adds landlines, pagers, and ways to route them"
PLUGIN.author = "M!NT"

ix.phone = ix.phone or {}

ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("sv_plugin.lua")

CAMI.RegisterPrivilege({
	Name = "Helix - Use Phones",
	MinAccess = "user"
})

ix.command.Add("HangupPhone", {
    alias = "HP",
    description = "Hangs up the phone you're looking at.",
    arguments = {},
    privilege = "Use Phones",
    OnRun = function(self, client)
        PLUGIN:runHangupOnClient(client)
    end
})

CAMI.RegisterPrivilege({
	Name = "Helix - Manage Phones",
	MinAccess = "admin"
})

ix.command.Add("EditLandline", {
    description = "Edit the landline phone you are currently looking at.",
    arguments = {
        ix.type.number,
        ix.type.number,
        ix.type.text
    },
    privilege = "Manage Phones",
    OnRun = function(self, client, pbx, extension, publicName)
        if (!pbx or !extension or !publicName or string.len(publicName) < 1) then
            client:NotifyLocalized("You provided an invalid argument")
        end

        -- perform input validations
        if (pbx < 1 or pbx > 9) then
            client:NotifyLocalized("Provided PBX is invalid! (must be a number between 1 and 10)")
            return
        end

        if (!ix.phone.switch:ExchangeExists(pbx)) then
            client:NotifyLocalized("Provided PBX '"..tostring(pbx).."' does not exist.")
            return
        end

        if (extension < 100 or extension > 999) then
            client:NotifyLocalized("Provided extension is invalid! (must be a number between 100 and 1000")
            return
        end

        if (string.len(publicName) < 1) then
            client:NotifyLocalized("Provided public name is invalid! (must have a length greater than 1)")
            return
        end

        local data = {}
            data.start = client:GetShootPos()
            data.endpos = data.start + client:GetAimVector() * 96
            data.filter = client
        local target = util.TraceLine(data).Entity

        if (!IsValid(target) or target.PrintName != "Landline Phone") then
            client:NotifyLocalized("You are not looking at a phone.")
            return
        end

        if (ix.phone.switch:DestExists(target.currentPBX, target.currentExtension)) then
            ix.phone.switch:RmDest(target.currentPBX, target.currentExtension)
        end

        if (!ix.phone.switch:AddDest(pbx, extension, publicName, target.endpointID)) then
            client:NotifyLocalized("Could not register the phone with the provided arguments")
            return
        end

        target.currentName      = publicName
        target.currentPBX       = pbx
        target.currentExtension = extension

        client:NotifyLocalized("You have successfully updated the landline.")
    end
})

ix.command.Add("AddPBX", {
    description = "Add new PBX if one does not already exist",
    arguments = {ix.type.number},
    privilege = "Manage Phones",
    OnRun = function(self, client, pbx)
        if (!pbx or pbx < 1 or pbx > 9) then
            client:NotifyLocalized("Provided PBX is invalid! (must be a number between 1 and 10)")
            return
        end

        if (ix.phone.switch:AddExchange(pbx)) then
            client:NotifyLocalized("PBX '"..tostring(pbx).."' was created succesfully!")
        else
            client:NotifyLocalized("PBX '"..tostring(pbx).."' already exists!")
            return
        end
    end
})

ix.command.Add("RemovePBX", {
    description = "Remove an existing PBX (will stop all active calls on this PBX and deregister all phones currently connected!)",
    arguments = {ix.type.number},
    privilege = "Manage Phones",
    OnRun = function(self, client, pbx)
        if (!pbx or pbx < 1 or pbx > 9) then
            client:NotifyLocalized("Provided PBX is invalid! (must be a number between 1 and 10)")
            return
        end
        
        if (!ix.phone.switch:ExchangeExists(pbx)) then
            client:NotifyLocalized("PBX '"..tostring(pbx).."' does not exist!")
            return
        end

        -- stop all active connections
        for ext, md in ipairs(ix.phone.switch.exchanges[pbx]) do
            local connMd = ix.phone.switch:GetActiveConnection(pbx, ext)
            if (IsValid(connMd)) then
                local recvs = ix.phone.switch:getSourceRecieversFromConnection(
                    connMd["targetConnId"],
                    connMd["sourceNodeID"]
                )

                for _, dest in ipairs(recv) do
                    ix.phone.switch.endpoints:GetEndpoint(dest["endID"]):HangUp()
                end
            end
        end

        ix.phone.switch:RmExchange(pbx)
        
        client:NotifyLocalized("PBX '"..tostring(pbx).."' has been deconstructed.")
    end
})

ix.char.RegisterVar("landlineConnection", {
	field = "landlineConnection",
	fieldType = ix.type.table,
	default = {
        active = false,
        exchange = nil,
        extension = nil
    },
	bNoDisplay = true,
	isLocal = true,
	OnSet = function(self, value)
		local client = self:GetPlayer()

        if (!IsValid(client)) then
            return nil
        end

        net.Start("ixConnectedCallStatusChange")
            net.WriteBool(value["active"])
        net.Send(client)

        self.vars.landlineConnection = {
            active = value["active"],
            exchange = value["exchange"],
            extension = value["extension"]
        }
	end,
	OnGet = function(self, default)
        local connMetaData = self.vars.landlineConnection
        return connMetaData
	end,
    OnAdjust = function(self, client, data, value, newData)
		newData.landlineConnection = value
	end
})

do
    local phoneChatCommands = {
        phonesay = {
            alias = "PS",
            description = "Speak into a phone if you're holding one."
        },
        phonewhisper = {
            alias = "PW",
            description = "Whisper into a phone if you're holding one."
        },
        phoneyell = {
            alias = "PY",
            description = "Yell into a phone if you're holding one."
        }
    }

    for phoneChatCommand, commandSettings in pairs(phoneChatCommands) do
        ix.command.Add(phoneChatCommand, {
            alias = commandSettings.alias,
            description = commandSettings.description,
            arguments = ix.type.text,
            privilege = "Use Phones",
            OnRun = function(self, client, message)
                if (client:GetCharacter():GetLandlineConnection()["active"]) then
                    ix.chat.Send(client, phoneChatCommand, message)
                end
            end
        })
    end
end

do
    -- used to simulate a distortion effect on certain letters when using phoneyell
    local chatDistortionChars = {
        O = "Ő̸̗",
        F = "F̸̲̂̉ ̷̖̇̀",
        P = "P̵̧̝̫̘͛͜F̶̆̃ ̴̩̫̎̌͜͝ ̴͈̈́",
        CK =  "C̴̣̖̕͜K̵̘̲͂̈́",
        K = "K̵̘̲͂̈́",
        T = "T̸̮͒͝͝",
        X = "Ẍ̷̻́_̷̛̰",
        S =  "S̷̥̓ ̶̖͂Ḣ̴̗ ̴̘̔",
        Z = "Z̶̗̒̃̅",
        S = "S̶͖̐̿ ̷̤̰͂͌",
        H = " ̵̬̻͇̎ ̵͈̦͍̔̅̊̇͝H"
    }
    -- TODO: get atle to add a real icon for this to willardcuntent
    local chatIcon = ix.util.GetMaterial("willardnetworks/chat/message_icon.png")
    local chatSettings = {
        phonewhisper = {
            range = ix.config.Get("chatRange", 280) / 4,
            color = Color(149, 196, 215),
            indicator = "chatWhispering",
            format = "[PHONE] %s: (whisper) \"%s\""
        },
        phonesay = {
            range = ix.config.Get("chatRange", 280),
            color = Color(105, 157, 178),
            indicator = "chatTalking",
            format = "[PHONE] %s: \"%s\""
        },
        phoneyell = {
            range = ix.config.Get("chatRange", 280) * 4,
            color = Color(166, 89, 89),
            indicator = "chatYelling",
            format = "[PHONE] %s: \"%s\""
        }
    }

    for chatType, chatTypeData in pairs(chatSettings) do
        ix.chat.Register(chatType, {
            color = chatTypeData.color,
            indicator = chatTypeData.indicator,
            format = chatTypeData.format,
            CanSay = function(self, speaker, text)
                return speaker:GetCharacter():GetLandlineConnection()["active"]
            end,
            CanHear = function(self, speaker, listener)
                if (ix.phone.switch:ListenerCanHearSpeaker(speaker, listener)) then
                    return true
                else
                    return chatSettings[chatType].range
                end
            end,
            OnChatAdd = function(self, speaker, text, anonymous, data)
                local name = "Someone"

                if (speaker == LocalPlayer()) then
                    name = "You"
                end
        
                if (!anonymous) then
                    local _recogName = hook.Run("GetCharacterName", speaker, "ic")
                    if (_recogName) then
                        name = _recogName
                    end
                end

                local rText = ix.chat.Format(text)
                if (chatType == "phoneyell") then
                    rText = rText:upper()
                    for char, repl in pairs(chatDistortionChars) do
                        rText = rText:gsub(tostring(char), tostring(repl))
                    end

                    -- ix.chat.Format() will always add punctuation. 
                    -- Replace that with an exclamation mark for greater affect :)
                    rText = rText:sub(1, -2)
                    rText = rText.."!"
                end
                rText = string.format(chatTypeData.format, name, rText)

                if (ix.option.Get("standardIconsEnabled")) then
                    chat.AddText(chatIcon, self.color, rText)
                else
                    chat.AddText(self.color, rText)
                end
            end
        })
    end
end
