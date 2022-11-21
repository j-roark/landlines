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
ENT.inUse = false
ENT.isRinging = false
ENT.defaultRingTime = 60 -- how long the phone will ring (in seconds)
ENT.endpointID = nil
ENT.ringCallback = nil

function ENT:GetIndicatorPos()
    local btnPos = self:GetPos()
    
    btnPos = btnPos + self:GetForward() * 4.3
    btnPos = btnPos + self:GetRight() * -1.1
    btnPos = btnPos + self:GetUp() * 2.0

    return btnPos
end

if SERVER then
    util.AddNetworkString("UpdateLandlineEntStatus")

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

        print("landline registered as: "..tostring(self.endpointID))
    end

    function ENT:PerformPickup(client)
        if timer.Exists("ixCharacterInteraction" .. client:SteamID()) then return end

        client:PerformInteraction(.5, self, function(_)
            client:GetCharacter():GetInventory():Add("landline")
            self:Remove()
        end)
    end

    function ENT:Use(activator)
        local curTime = CurTime()

        if (self.nextUse and self.nextUse > curTime) then
            return
        end
        if activator:KeyDown(IN_WALK) then
            return self:PerformPickup(activator)
        end

        if (self.isRinging) then
            self:pickupDuringRing()
            self.nextUse = curTime + 1
            return
        elseif (!self.inUse) then
            netstream.Start(activator, "EnterLandlineDial", self.endpointID)
            self.nextUse = curTime + 1
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
            self.inUse = false
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
        self.inUse = true
        self:broadcastStatusOnChange()

        local _, _ = pcall(self.ringCallback, true)
        self.ringCallback = nil
    end

    function ENT:hangupDuringRing()
        if (!self.isRinging or !timer.Exists("PhoneRinging"..self.endpointID)) then
            return nil
        end

        timer.Remove("PhoneRinging"..self.endpointID)
        self:StopSound("landline_ringtone.wav")
        self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)

        self.isRinging = false
        self.inUse = false
        self:broadcastStatusOnChange()

        local _, _ = pcall(self.ringCallback, false)
    end

    function ENT:HangUp()
        self:SetModel("models/props/cs_office/phone.mdl")

        if (!self.isRinging and !self.inUse) then
            self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)
            return
        end

        if (self.inUse) then
            self:EmitSound("landline_hangup.wav", 60, 100, 1, CHAN_STATIC)
            self.inUse = false
            self:broadcastStatusOnChange()
        end

        if (self.isRinging) then
            self:hangupDuringRing()
        end
    end

    function ENT:InUse()
        return self.inUse
    end

    function ENT:IsRinging()
        return self.isRinging
    end

    function ENT:broadcastStatusOnChange()
        net.Start("UpdateLandlineEntStatus")
            net.WriteBool(self.isRinging)
            net.WriteBool(self.inUse)
        net.Broadcast()
    end
else
    local glowMaterial = ix.util.GetMaterial("sprites/glow04_noz")
    local color_green = Color(0, 255, 0, 255)
    local color_red = Color(255, 50, 50, 255)
    local isRinging = false
    local inUse = false
    local lastFlashTime = CurTime()
    local nextFlashTime = CurTime()

    net.Receive("UpdateLandlineEntStatus", function()
        isRinging = net.ReadBool()
        inUse = net.ReadBool()
        
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
        elseif (inUse) then
		    render.DrawSprite(btnPos, 1, 1, color_red)
        else
            render.DrawSprite(btnPos, 1, 1, color_green)
        end
    end
end