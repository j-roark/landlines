
local PLUGIN = PLUGIN
PLUGIN.offHook = false
PLUGIN.otherSideRinging    = false
PLUGIN.otherSideActive     = false
PLUGIN.currentCallStatus   = "PENDING"
PLUGIN.currentCallPeerName = "Unknown"

local dialSeq = {}
local buttonMap = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"}

local PANEL = {}

function dialSeq:insert(signal) 
	self[#self+1] = signal
end

function dialSeq:reset() 
	for k, signal in ipairs(self) do
		self[k] = nil
	end
end

function dialSeq:asStr()
	local dialSeqStr = ""
	for _, signal in ipairs(self) do
		dialSeqStr = dialSeqStr..signal
	end
	return dialSeqStr
end

function dialSeq:playDTMFTone(signal)
	local _signal = signal
	if (signal == "*") then _signal = "asterisk" end
	if (signal == "#") then _signal = "pound" end

	surface.PlaySound("dtmftones/dtmfgen_".._signal..".wav")
end

function PANEL:Init()
	if (IsValid(PLUGIN.panel)) then
		PLUGIN.panel:Remove()
	end

	self:SetSize(600, 1100)
	self:Center()
	self:SetBackgroundBlur(true)
	self:SetDeleteOnClose(true)
	self:SetTitle(L(" "))
	self:ShowCloseButton(false)
	self:IsDraggable(false)

	self.verStamp = self:Add("DLabel")
	self.verStamp:Dock(TOP)
	self.verStamp:DockMargin(0, -3, 115, 0)
	self.verStamp:SetFont("DermaDefaultBold")
	self.verStamp:SetHeight(30)
	self.verStamp:SetColor(Color(215, 240, 231))
	self.verStamp:SetText(L("UU penOS BETA v0.254ga - NODEID - "..tostring(PLUGIN.targetedLandlineEndpointID)))
	self.verStamp:SetContentAlignment(9)

	self.status = self:Add("DLabel")
	self.status:Dock(TOP)
	self.status:DockMargin(0, -10, 0, 0)
	self.status:SetFont("DermaDefaultBold")
	self.status:SetHeight(30)
	self.status:SetColor(Color(215, 240, 231))
	local _connStatus = "DISCONNECTED!"
	local _curPBX = "N/A"
	if (PLUGIN.targetedLandlinePBX and PLUGIN.targetedLandlinePBX > 0) then
		_connStatus = "ACTIVE"
		_curPBX = "0"..tostring(PLUGIN.targetedLandlinePBX)
	end
	self.status:SetText(L("Connection Status: ".._connStatus))
	self.status:SetContentAlignment(5)

	self.name = self:Add("DLabel")
	self.name:Dock(TOP)
	self.name:DockMargin(0, 4, 125, 0)
	self.name:SetText(L(tostring(PLUGIN.targetedLandlineName)))
	self.name:SetHeight(35)
	self.name:SetFont("CloseCaption_Bold")
	self.name:SetColor(Color(15, 13, 44, 220))
	self.name:SetContentAlignment(9)

	self.pBX = self:Add("DLabel")
	self.pBX:Dock(TOP)
	self.pBX:DockMargin(125, 4, 0, 0)
	self.pBX:SetText(L("PBX   :> ".._curPBX))
	self.pBX:SetHeight(35)
	self.pBX:SetFont("CloseCaption_Bold")
	self.pBX:SetColor(Color(15, 13, 44, 220))
	self.pBX:SetContentAlignment(7)

	self.ext = self:Add("DLabel")
	self.ext:Dock(TOP)
	self.ext:DockMargin(125, 4, 0, 0)
	self.ext:SetText(L("EXT   :> "..tostring(PLUGIN.targetedLandlineExt)))
	self.ext:SetHeight(35)
	self.ext:SetFont("CloseCaption_Bold")
	self.ext:SetColor(Color(15, 13, 44, 220))
	self.ext:SetContentAlignment(7)

	self.dialSeqText = self:Add("DLabel")
	self.dialSeqText:Dock(TOP)
	self.dialSeqText:DockMargin(125, 4, 0, 0)
	self.dialSeqText:SetText(L("DIAL :> "))
	self.dialSeqText:SetHeight(50)
	self.dialSeqText:SetFont("CloseCaption_Bold")
	self.dialSeqText:SetColor(Color(15, 13, 44, 220))
	self.dialSeqText:SetContentAlignment(7)

	self.close = self:Add("DButton")
	self.close:Dock(BOTTOM)
	self.close:DockMargin(0, 4, 0, 0)
	self.close:SetText(L("close"))
	self.close:SetHeight(50)
	self.close.DoClick = function()
		dialSeq:playDTMFTone("#")
		self:Close()

		PLUGIN.offHook = false
		PLUGIN.otherSideRinging    = false
		PLUGIN.otherSideActive     = false
		PLUGIN.currentCallStatus   = "PENDING"
		PLUGIN.currentCallPeerName = "Unknown"

		net.Start("RunHangupLandline")
		net.SendToServer()
	end

	self.dial = self:Add("DButton")
	self.dial:Dock(BOTTOM)
	self.dial:DockMargin(0, 4, 0, 0)
	self.dial:SetText(L("Dial"))
	self.dial:SetColor(Color(0, 255, 0))
	self.dial:SetHeight(50)
	self.dial.DoClick = function()
		net.Start("BeginDialToPeer")
			net.WriteString(dialSeq:asStr())
			net.WriteInt(PLUGIN.targetedLandlinePBX, 5)
			net.WriteInt(PLUGIN.targetedLandlineExt, 11)
		net.SendToServer()

		PLUGIN.offHook = true
		PLUGIN.otherSideRinging  = true
		PLUGIN.otherSideActive   = false
		PLUGIN.currentCallStatus = "RINGING"
	end

	self.reset = self:Add("DButton")
	self.reset:Dock(BOTTOM)
	self.reset:DockMargin(0, 4, 0, 0)
	self.reset:SetText(L("Reset"))
	self.reset:SetColor(Color(255, 0, 0))
	self.reset:SetHeight(50)
	self.reset.DoClick = function()
		dialSeq:reset()
		dialSeq:playDTMFTone("0")
		self.dialSeqText:SetText(L("DIAL :> "))
	end

	self.numberGrid = self:Add("DGrid")
	self.numberGrid:SetPos(110, 400)
	self.numberGrid:SetCols(3)
	self.numberGrid:SetColWide(130)
	self.numberGrid:SetRowHeight(130)
 
	for _, key in ipairs(buttonMap) do
		local button = vgui.Create("DButton")
		button:SetText(key)
		button:SetSize(130, 130)
		button:SetFont("DermaLarge")

		button.DoClick = function()
			dialSeq:playDTMFTone(key)
			dialSeq:insert(key)
			self.dialSeqText:SetText(L("DIAL :> "..dialSeq:asStr()))
		end

		self.numberGrid:AddItem(button)
	end
	
	self:MakePopup()

	PLUGIN.panel = self
end

function PANEL:OnRemove()
	PLUGIN.panel = nil
	dialSeq:reset()
end

function PANEL:Paint(w, h)
	-- background
	draw.RoundedBox(6, 0, 0, w, h, Color(35, 35, 45))
	-- "screen"
	draw.RoundedBox(6, 110, 10, 390, 350, Color(215, 240, 231))
	-- outline
	surface.SetDrawColor(15, 13, 44, 255)
	surface.DrawOutlinedRect(115, 20, 380, 320, 4)

	-- boxes:
	local drawOutlineBoxPair = function (x, y, w, h, thick, darker, black)
		surface.SetDrawColor(150, 150, 140, 100)
		if (darker) then
			surface.SetDrawColor(150, 150, 140, 150)
		end
		if (black) then
			surface.SetDrawColor(0, 0, 0, 255)
		end
		surface.DrawRect(x, y, w, h)
		surface.SetDrawColor(15, 13, 44, 255)
		surface.DrawOutlinedRect(x, y, w, h, thick)
	end
	-- top box
	drawOutlineBoxPair(117, 20, 376, 55, 3, false, true)
	-- name
	drawOutlineBoxPair(117, 75, 376, 38, 2)
	-- exchange
	drawOutlineBoxPair(117, 113, 376, 38, 2, true)
	-- ext
	drawOutlineBoxPair(117, 151, 376, 38, 2)
	-- dial
	drawOutlineBoxPair(117, 189, 376, 38, 2, true)
	-- status
	drawOutlineBoxPair(117, 285, 376, 55, 3, false, true)
	-- status text
	surface.SetFont("CloseCaption_Normal")
	surface.SetTextColor(215, 240, 231, 255)
	surface.SetTextPos(124, 290) 
	surface.DrawText("STATUS :> ")
	surface.SetFont("CloseCaption_Bold")
	surface.DrawText(tostring(PLUGIN.currentCallStatus))
	surface.SetTextPos(151, 313) 
	if (PLUGIN.otherSideActive == true) then
		surface.SetFont("CloseCaption_Normal")
		surface.DrawText("CONNECTED :> ")
		surface.DrawText(tostring(PLUGIN.currentCallPeerName))
		surface.SetFont("CloseCaption_Bold")
	end

	-- time text
	surface.SetTextColor(215, 240, 231, 255)
	surface.SetTextPos(124, 25)
	local ostime = os.time()
	surface.SetFont("DermaDefaultBold")
	surface.DrawText(os.date("%H:%M:%S", ostime))
	surface.SetTextPos(124, 40)
	surface.DrawText(os.date("%d/%m/%Y", ostime))
end

vgui.Register("ixLandlineDial", PANEL, "DFrame")
