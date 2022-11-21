
local PLUGIN = PLUGIN
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

	self:SetSize(500, 800)
	self:Center()
	self:SetBackgroundBlur(true)
	self:SetDeleteOnClose(true)
	self:SetTitle(L(" "))

	self.dialSeqText = self:Add("DLabel")
	self.dialSeqText:Dock(TOP)
	self.dialSeqText:DockMargin(0, 4, 0, 0)
	self.dialSeqText:SetText(L(""))
	self.dialSeqText:SetHeight(50)
	self.dialSeqText:SetFont("DermaLarge")
	self.dialSeqText:CenterHorizontal()
	self.dialSeqText:SetColor(Color(0, 255, 0))
	self.dialSeqText:SetContentAlignment(5)

	self.close = self:Add("DButton")
	self.close:Dock(BOTTOM)
	self.close:DockMargin(0, 4, 0, 0)
	self.close:SetText(L("close"))
	self.close:SetHeight(50)
	self.close.DoClick = function()
		self:Close()
	end

	self.dial = self:Add("DButton")
	self.dial:Dock(BOTTOM)
	self.dial:DockMargin(0, 4, 0, 0)
	self.dial:SetText(L("Dial"))
	self.dial:SetColor(Color(0, 255, 0))
	self.dial:SetHeight(50)
	self.dial.DoClick = function()
		-- TODO: Actually start the dialing process here
		self:Close()
	end

	self.reset = self:Add("DButton")
	self.reset:Dock(BOTTOM)
	self.reset:DockMargin(0, 4, 0, 0)
	self.reset:SetText(L("Reset"))
	self.reset:SetColor(Color(255, 0, 0))
	self.reset:SetHeight(50)
	self.reset.DoClick = function()
		dialSeq:reset()
		self.dialSeqText:SetText(L(""))
	end

	self.numberGrid = self:Add("DGrid")
	self.numberGrid:SetPos(55, 100)
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
			self.dialSeqText:SetText(L("#"..dialSeq:asStr()))
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

vgui.Register("ixLandlineDial", PANEL, "DFrame")
