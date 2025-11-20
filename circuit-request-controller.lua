--[[
    CircuitRequestController Module
    
    This module implements circuit network control for logistics groups.
    It allows platforms to have their transfer requests controlled by circuit signals.
    
    Features:
    - 1x1 combinator-like entity for circuit network integration
    - Logistics group management and selection
    - Planet selection for target transfers
    - Automatic request quantity updates from circuit signals
    - Minimum/Maximum inventory level support with buffer multipliers
    - Per-item override support for fine-grained control
    - Group locking when controlled by a circuit block
    - Only one block can control a group globally
    - Entities can remove/deactivate groups at any time
    - Built-in GUI for configuration (no external mod required)
    
    Minimum/Maximum Inventory Levels:
    - Circuit signals represent the MINIMUM requested quantity
    - Maximum quantity is calculated as: minimum × buffer_multiplier
    - Default buffer multiplier is 2.0 (configurable per controller)
    - Each item can have a custom buffer multiplier override
    - Or a fixed maximum quantity override
    - Entity-level overrides take priority over controller defaults
    
    Compatibility:
    - Works with Factorio 2.0 (with or without Space Age)
    - Space Age features (platforms) are optional
    - Compatible with TransferRequestSystem mod (optional)
]]

-- Import flib modules for better mod compatibility
local flib_gui = require("__flib__.gui")
-- local flib_table = require("__flib__.table")  -- Available for future use (array operations, deep_compare, etc.)

local CircuitRequestController = {}

-- Constants for configuration
local RED_WIRE_ID = 1  -- Red circuit network ID
local GREEN_WIRE_ID = 2  -- Green circuit network ID

-- Initialize storage for the module
function CircuitRequestController.init()
    storage.circuit_controllers = storage.circuit_controllers or {} -- Maps controller unit_number to controller data
    storage.logistics_groups = storage.logistics_groups or {} -- Maps group_id to group data
    storage.group_controllers = storage.group_controllers or {} -- Maps group_id to controller unit_number (for uniqueness check)
end

-- Create a new logistics group
-- Returns group_id or nil on failure
function CircuitRequestController.create_logistics_group(platform, name)
    if not platform or not platform.valid then return nil end
    
    storage.logistics_groups = storage.logistics_groups or {}
    
    -- Generate unique group ID
    local group_id = "group_" .. platform.index .. "_" .. game.tick
    
    storage.logistics_groups[group_id] = {
        id = group_id,
        name = name or "Logistics Group",
        platform_index = platform.index,
        requests = {}, -- Map of item_name -> {minimum_quantity, requested_quantity, maximum_quantity}
        locked = false, -- Whether group is locked by a circuit controller
        created_tick = game.tick,
        default_buffer_multiplier = 2.0 -- Default buffer multiplier for maximum = requested * multiplier
    }
    
    return group_id
end

-- Delete a logistics group
function CircuitRequestController.delete_logistics_group(group_id)
    if not group_id then return false end
    
    storage.logistics_groups = storage.logistics_groups or {}
    storage.group_controllers = storage.group_controllers or {}
    
    -- Remove the group
    storage.logistics_groups[group_id] = nil
    
    -- Remove controller assignment if any
    storage.group_controllers[group_id] = nil
    
    return true
end

-- Get all logistics groups for a platform
function CircuitRequestController.get_platform_groups(platform)
    if not platform or not platform.valid then return {} end
    
    storage.logistics_groups = storage.logistics_groups or {}
    
    local groups = {}
    for group_id, group in pairs(storage.logistics_groups) do
        if group.platform_index == platform.index then
            table.insert(groups, group)
        end
    end
    
    return groups
end

-- Register a circuit controller
-- Returns true on success, false and error message on failure
function CircuitRequestController.register_controller(controller_entity, group_id, target_planet)
    if not controller_entity or not controller_entity.valid then 
        return false, "Invalid controller entity"
    end
    
    if not group_id then
        return false, "No group ID specified"
    end
    
    storage.circuit_controllers = storage.circuit_controllers or {}
    storage.logistics_groups = storage.logistics_groups or {}
    storage.group_controllers = storage.group_controllers or {}
    
    local group = storage.logistics_groups[group_id]
    if not group then
        return false, "Group does not exist"
    end
    
    -- Check if another controller is already controlling this group
    local existing_controller_id = storage.group_controllers[group_id]
    if existing_controller_id and existing_controller_id ~= controller_entity.unit_number then
        -- Check if the existing controller still exists
        local existing_controller = storage.circuit_controllers[existing_controller_id]
        if existing_controller and existing_controller.entity and existing_controller.entity.valid then
            return false, "Group is already controlled by another circuit controller"
        else
            -- Old controller is gone, we can take over
            storage.group_controllers[group_id] = nil
        end
    end
    
    -- Register this controller
    storage.circuit_controllers[controller_entity.unit_number] = {
        entity = controller_entity,
        group_id = group_id,
        target_planet = target_planet or "nauvis",
        last_update_tick = 0,
        default_buffer_multiplier = 2.0, -- Default multiplier for maximum = requested * multiplier
        item_overrides = {} -- Per-item overrides: item_name -> {buffer_multiplier, maximum_quantity}
    }
    
    -- Mark group as controlled by this controller
    storage.group_controllers[group_id] = controller_entity.unit_number
    group.locked = true
    
    return true, "Controller registered successfully"
end

-- Unregister a circuit controller
function CircuitRequestController.unregister_controller(controller_unit_number)
    if not controller_unit_number then return false end
    
    storage.circuit_controllers = storage.circuit_controllers or {}
    storage.group_controllers = storage.group_controllers or {}
    storage.logistics_groups = storage.logistics_groups or {}
    
    local controller = storage.circuit_controllers[controller_unit_number]
    if not controller then return false end
    
    local group_id = controller.group_id
    
    -- Unlock the group
    if group_id and storage.logistics_groups[group_id] then
        storage.logistics_groups[group_id].locked = false
    end
    
    -- Remove controller assignment
    if group_id then
        storage.group_controllers[group_id] = nil
    end
    
    -- Remove controller data
    storage.circuit_controllers[controller_unit_number] = nil
    
    return true
end

-- Get controller data
function CircuitRequestController.get_controller(controller_unit_number)
    storage.circuit_controllers = storage.circuit_controllers or {}
    return storage.circuit_controllers[controller_unit_number]
end

-- Update a logistics group's requests from circuit signals
-- This is called when circuit signals change
function CircuitRequestController.update_group_from_signals(controller_unit_number, signals)
    storage.circuit_controllers = storage.circuit_controllers or {}
    storage.logistics_groups = storage.logistics_groups or {}
    
    local controller = storage.circuit_controllers[controller_unit_number]
    if not controller or not controller.entity or not controller.entity.valid then
        return false
    end
    
    local group = storage.logistics_groups[controller.group_id]
    if not group then
        return false
    end
    
    -- Clear existing requests
    group.requests = {}
    
    -- Process circuit signals
    -- Each signal represents an item and its requested quantity
    -- The signal value is the minimum requested quantity
    for _, signal in pairs(signals) do
        if signal.signal and signal.signal.type == "item" then
            local item_name = signal.signal.name
            local minimum_quantity = signal.count
            
            if minimum_quantity > 0 then
                -- Get buffer multiplier (controller override or default)
                local buffer_multiplier = controller.default_buffer_multiplier or 2.0
                if controller.item_overrides and controller.item_overrides[item_name] then
                    buffer_multiplier = controller.item_overrides[item_name].buffer_multiplier or buffer_multiplier
                end
                
                -- Calculate maximum quantity based on buffer multiplier
                local maximum_quantity = math.floor(minimum_quantity * buffer_multiplier)
                
                -- Check for item-specific maximum override
                if controller.item_overrides and controller.item_overrides[item_name] and controller.item_overrides[item_name].maximum_quantity then
                    maximum_quantity = controller.item_overrides[item_name].maximum_quantity
                end
                
                group.requests[item_name] = {
                    minimum_quantity = minimum_quantity,
                    requested_quantity = minimum_quantity, -- For compatibility
                    maximum_quantity = maximum_quantity
                }
            end
        end
    end
    
    controller.last_update_tick = game.tick
    
    return true
end

-- Synchronize group requests with the TransferRequest system
-- This applies the logistics group requests to the actual transfer system
-- Works only if TransferRequest mod is available
function CircuitRequestController.sync_group_to_transfer_system(group_id)
    storage.logistics_groups = storage.logistics_groups or {}
    
    local group = storage.logistics_groups[group_id]
    if not group then return false end
    
    -- Find the platform
    local platform = nil
    for _, force in pairs(game.forces) do
        for _, p in pairs(force.platforms) do
            if p.valid and p.index == group.platform_index then
                platform = p
                break
            end
        end
        if platform then break end
    end
    
    if not platform then return false end
    
    -- Try to load TransferRequest if available (optional dependency)
    local has_transfer_request, TransferRequest = pcall(require, "__TransferRequestSystem__.transfer-request")
    if not has_transfer_request then
        -- TransferRequest mod not available, skip sync
        return true
    end
    
    -- Clear all existing requests for this platform
    local existing_requests = TransferRequest.get_requests(platform)
    for item_name, _ in pairs(existing_requests) do
        TransferRequest.remove_request(platform, item_name)
    end
    
    -- Apply new requests from the group
    for item_name, request_data in pairs(group.requests) do
        -- Check if item is enabled (default to true if not specified)
        local enabled = request_data.enabled ~= false
        
        if enabled then
            -- Check if TransferRequest supports maximum_quantity parameter (Space Age feature)
            local success, err = pcall(function()
                TransferRequest.register_request(
                    platform,
                    item_name,
                    request_data.minimum_quantity,
                    request_data.maximum_quantity or request_data.requested_quantity
                )
            end)
            
            if not success then
                -- Fallback for older API without maximum_quantity
                TransferRequest.register_request(
                    platform,
                    item_name,
                    request_data.minimum_quantity,
                    request_data.requested_quantity
                )
            end
        end
    end
    
    return true
end

-- Process all circuit controllers (called periodically)
function CircuitRequestController.process_controllers(current_tick)
    storage.circuit_controllers = storage.circuit_controllers or {}
    
    local controllers_to_remove = {}
    
    for unit_number, controller in pairs(storage.circuit_controllers) do
        if not controller.entity or not controller.entity.valid then
            -- Controller entity was destroyed, unregister it
            table.insert(controllers_to_remove, unit_number)
        else
            -- Read circuit signals
            local red_network = controller.entity.get_circuit_network(RED_WIRE_ID)
            local green_network = controller.entity.get_circuit_network(GREEN_WIRE_ID)
            
            local signals = {}
            
            -- Collect signals from red network
            if red_network and red_network.signals then
                for _, signal in pairs(red_network.signals) do
                    local key = signal.signal.type .. "/" .. signal.signal.name
                    signals[key] = signal
                end
            end
            
            -- Collect signals from green network (merge with red)
            if green_network and green_network.signals then
                for _, signal in pairs(green_network.signals) do
                    local key = signal.signal.type .. "/" .. signal.signal.name
                    if signals[key] then
                        -- Add values if signal exists in both networks
                        signals[key].count = signals[key].count + signal.count
                    else
                        signals[key] = signal
                    end
                end
            end
            
            -- Convert signals table back to array
            local signals_array = {}
            for _, signal in pairs(signals) do
                table.insert(signals_array, signal)
            end
            
            -- Update group from signals
            if CircuitRequestController.update_group_from_signals(unit_number, signals_array) then
                -- Sync to transfer system
                CircuitRequestController.sync_group_to_transfer_system(controller.group_id)
            end
        end
    end
    
    -- Clean up destroyed controllers
    for _, unit_number in ipairs(controllers_to_remove) do
        CircuitRequestController.unregister_controller(unit_number)
    end
end

-- Cleanup function to remove stale data
function CircuitRequestController.cleanup()
    storage.circuit_controllers = storage.circuit_controllers or {}
    storage.logistics_groups = storage.logistics_groups or {}
    storage.group_controllers = storage.group_controllers or {}
    
    -- Clean up controllers for entities that no longer exist
    local controllers_to_remove = {}
    for unit_number, controller in pairs(storage.circuit_controllers) do
        if not controller.entity or not controller.entity.valid then
            table.insert(controllers_to_remove, unit_number)
        end
    end
    
    for _, unit_number in ipairs(controllers_to_remove) do
        CircuitRequestController.unregister_controller(unit_number)
    end
    
    -- Clean up groups for platforms that no longer exist
    local valid_platform_indices = {}
    for _, force in pairs(game.forces) do
        for _, platform in pairs(force.platforms) do
            if platform.valid then
                valid_platform_indices[platform.index] = true
            end
        end
    end
    
    local groups_to_remove = {}
    for group_id, group in pairs(storage.logistics_groups) do
        if not valid_platform_indices[group.platform_index] then
            table.insert(groups_to_remove, group_id)
        end
    end
    
    for _, group_id in ipairs(groups_to_remove) do
        CircuitRequestController.delete_logistics_group(group_id)
    end
end

-- Check if a group is locked by a controller
function CircuitRequestController.is_group_locked(group_id)
    storage.logistics_groups = storage.logistics_groups or {}
    local group = storage.logistics_groups[group_id]
    return group and group.locked or false
end

-- Get the logistics group data
function CircuitRequestController.get_group(group_id)
    storage.logistics_groups = storage.logistics_groups or {}
    return storage.logistics_groups[group_id]
end

-- Update multipliers for a locked group (without changing items)
-- This allows adjusting multipliers even when the group is locked
function CircuitRequestController.update_group_multipliers(group_id, item_multipliers)
    storage.logistics_groups = storage.logistics_groups or {}
    local group = storage.logistics_groups[group_id]
    if not group then return false, "Group not found" end
    
    -- Update multipliers for existing items only
    for item_name, multiplier in pairs(item_multipliers) do
        if group.requests[item_name] then
            local request = group.requests[item_name]
            local new_max = math.floor(request.minimum_quantity * multiplier)
            request.maximum_quantity = new_max
        end
    end
    
    return true
end

-- Enable/disable specific items in a group without removing them
function CircuitRequestController.set_item_enabled(group_id, item_name, enabled)
    storage.logistics_groups = storage.logistics_groups or {}
    local group = storage.logistics_groups[group_id]
    if not group then return false, "Group not found" end
    
    if not group.requests[item_name] then
        return false, "Item not in group"
    end
    
    -- Add enabled flag to request
    group.requests[item_name].enabled = enabled
    
    return true
end

-- Check if an item is enabled in a group
function CircuitRequestController.is_item_enabled(group_id, item_name)
    storage.logistics_groups = storage.logistics_groups or {}
    local group = storage.logistics_groups[group_id]
    if not group or not group.requests[item_name] then
        return false
    end
    
    -- Default to enabled if not specified
    return group.requests[item_name].enabled ~= false
end

-- Set default buffer multiplier for a controller
function CircuitRequestController.set_controller_buffer_multiplier(controller_unit_number, multiplier)
    storage.circuit_controllers = storage.circuit_controllers or {}
    
    local controller = storage.circuit_controllers[controller_unit_number]
    if not controller then return false, "Controller not found" end
    
    if multiplier <= 0 then
        return false, "Multiplier must be greater than 0"
    end
    
    controller.default_buffer_multiplier = multiplier
    return true
end

-- Set item-specific override for a controller
function CircuitRequestController.set_item_override(controller_unit_number, item_name, override_data)
    storage.circuit_controllers = storage.circuit_controllers or {}
    
    local controller = storage.circuit_controllers[controller_unit_number]
    if not controller then return false, "Controller not found" end
    
    controller.item_overrides = controller.item_overrides or {}
    
    if not override_data then
        -- Remove override
        controller.item_overrides[item_name] = nil
        return true
    end
    
    -- Set or update override
    controller.item_overrides[item_name] = {
        buffer_multiplier = override_data.buffer_multiplier,
        maximum_quantity = override_data.maximum_quantity
    }
    
    return true
end

-- Remove item override (revert to controller default)
function CircuitRequestController.remove_item_override(controller_unit_number, item_name)
    return CircuitRequestController.set_item_override(controller_unit_number, item_name, nil)
end

-- Get all item overrides for a controller
function CircuitRequestController.get_item_overrides(controller_unit_number)
    storage.circuit_controllers = storage.circuit_controllers or {}
    
    local controller = storage.circuit_controllers[controller_unit_number]
    if not controller then return {} end
    
    return controller.item_overrides or {}
end

-- Create GUI for controller configuration
function CircuitRequestController.create_gui(player, controller_entity)
    if not player or not player.valid then return end
    if not controller_entity or not controller_entity.valid then return end
    
    -- Close existing GUI if any
    if player.gui.screen["circuit-controller-gui"] then
        player.gui.screen["circuit-controller-gui"].destroy()
    end
    
    storage.circuit_controllers = storage.circuit_controllers or {}
    storage.logistics_groups = storage.logistics_groups or {}
    
    local controller = storage.circuit_controllers[controller_entity.unit_number]
    
    -- Store controller reference for this player
    storage.gui_controllers = storage.gui_controllers or {}
    storage.gui_controllers[player.index] = controller_entity.unit_number
    
    -- Create main frame using flib.gui for better mod compatibility
    local elems = {}
    local main_frame = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = "circuit-controller-gui",
        direction = "vertical",
        elem_mods = {auto_center = true},
        {
            -- Title bar
            type = "flow",
            direction = "horizontal",
            style_mods = {horizontal_spacing = 8},
            drag_target = "circuit-controller-gui",
            {
                type = "label",
                caption = {"gui.circuit-controller-title"},
                style = "frame_title",
                elem_mods = {ignored_by_interaction = true}
            },
            {
                type = "empty-widget",
                style = "draggable_space_header",
                style_mods = {
                    horizontally_stretchable = true,
                    height = 24
                },
                drag_target = "circuit-controller-gui"
            }
        },
        {
            -- Content area
            type = "frame",
            name = "content_frame",
            direction = "vertical",
            style = "inside_shallow_frame",
            style_mods = {padding = 12}
        }
    }, elems)
    
    local content = elems.content_frame
    
    if not controller then
        -- Controller not registered yet
        -- Get available groups for current surface/platform
        local surface = controller_entity.surface
        local platform_index = surface and surface.platform and surface.platform.index
        local group_items = {}
        
        if platform_index then
            local groups = CircuitRequestController.get_platform_groups(surface.platform)
            for i, group in ipairs(groups) do
                table.insert(group_items, group.name)
            end
        end
        
        flib_gui.add(content, {
            {
                type = "label",
                caption = {"gui.controller-not-registered"},
                style = "heading_2_label"
            },
            {type = "line"},
            platform_index and {
                -- Group selection
                type = "flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontal_spacing = 8
                },
                {
                    type = "label",
                    caption = {"gui.select-group"},
                    style_mods = {width = 150}
                },
                {
                    type = "drop-down",
                    name = "group-dropdown",
                    items = group_items
                }
            } or {
                type = "label",
                caption = {"gui.no-platform"},
                style = "bold_red_label"
            },
            {
                -- Planet selection
                type = "flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontal_spacing = 8,
                    top_margin = 8
                },
                {
                    type = "label",
                    caption = {"gui.target-planet"},
                    style_mods = {width = 150}
                },
                {
                    type = "textfield",
                    name = "planet-textfield",
                    text = "nauvis",
                    style_mods = {width = 200}
                }
            },
            {
                -- Register button
                type = "flow",
                direction = "horizontal",
                style_mods = {
                    top_margin = 12,
                    horizontal_align = "center"
                },
                {
                    type = "button",
                    name = "register-controller-button",
                    caption = {"gui.register-controller"},
                    style = "confirm_button"
                }
            }
        })
    else
        -- Controller is registered
        local group = storage.logistics_groups[controller.group_id]
        
        if group then
            local content_elems = {}
            flib_gui.add(content, {
                {
                    -- Status section
                    type = "flow",
                    direction = "vertical",
                    style_mods = {bottom_margin = 8},
                    {
                        type = "label",
                        caption = {"gui.group-name", group.name},
                        style = "heading_2_label"
                    },
                    {
                        type = "label",
                        caption = {"gui.target-planet", controller.target_planet}
                    }
                },
                {type = "line"},
                {
                    -- Default buffer multiplier section
                    type = "flow",
                    direction = "vertical",
                    style_mods = {
                        top_margin = 8,
                        bottom_margin = 8
                    },
                    {
                        type = "label",
                        caption = {"gui.default-buffer-multiplier"},
                        style = "bold_label"
                    },
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            horizontal_spacing = 8,
                            top_margin = 4
                        },
                        {
                            type = "textfield",
                            name = "buffer-multiplier-textfield",
                            text = tostring(controller.default_buffer_multiplier or 2.0),
                            numeric = true,
                            style_mods = {width = 100}
                        },
                        {
                            type = "button",
                            name = "save-multiplier-button",
                            caption = {"gui.save"},
                            style = "confirm_button"
                        }
                    }
                },
                {type = "line"},
                {
                    -- Current requests section
                    type = "flow",
                    name = "requests_section",
                    direction = "vertical",
                    style_mods = {top_margin = 8}
                }
            }, content_elems)
            
            local requests_section = content_elems.requests_section
            flib_gui.add(requests_section, {
                {
                    type = "label",
                    caption = {"gui.current-requests"},
                    style = "heading_2_label"
                }
            })
            
            if group.requests and next(group.requests) then
                local scroll_elems = {}
                flib_gui.add(requests_section, {
                    {
                        type = "scroll-pane",
                        name = "scroll_pane",
                        direction = "vertical",
                        style_mods = {
                            maximal_height = 400,
                            top_margin = 8
                        },
                        {
                            type = "table",
                            name = "request_table",
                            column_count = 7
                        }
                    }
                }, scroll_elems)
                
                local request_table = scroll_elems.request_table
                
                -- Headers
                request_table.add{type = "label", caption = {"gui.enabled"}, style = "bold_label"}
                request_table.add{type = "label", caption = {"gui.item"}, style = "bold_label"}
                request_table.add{type = "label", caption = {"gui.minimum"}, style = "bold_label"}
                request_table.add{type = "label", caption = {"gui.maximum"}, style = "bold_label"}
                request_table.add{type = "label", caption = {"gui.multiplier"}, style = "bold_label"}
                request_table.add{type = "label", caption = {"gui.override"}, style = "bold_label"}
                request_table.add{type = "label", caption = {"gui.actions"}, style = "bold_label"}
                
                -- Items
                for item_name, request_data in pairs(group.requests) do
                    -- Enabled checkbox
                    local is_enabled = request_data.enabled ~= false
                    request_table.add{
                        type = "checkbox",
                        name = "enable-item-" .. item_name,
                        state = is_enabled
                    }
                    
                    -- Item sprite
                    if game.item_prototypes[item_name] then
                        request_table.add{
                            type = "sprite-button",
                            sprite = "item/" .. item_name,
                            tooltip = game.item_prototypes[item_name].localised_name,
                            style = "slot_button",
                            enabled = false
                        }
                    else
                        request_table.add{type = "label", caption = item_name}
                    end
                    
                    -- Minimum quantity
                    request_table.add{type = "label", caption = tostring(request_data.minimum_quantity)}
                    
                    -- Maximum quantity
                    local override = controller.item_overrides and controller.item_overrides[item_name]
                    local max_display = tostring(request_data.maximum_quantity)
                    if override and override.maximum_quantity then
                        max_display = tostring(override.maximum_quantity) .. "*"
                    end
                    request_table.add{type = "label", caption = max_display}
                    
                    -- Multiplier display
                    local mult_display = tostring(controller.default_buffer_multiplier or 2.0)
                    if override and override.buffer_multiplier then
                        mult_display = tostring(override.buffer_multiplier) .. "*"
                    end
                    request_table.add{type = "label", caption = mult_display}
                    
                    -- Override indicator
                    local has_override = override ~= nil
                    request_table.add{type = "label", caption = has_override and {"gui.yes"} or {"gui.no"}}
                    
                    -- Actions
                    local actions_flow = request_table.add{type = "flow", direction = "horizontal"}
                    actions_flow.style.horizontal_spacing = 4
                    actions_flow.add{
                        type = "button",
                        name = "edit-item-" .. item_name,
                        caption = {"gui.edit"}
                    }
                    if has_override then
                        actions_flow.add{
                            type = "button",
                            name = "reset-item-" .. item_name,
                            caption = {"gui.reset"}
                        }
                    end
                end
            else
                flib_gui.add(requests_section, {
                    {
                        type = "label",
                        caption = {"gui.no-requests"},
                        style = "italic_label"
                    }
                })
            end
            
            flib_gui.add(content, {
                {type = "line"},
                {
                    -- Unregister button
                    type = "flow",
                    direction = "horizontal",
                    style_mods = {
                        top_margin = 8,
                        horizontal_align = "center"
                    },
                    {
                        type = "button",
                        name = "unregister-controller-button",
                        caption = {"gui.unregister-controller"},
                        style = "red_button"
                    }
                }
            })
        end
    end
    
    -- Close button at bottom
    flib_gui.add(main_frame, {
        {
            type = "flow",
            direction = "horizontal",
            style_mods = {
                horizontal_align = "right",
                top_margin = 8
            },
            {
                type = "button",
                name = "close-gui-button",
                caption = {"gui.close"}
            }
        }
    })
    
    player.opened = main_frame
end

-- Handle GUI click events
function CircuitRequestController.handle_gui_click(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    local element = event.element
    if not element or not element.valid then return end
    
    storage.gui_controllers = storage.gui_controllers or {}
    local controller_unit_number = storage.gui_controllers[player.index]
    
    if element.name == "close-gui-button" then
        if player.gui.screen["circuit-controller-gui"] then
            player.gui.screen["circuit-controller-gui"].destroy()
        end
    elseif element.name == "register-controller-button" then
        -- Handle controller registration
        local gui = player.gui.screen["circuit-controller-gui"]
        if not gui then return end
        
        -- Find the content frame
        local content_frame = gui["content_frame"]
        if not content_frame then return end
        
        local group_dropdown = content_frame["group-dropdown"]
        local planet_textfield = content_frame["planet-textfield"]
        
        if not group_dropdown or not planet_textfield then return end
        
        local controller_entity = nil
        for _, entity in pairs(player.surface.find_entities_filtered{name = "circuit-request-controller"}) do
            if entity.unit_number == controller_unit_number then
                controller_entity = entity
                break
            end
        end
        
        if not controller_entity then
            player.print({"gui.controller-not-found"})
            return
        end
        
        -- Get selected group
        local platform = controller_entity.surface.platform
        if not platform then
            player.print({"gui.no-platform"})
            return
        end
        
        local groups = CircuitRequestController.get_platform_groups(platform)
        local selected_group = groups[group_dropdown.selected_index]
        
        if not selected_group then
            player.print({"gui.no-group-selected"})
            return
        end
        
        local target_planet = planet_textfield.text or "nauvis"
        
        local success, message = CircuitRequestController.register_controller(
            controller_entity,
            selected_group.id,
            target_planet
        )
        
        if success then
            player.print({"gui.controller-registered"})
            gui.destroy()
            CircuitRequestController.create_gui(player, controller_entity)
        else
            player.print(message)
        end
    elseif element.name == "unregister-controller-button" then
        local controller_entity = nil
        for _, entity in pairs(player.surface.find_entities_filtered{name = "circuit-request-controller"}) do
            if entity.unit_number == controller_unit_number then
                controller_entity = entity
                break
            end
        end
        
        if controller_entity then
            CircuitRequestController.unregister_controller(controller_entity.unit_number)
            player.print({"gui.controller-unregistered"})
            if player.gui.screen["circuit-controller-gui"] then
                player.gui.screen["circuit-controller-gui"].destroy()
            end
        end
    elseif element.name == "save-multiplier-button" then
        local gui = player.gui.screen["circuit-controller-gui"]
        if not gui then return end
        
        local content_frame = gui["content_frame"]
        if not content_frame then return end
        
        local multiplier_textfield = content_frame["buffer-multiplier-textfield"]
        if not multiplier_textfield then return end
        
        local multiplier = tonumber(multiplier_textfield.text)
        if not multiplier or multiplier <= 0 then
            player.print({"gui.invalid-multiplier"})
            return
        end
        
        local success = CircuitRequestController.set_controller_buffer_multiplier(controller_unit_number, multiplier)
        if success then
            player.print({"gui.multiplier-saved"})
        end
    elseif element.name:match("^edit%-item%-") then
        local item_name = element.name:sub(11)
        CircuitRequestController.create_item_edit_gui(player, controller_unit_number, item_name)
    elseif element.name:match("^reset%-item%-") then
        local item_name = element.name:sub(12)
        CircuitRequestController.remove_item_override(controller_unit_number, item_name)
        player.print({"gui.override-removed", game.item_prototypes[item_name] and game.item_prototypes[item_name].localised_name or item_name})
        
        -- Refresh main GUI
        local controller_entity = nil
        for _, entity in pairs(player.surface.find_entities_filtered{name = "circuit-request-controller"}) do
            if entity.unit_number == controller_unit_number then
                controller_entity = entity
                break
            end
        end
        if controller_entity then
            CircuitRequestController.create_gui(player, controller_entity)
        end
    elseif element.name == "save-item-override-button" then
        CircuitRequestController.handle_save_item_override(player, event)
    elseif element.name == "cancel-item-edit-button" then
        if player.gui.screen["item-edit-gui"] then
            player.gui.screen["item-edit-gui"].destroy()
        end
    end
end

-- Create item edit GUI
function CircuitRequestController.create_item_edit_gui(player, controller_unit_number, item_name)
    if not player or not player.valid then return end
    
    -- Close existing edit GUI if any
    if player.gui.screen["item-edit-gui"] then
        player.gui.screen["item-edit-gui"].destroy()
    end
    
    storage.circuit_controllers = storage.circuit_controllers or {}
    local controller = storage.circuit_controllers[controller_unit_number]
    if not controller then return end
    
    local override = controller.item_overrides and controller.item_overrides[item_name]
    
    -- Store item reference
    storage.gui_edit_items = storage.gui_edit_items or {}
    storage.gui_edit_items[player.index] = item_name
    
    -- Build item display elements
    local item_display_elements = {}
    if game.item_prototypes[item_name] then
        item_display_elements = {
            {
                type = "sprite-button",
                sprite = "item/" .. item_name,
                enabled = false,
                style = "slot_button"
            },
            {
                type = "label",
                caption = game.item_prototypes[item_name].localised_name,
                style = "heading_2_label"
            }
        }
    else
        item_display_elements = {
            {
                type = "label",
                caption = item_name,
                style = "heading_2_label"
            }
        }
    end
    
    -- Create edit frame using flib.gui for better mod compatibility
    local elems = {}
    local edit_frame = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = "item-edit-gui",
        direction = "vertical",
        elem_mods = {auto_center = true},
        {
            -- Title bar
            type = "flow",
            direction = "horizontal",
            style_mods = {horizontal_spacing = 8},
            drag_target = "item-edit-gui",
            {
                type = "label",
                caption = {"gui.edit-item-settings"},
                style = "frame_title",
                elem_mods = {ignored_by_interaction = true}
            },
            {
                type = "empty-widget",
                style = "draggable_space_header",
                style_mods = {
                    horizontally_stretchable = true,
                    height = 24
                },
                drag_target = "item-edit-gui"
            }
        },
        {
            -- Content area
            type = "frame",
            name = "content_frame",
            direction = "vertical",
            style = "inside_shallow_frame",
            style_mods = {padding = 12}
        }
    }, elems)
    
    local content = elems.content_frame
    
    -- Add content using flib.gui
    flib_gui.add(content, {
        {
            -- Item display
            type = "flow",
            direction = "horizontal",
            style_mods = {
                vertical_align = "center",
                horizontal_spacing = 8,
                bottom_margin = 12
            },
            -- Unpack item display elements into the flow
            table.unpack(item_display_elements)
        },
        {type = "line"},
        {
            -- Buffer multiplier section
            type = "flow",
            direction = "vertical",
            style_mods = {
                top_margin = 8,
                bottom_margin = 8
            },
            {
                type = "label",
                caption = {"gui.buffer-multiplier"},
                style = "bold_label"
            },
            {
                type = "flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontal_spacing = 8,
                    top_margin = 4
                },
                {
                    type = "textfield",
                    name = "item-multiplier-textfield",
                    text = tostring(override and override.buffer_multiplier or controller.default_buffer_multiplier or 2.0),
                    numeric = true,
                    style_mods = {width = 100}
                }
            }
        },
        {
            -- Maximum quantity override section
            type = "flow",
            direction = "vertical",
            style_mods = {bottom_margin = 8},
            {
                type = "label",
                caption = {"gui.maximum-override"},
                style = "bold_label"
            },
            {
                type = "flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontal_spacing = 8,
                    top_margin = 4
                },
                {
                    type = "textfield",
                    name = "item-maximum-textfield",
                    text = override and override.maximum_quantity and tostring(override.maximum_quantity) or "",
                    numeric = true,
                    style_mods = {width = 100}
                },
                {
                    type = "label",
                    caption = {"gui.leave-empty-for-auto"},
                    style = "italic_label"
                }
            }
        },
        {type = "line"},
        {
            -- Buttons
            type = "flow",
            direction = "horizontal",
            style_mods = {
                top_margin = 8,
                horizontal_spacing = 8,
                horizontal_align = "center"
            },
            {
                type = "button",
                name = "save-item-override-button",
                caption = {"gui.save"},
                style = "confirm_button"
            },
            {
                type = "button",
                name = "cancel-item-edit-button",
                caption = {"gui.cancel"}
            }
        }
    })
    
    player.opened = edit_frame
end

-- Handle save item override
function CircuitRequestController.handle_save_item_override(player, event)
    if not player or not player.valid then return end
    
    storage.gui_edit_items = storage.gui_edit_items or {}
    storage.gui_controllers = storage.gui_controllers or {}
    
    local item_name = storage.gui_edit_items[player.index]
    local controller_unit_number = storage.gui_controllers[player.index]
    
    if not item_name or not controller_unit_number then return end
    
    local gui = player.gui.screen["item-edit-gui"]
    if not gui then return end
    
    local content_frame = gui["content_frame"]
    if not content_frame then return end
    
    local mult_field = content_frame["item-multiplier-textfield"]
    local max_field = content_frame["item-maximum-textfield"]
    
    if not mult_field then return end
    
    local multiplier = tonumber(mult_field.text)
    local maximum = max_field and max_field.text ~= "" and tonumber(max_field.text) or nil
    
    if not multiplier or multiplier <= 0 then
        player.print({"gui.invalid-multiplier"})
        return
    end
    
    if maximum and maximum < 0 then
        player.print({"gui.invalid-maximum"})
        return
    end
    
    local override_data = {
        buffer_multiplier = multiplier,
        maximum_quantity = maximum
    }
    
    CircuitRequestController.set_item_override(controller_unit_number, item_name, override_data)
    player.print({"gui.override-saved"})
    
    gui.destroy()
    
    -- Refresh main GUI
    local controller_entity = nil
    for _, entity in pairs(player.surface.find_entities_filtered{name = "circuit-request-controller"}) do
        if entity.unit_number == controller_unit_number then
            controller_entity = entity
            break
        end
    end
    if controller_entity then
        CircuitRequestController.create_gui(player, controller_entity)
    end
end

-- Handle GUI text changed events
function CircuitRequestController.handle_gui_text_changed(event)
    -- Currently no special handling needed
end

-- Handle GUI confirmed events (Enter key pressed)
function CircuitRequestController.handle_gui_confirmed(event)
    -- Currently no special handling needed
end

-- Handle GUI checkbox state changed events
function CircuitRequestController.handle_gui_checked_state_changed(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    local element = event.element
    if not element or not element.valid then return end
    
    -- Check if this is an enable-item checkbox
    if element.name:match("^enable%-item%-") then
        local item_name = element.name:sub(13)
        
        storage.gui_controllers = storage.gui_controllers or {}
        local controller_unit_number = storage.gui_controllers[player.index]
        if not controller_unit_number then return end
        
        storage.circuit_controllers = storage.circuit_controllers or {}
        local controller = storage.circuit_controllers[controller_unit_number]
        if not controller then return end
        
        -- Update the item enabled state
        local success, err = CircuitRequestController.set_item_enabled(
            controller.group_id,
            item_name,
            element.state
        )
        
        if success then
            -- Re-sync to transfer system
            CircuitRequestController.sync_group_to_transfer_system(controller.group_id)
            
            -- Show confirmation message
            if element.state then
                player.print({"gui.item-enabled", game.item_prototypes[item_name] and game.item_prototypes[item_name].localised_name or item_name})
            else
                player.print({"gui.item-disabled", game.item_prototypes[item_name] and game.item_prototypes[item_name].localised_name or item_name})
            end
        else
            player.print(err)
        end
    end
end

return CircuitRequestController
