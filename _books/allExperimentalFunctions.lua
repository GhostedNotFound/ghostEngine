function exp_CopyLayer(fromLayer, toLayer, deleteFromLayer)
    if Layers[fromLayer] and Layers[toLayer] then
        print("Copying items from layer",fromLayer,"to layer",toLayer)
        Layers[toLayer] = Layers[fromLayer]
        if deleteFromLayer then
            print("Deleted Layers."..fromLayer)
            Layers[fromLayer] = nil
        end
        return Layers[toLayer]
    else
        print("Attempted to copy from layer", fromLayer , "to layer", toLayer, "and failed.")
    end
end