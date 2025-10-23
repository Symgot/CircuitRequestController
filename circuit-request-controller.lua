--[[
    CircuitRequestController Module
    
    This module implements circuit network control for logistics groups.
    It allows platforms to have their transfer requests controlled by circuit signals.
    
    Features:
    - 1x1 combinator-like entity for circuit network integration
    - Logistics group management and selection
    - Planet selection for target transfers
    - Automatic request quantity updates from circuit signals
    - Group locking when controlled by a circuit block
    - Only one block can control a group globally
    - Entities can remove/deactivate groups at any time
]]

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
        requests = {}, -- Map of item_name -> {minimum_quantity, requested_quantity}
        locked = false, -- Whether group is locked by a circuit controller
        created_tick = game.tick
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
        last_update_tick = 0
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
    -- The signal value is the requested quantity
    for _, signal in pairs(signals) do
        if signal.signal and signal.signal.type == "item" then
            local item_name = signal.signal.name
            local requested_quantity = signal.count
            
            if requested_quantity > 0 then
                -- Set minimum quantity to 10% of requested, or at least 1
                local minimum_quantity = math.max(1, math.floor(requested_quantity * 0.1))
                
                group.requests[item_name] = {
                    minimum_quantity = minimum_quantity,
                    requested_quantity = requested_quantity
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
        TransferRequest.register_request(
            platform,
            item_name,
            request_data.minimum_quantity,
            request_data.requested_quantity
        )
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

return CircuitRequestController
