local CircuitRequestController = require("circuit-request-controller")

-- Entity name filter for all events involving circuit-request-controller
local entity_filter = {{filter = "name", name = "circuit-request-controller"}}

-- Initialize mod when first loaded
script.on_init(function()
    CircuitRequestController.init()
end)

-- Handle configuration changes (mod updates)
script.on_configuration_changed(function()
    CircuitRequestController.init()
end)

-- Handle entity built events with entity filter for better performance
script.on_event(defines.events.on_built_entity, function(event)
    -- Controller built, no special action needed yet
end, entity_filter)

script.on_event(defines.events.on_robot_built_entity, function(event)
    -- Controller built by robot, no special action needed yet
end, entity_filter)

script.on_event(defines.events.on_space_platform_built_entity, function(event)
    -- Controller built on platform, no special action needed yet
end, entity_filter)

-- Handle entity mined events with entity filter for better performance
script.on_event(defines.events.on_player_mined_entity, function(event)
    CircuitRequestController.unregister_controller(event.entity.unit_number)
end, entity_filter)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    CircuitRequestController.unregister_controller(event.entity.unit_number)
end, entity_filter)

script.on_event(defines.events.on_space_platform_mined_entity, function(event)
    CircuitRequestController.unregister_controller(event.entity.unit_number)
end, entity_filter)

-- Handle entity destroyed with entity filter for better performance
script.on_event(defines.events.on_entity_died, function(event)
    CircuitRequestController.unregister_controller(event.entity.unit_number)
end, entity_filter)

-- Handle GUI events
script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        -- Close the default entity GUI that was opened
        player.opened = nil
        
        -- Try to use SpaceShipMod's GUI if available
        if remote.interfaces["SpaceShipMod"] and remote.interfaces["SpaceShipMod"]["create_circuit_controller_gui"] then
            remote.call("SpaceShipMod", "create_circuit_controller_gui", player, event.entity)
        else
            -- Use built-in GUI
            CircuitRequestController.create_gui(player, event.entity)
        end
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Handle closing of our custom GUIs (screen elements)
    if event.element and event.element.valid then
        if event.element.name == "circuit-controller-gui" then
            event.element.destroy()
            -- Clean up player-specific GUI storage
            if storage.gui_controllers then
                storage.gui_controllers[player.index] = nil
            end
        elseif event.element.name == "item-edit-gui" then
            event.element.destroy()
            -- Clean up edit item storage
            if storage.gui_edit_items then
                storage.gui_edit_items[player.index] = nil
            end
        end
    end
    
    -- Handle entity GUI closed (shouldn't happen since we override it, but just in case)
    if event.entity and event.entity.valid and event.entity.name == "circuit-request-controller" then
        if player.gui.screen["circuit-controller-gui"] then
            player.gui.screen["circuit-controller-gui"].destroy()
        end
        if player.gui.screen["item-edit-gui"] then
            player.gui.screen["item-edit-gui"].destroy()
        end
        -- Clean up player-specific GUI storage
        if storage.gui_controllers then
            storage.gui_controllers[player.index] = nil
        end
        if storage.gui_edit_items then
            storage.gui_edit_items[player.index] = nil
        end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- Try to use SpaceShipMod's GUI handler if available
    if remote.interfaces["SpaceShipMod"] and remote.interfaces["SpaceShipMod"]["handle_circuit_controller_buttons"] then
        remote.call("SpaceShipMod", "handle_circuit_controller_buttons", event)
    else
        CircuitRequestController.handle_gui_click(event)
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    CircuitRequestController.handle_gui_checked_state_changed(event)
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    CircuitRequestController.handle_gui_text_changed(event)
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
    CircuitRequestController.handle_gui_confirmed(event)
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
    end,
    
    -- Set default buffer multiplier for a controller
    set_controller_buffer_multiplier = function(controller_unit_number, multiplier)
        return CircuitRequestController.set_controller_buffer_multiplier(controller_unit_number, multiplier)
    end,
    
    -- Set item-specific override
    set_item_override = function(controller_unit_number, item_name, override_data)
        return CircuitRequestController.set_item_override(controller_unit_number, item_name, override_data)
    end,
    
    -- Remove item override
    remove_item_override = function(controller_unit_number, item_name)
        return CircuitRequestController.remove_item_override(controller_unit_number, item_name)
    end,
    
    -- Get all item overrides
    get_item_overrides = function(controller_unit_number)
        return CircuitRequestController.get_item_overrides(controller_unit_number)
    end,
    
    -- Update multipliers for a locked group (without changing items)
    update_group_multipliers = function(group_id, item_multipliers)
        return CircuitRequestController.update_group_multipliers(group_id, item_multipliers)
    end,
    
    -- Enable/disable specific items in a group
    set_item_enabled = function(group_id, item_name, enabled)
        return CircuitRequestController.set_item_enabled(group_id, item_name, enabled)
    end,
    
    -- Check if an item is enabled in a group
    is_item_enabled = function(group_id, item_name)
        return CircuitRequestController.is_item_enabled(group_id, item_name)
    end
})
