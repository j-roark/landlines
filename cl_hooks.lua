local PLUGIN = PLUGIN
PLUGIN.landlineID = 1

function PLUGIN:setCurrentLandlineID(serverEntID)
	self.landlineID = serverEntID
end

netstream.Hook("EnterLandlineDial", function(serverEntID)
	vgui.Create("ixLandlineDial")
	PLUGIN:setCurrentLandlineID(serverEntID)
end)

