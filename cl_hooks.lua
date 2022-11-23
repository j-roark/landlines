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

