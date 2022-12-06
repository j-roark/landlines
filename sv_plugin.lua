ix.phone = ix.phone or {}
ix.phone.switch = ix.phone.switch or {}

local PLUGIN = PLUGIN

function PLUGIN:RegisterSaveEnts()
    ix.saveEnts:RegisterEntity("landline_phone", true, true, true, {
        OnSave = function(entity, data) --OnSave
            data.endpointID = entity.endpointID
            data.extension  = entity.currentExtension
            data.exchange   = entity.currentPBX
            data.name       = entity.currentName
        end,
        OnRestore = function(entity, data) --OnRestore
            local exID = tonumber(data.exchange)
            local ext  = tonumber(data.extension)
            local name = data.name
            local lastEndID = tonumber(data.endpointID)
            if (!lastEndpointID) then
                return
            end

            local newEndID = ix.phone.switch.endpoints:Register(entity)
            if (newEndID) then 
                -- ent exists already as an endpoint
                return
            end
            entity.endpointID = newEndID

            if (!exID or !ext) then
                return
            end

            if (!ix.phone.switch:ExchangeExists(exID)) then
                ix.phone.switch:AddExchange(exID)
            end
            ix.phone.switch:AddDest(exID, ext, name, newEndID)
        end
    })
end
