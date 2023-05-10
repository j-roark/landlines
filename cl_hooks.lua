local PLUGIN = PLUGIN
PLUGIN.targetedLandlineEndpointID = nil
PLUGIN.targetedLandlinePBX = nil
PLUGIN.targetedLandlineExt = nil
PLUGIN.targetedLandlineName = nil

net.Receive("EnterLandlineDial", function()
	PLUGIN.targetedLandlineEndpointID = net.ReadInt(15)
	PLUGIN.targetedLandlinePBX = net.ReadInt(5)
	PLUGIN.targetedLandlineExt = net.ReadInt(11)
	PLUGIN.targetedLandlineName = net.ReadString()

	vgui.Create("ixLandlineDial")
end)

net.Receive("ixConnectedCallStatusChange", function()
	local active = net.ReadBool()
	if (active) then
		PLUGIN.offHook = true
		PLUGIN.otherSideRinging  = false
		PLUGIN.currentCallStatus = "CONNECTED"	

		net.Start("RunGetPeerName")
		net.SendToServer()
		return 
	end
	
	PLUGIN.otherSideRinging    = false
	PLUGIN.otherSideActive     = false
	PLUGIN.currentCallStatus   = "DISCONNECTED"
	PLUGIN.currentCallPeerName = "Unknown"
end)

net.Receive("OnGetPeerName", function()
	PLUGIN.currentCallPeerName = net.ReadString()
end)
