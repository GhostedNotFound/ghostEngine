ghostengine.log("Adding old experimental functions.")

ghostengine.exp_CopyLayer = function (fromLayer, toLayer, deleteFromLayer)
    if ghostengine.layers[fromLayer] and ghostengine.layers[toLayer] then
        ghostengine.log("Copying items from layer "..fromLayer.." to layer "..toLayer)
        ghostengine.layers[toLayer] = ghostengine.layers[fromLayer]
        if deleteFromLayer then
            ghostengine.log("Deleted ghostengine.layers."..fromLayer)
            ghostengine.layers[fromLayer] = nil
        end
        return ghostengine.layers[toLayer]
    else
        ghostengine.log("Attempted to copy from layer ".. fromLayer .." to layer "..toLayer.." and failed.")
    end
end

ghostengine.log("ghostengine.exp_CopyLayer: OK")

ghostengine.log("Successfully added all experimental functions.")