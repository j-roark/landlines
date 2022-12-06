ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Landline Phone"
ENT.Author = "M!NT"
ENT.Category = "HL2 RP"
ENT.Contact = ""
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Holdable = true
ENT.offHook = false
ENT.inUseBy = nil
ENT.isRinging = false
ENT.defaultRingTime = 60  -- how long the phone will ring (in seconds)
ENT.endpointID = nil
ENT.ringCallback = nil
ENT.currentName = "Unknown" -- public name as stored currently in the PBX
ENT.currentPBX = 0          -- PBX this entity is attached to
ENT.currentExtension = nil  -- extension in the PBX

function ENT:GetIndicatorPos()
    local btnPos = self:GetPos()
    
    btnPos = btnPos + self:GetForward() * 4.3
    btnPos = btnPos + self:GetRight() * -1.1
    btnPos = btnPos + self:GetUp() * 2.0

    return btnPos
end

if SERVER then
    util.AddNetworkString("UpdateLandlineEntStatus")
    util.AddNetworkString("EnterLandlineDial")

    function ENT:Initialize()
        self:SetModel("models/props/cs_office/phone.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end

        self.endpointID = ix.phone.switch.endpoints:Register(self)
        self.currentExtension = math.random(100, 999)

        self:CallOnRemove("OnRemoveLandlineCleanup", function(ent)
            if (self.currentExtension and self.currentPBX) then
                return
            end

            local connID = ix.phone.switch:GetActiveConnection(extID, extNum)
            if (connID) then
                ix.phone.switch:Disconnect(connID, true)
            end
        end)
    end

    function ENT:PerformPickup(client)
        if timer.Exists("ixCharacterInteraction" .. client:SteamID()) then return end

        client:PerformInteraction(.5, self, function(_)
            client:GetCharacter():GetInventory():Add("landline")
            self:Remove()
        end)
    end
 
    function ENT:Use(activator)
        if (self.nextUse and self.nextUse > CurTime()) then
            return
        end
        
        self.nextUse = CurTime() + 1

        if activator:KeyDown(IN_WALK) then
            return self:PerformPickup(activator)
        end

        if (self.isRinging) then
            self.inUseBy = activator
            self:pickupDuringRing()
        elseif (!self.offHook) then
            self.inUseBy = activator
            net.Start("EnterLandlineDial")
                net.WriteInt(tonumber(self.endpointID), 15)
                net.WriteInt(tonumber(self.currentPBX), 5)
                net.WriteInt(tonumber(self.currentExtension), 11)
                net.WriteString(self.currentName)
            net.Send(activator)
            
            self:SetModel("models/props/cs_office/phone_p1.mdl")
            self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)
            
            self.inUseBy:GetCharacter():SetLandlineConnection({
                active = true,
                exchange = self.currentPBX,
                extension = self.currentExtension
            })
        end
	end

    function ENT:GetEndpointID()
        return self.endpointID
    end

    function ENT:EnterRing(callback)
        self:EmitSound("landline_ringtone.wav", 60, 100, 1, CHAN_STATIC)
        self.isRinging = true
        self.ringCallback = callback

        self:broadcastStatusOnChange()

        timer.Create("PhoneRinging"..self.endpointID, self.defaultRingTime, 1, function ()
            -- phone has rung too long
            self.isRinging = false
            self.offHook = false
            self:broadcastStatusOnChange()

            local _, _ = pcall(self.ringCallback, false)
            self.ringCallback = nil
        end)
    end

    function ENT:pickupDuringRing()
        self:SetModel("models/props/cs_office/phone_p1.mdl")

        if (!self.isRinging or !timer.Exists("PhoneRinging"..self.endpointID)) then
            return nil
        end

        timer.Remove("PhoneRinging"..self.endpointID)
        self:StopSound("landline_ringtone.wav")
        self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)

        self.isRinging = false
        self.offHook = true
        self:broadcastStatusOnChange()

        local _, _ = pcall(self.ringCallback, true)
        self.ringCallback = nil

        self.inUseBy:GetCharacter():SetLandlineConnection({
            active = true,
            exchange = currentPBX,
            extension = currentExtension
        })
    end

    function ENT:hangupDuringRing()
        if (!self.isRinging or !timer.Exists("PhoneRinging"..self.endpointID)) then
            return nil
        end

        timer.Remove("PhoneRinging"..self.endpointID)
        self:StopSound("landline_ringtone.wav")
        self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)

        self.isRinging = false
        self.offHook = false
        self:broadcastStatusOnChange()

        local _, _ = pcall(self.ringCallback, false)
    end

    function ENT:HangUp()
        self:SetModel("models/props/cs_office/phone.mdl")

        if (!self.isRinging and !self.offHook) then
            self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)
            return
        end

        if (self.offHook) then
            self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)
            
            self.inUseBy:GetCharacter():SetLandlineConnection({
                active = false,
                exchange = nil,
                extension = nil
            })
            self.offHook = false
            
            self:broadcastStatusOnChange()
        end

        if (self.isRinging) then
            self:hangupDuringRing()
        end
    end

    function ENT:InUse()
        return self.offHook
    end

    function ENT:IsRinging()
        return self.isRinging
    end

    function ENT:broadcastStatusOnChange()
        net.Start("UpdateLandlineEntStatus")
            net.WriteBool(self.isRinging)
            net.WriteBool(self.offHook)
            net.WriteInt(self.currentPBX, 11)
            net.WriteInt(self.currentExtension, 15)
        net.Broadcast()
    end
else
    local glowMaterial = ix.util.GetMaterial("sprites/glow04_noz")
    local color_green = Color(0, 255, 0, 255)
    local color_red = Color(255, 50, 50, 255)
    local isRinging = false
    local offHook = false
    local lastFlashTime = CurTime()
    local nextFlashTime = CurTime()

    net.Receive("UpdateLandlineEntStatus", function()
        isRinging = net.ReadBool()
        offHook = net.ReadBool()
        
        -- reset the indicator status flashing
        color_red.a = 255
        if (isRinging) then
            nextFlashTime = CurTime() + 1
        end
    end)

    function ENT:Draw()
        self:DrawModel()

        local btnPos = self:GetIndicatorPos()

        render.SetMaterial(glowMaterial)

        if (isRinging) then
            -- slow flash
            if (CurTime() > nextFlashTime) then
                color_red.a = 255
                if (CurTime() > nextFlashTime + 0.5) then
                    nextFlashTime = CurTime() + 0.5
                end
            else
                color_red.a = 0
            end
            render.DrawSprite(btnPos, 1, 1, color_red)
        elseif (offHook) then
		    render.DrawSprite(btnPos, 1, 1, color_red)
        else
            render.DrawSprite(btnPos, 1, 1, color_green)
        end
    end
end
