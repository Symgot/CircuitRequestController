local CircuitRequestController = require("circuit-request-controller")

-- Initialize mod when first loaded
script.on_init(function()
    CircuitRequestController.init()
end)

-- Handle configuration changes (mod updates)
script.on_configuration_changed(function()
    CircuitRequestController.init()
end)

-- Handle entity built events
script.on_event(defines.events.on_built_entity, function(event)
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        -- Controller built, no special action needed yet
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        -- Controller built by robot, no special action needed yet
    end
end)

script.on_event(defines.events.on_space_platform_built_entity, function(event)
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        -- Controller built on platform, no special action needed yet
    end
end)

-- Handle entity mined events
script.on_event(defines.events.on_player_mined_entity, function(event)
    if event.entity.name == "circuit-request-controller" then
        CircuitRequestController.unregister_controller(event.entity.unit_number)
    end
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    if event.entity.name == "circuit-request-controller" then
        CircuitRequestController.unregister_controller(event.entity.unit_number)
    end
end)

script.on_event(defines.events.on_space_platform_mined_entity, function(event)
    if event.entity.name == "circuit-request-controller" then
        CircuitRequestController.unregister_controller(event.entity.unit_number)
    end
end)

-- Handle entity destroyed
script.on_event(defines.events.on_entity_died, function(event)
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        CircuitRequestController.unregister_controller(event.entity.unit_number)
    end
end)

-- Handle GUI events
script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        -- Try to use SpaceShipMod's GUI if available
        if remote.interfaces["SpaceShipMod"] and remote.interfaces["SpaceShipMod"]["create_circuit_controller_gui"] then
            remote.call("SpaceShipMod", "create_circuit_controller_gui", player, event.entity)
        else
            -- Fallback: show a simple message
            player.print("[Circuit Request Controller] GUI not available. Install SpaceShipMod for full GUI support.")
        end
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        if player.gui.screen["circuit-controller-gui"] then
            player.gui.screen["circuit-controller-gui"].destroy()
        end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- Try to use SpaceShipMod's GUI handler if available
    if remote.interfaces["SpaceShipMod"] and remote.interfaces["SpaceShipMod"]["handle_circuit_controller_buttons"] then
        remote.call("SpaceShipMod", "handle_circuit_controller_buttons", event)
    end
end)

-- Process all circuit controllers periodically
script.on_event(defines.events.on_tick, function(event)
    if game.tick % 60 == 0 then
        CircuitRequestController.process_controllers(game.tick)
    end
    
    -- Periodic cleanup (every 5 minutes)
    if game.tick % 18000 == 0 then
        CircuitRequestController.cleanup()
    end
end)

-- Provide remote interface for other mods to interact with this mod
remote.add_interface("CircuitRequestController", {
    -- Get module reference for other mods
    get_module = function()
        return CircuitRequestController
    end,
    
    -- Create a logistics group
    create_logistics_group = function(platform, name)
        return CircuitRequestController.create_logistics_group(platform, name)
    end,
    
    -- Delete a logistics group
    delete_logistics_group = function(group_id)
        return CircuitRequestController.delete_logistics_group(group_id)
    end,
    
    -- Get all logistics groups for a platform
    get_platform_groups = function(platform)
        return CircuitRequestController.get_platform_groups(platform)
    end,
    
    -- Register a circuit controller
    register_controller = function(controller_entity, group_id, target_planet)
        return CircuitRequestController.register_controller(controller_entity, group_id, target_planet)
    end,
    
    -- Unregister a circuit controller
    unregister_controller = function(controller_unit_number)
        return CircuitRequestController.unregister_controller(controller_unit_number)
    end,
    
    -- Get controller data
    get_controller = function(controller_unit_number)
        return CircuitRequestController.get_controller(controller_unit_number)
    end,
    
    -- Check if a group is locked
    is_group_locked = function(group_id)
        return CircuitRequestController.is_group_locked(group_id)
    end,
    
    -- Get logistics group data
    get_group = function(group_id)
        return CircuitRequestController.get_group(group_id)
    end
})
