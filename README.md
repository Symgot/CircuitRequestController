# Circuit Request Controller

A standalone Factorio mod that enables circuit network control of logistics requests.

## Features

- **Circuit Network Integration**: Control logistics requests via circuit signals
- **Logistics Group Management**: Organize requests into logical groups
- **No Space Age Required**: Works with base Factorio 2.0
- **Optional Integration**: Can work with TransferRequestSystem mod for platform-to-platform transfers
- **Remote Interface**: Other mods can interact with this mod via remote calls

## Usage

### Basic Usage

1. Research "Circuit Request Controller" technology
2. Build a Circuit Request Controller entity
3. Connect red or green circuit wires to the controller
4. Send item signals where the signal value represents the **minimum** requested quantity
   - Example: Iron plate signal with value 1000 = request minimum 1000 iron plates
   - The controller automatically calculates maximum quantity based on the buffer multiplier
   - Default buffer multiplier is 2.0 (so max = min × 2.0)

### GUI Configuration

When you open a Circuit Request Controller entity, you can:

1. **Register the Controller** (if not already registered):
   - Select a logistics group from the dropdown
   - Specify the target planet (default: nauvis)
   - Click "Register Controller"

2. **Configure Buffer Multiplier**:
   - Set the default buffer multiplier for all items
   - This determines: `Maximum Quantity = Minimum Quantity × Buffer Multiplier`
   - Default is 2.0, but you can set any value > 0

3. **View Current Requests**:
   - See all items being requested via circuit signals
   - View minimum and maximum quantities for each item
   - Items marked with "*" have custom overrides
   - Enable/disable individual items using the checkboxes

4. **Enable/Disable Items**:
   - Use the checkbox next to each item to enable or disable it
   - Disabled items remain in the group but are not synchronized to the transfer system
   - This allows you to temporarily pause requests without changing items

5. **Item-Specific Overrides**:
   - Click "Edit" next to any item to set custom values
   - Set a custom buffer multiplier for that specific item
   - Or set a fixed maximum quantity (overrides the multiplier calculation)
   - Entity-level adjustments have higher priority than controller settings

6. **Reset Overrides**:
   - Click "Reset" next to items with overrides
   - This reverts the item back to using controller default settings

**Note**: When a logistics group is controlled by a circuit controller, the items in the group are locked and cannot be added or removed. However, you can still adjust multipliers and enable/disable individual items.

### With TransferRequestSystem Mod

When used together with the TransferRequestSystem mod:
1. Place the controller on a space platform
2. Configure it to control a logistics group
3. Circuit signals will automatically update transfer requests
4. Items will be transferred from other platforms in the same orbit

### With SpaceShipMod

When used with SpaceShipMod, you get a full GUI for:
- Creating and managing logistics groups
- Selecting target planets
- Viewing current requests
- Monitoring controller status

## Remote Interface

Other mods can interact with this mod using:

```lua
-- Get the CircuitRequestController module
local CRC = remote.call("CircuitRequestController", "get_module")

-- Create a logistics group
local group_id = remote.call("CircuitRequestController", "create_logistics_group", platform, "My Group")

-- Register a controller
local success, message = remote.call("CircuitRequestController", "register_controller", 
    controller_entity, group_id, "nauvis")

-- Set default buffer multiplier for a controller
local success = remote.call("CircuitRequestController", "set_controller_buffer_multiplier",
    controller_unit_number, 3.0)

-- Set item-specific override
local success = remote.call("CircuitRequestController", "set_item_override",
    controller_unit_number, "iron-plate", {
        buffer_multiplier = 2.5,  -- Optional: custom multiplier
        maximum_quantity = 5000    -- Optional: fixed maximum
    })

-- Remove item override (revert to controller default)
local success = remote.call("CircuitRequestController", "remove_item_override",
    controller_unit_number, "iron-plate")

-- Get all item overrides for a controller
local overrides = remote.call("CircuitRequestController", "get_item_overrides",
    controller_unit_number)

-- Update multipliers for a locked group (without changing items)
local success, err = remote.call("CircuitRequestController", "update_group_multipliers",
    group_id, {
        ["iron-plate"] = 2.5,
        ["copper-plate"] = 3.0
    })

-- Enable/disable specific items in a group
local success, err = remote.call("CircuitRequestController", "set_item_enabled",
    group_id, "iron-plate", true)

-- Check if an item is enabled in a group
local is_enabled = remote.call("CircuitRequestController", "is_item_enabled",
    group_id, "iron-plate")

-- Check if a group is locked
local is_locked = remote.call("CircuitRequestController", "is_group_locked", group_id)

-- Get logistics group data
local group = remote.call("CircuitRequestController", "get_group", group_id)

-- Get controller data
local controller = remote.call("CircuitRequestController", "get_controller", controller_unit_number)

-- And more...
```

## Requirements

- **Factorio**: Version 2.0.0 or higher
- **Dependencies**: None (works standalone)
- **Optional**: TransferRequestSystem mod for platform transfers
- **Optional**: SpaceShipMod for full GUI support

## Development

### Creating a Release

To create a release:

1. Go to the **Actions** tab in the GitHub repository
2. Select the **Create Release** workflow
3. Click **Run workflow**
4. The workflow will automatically:
   - Read the version from `info.json`
   - Check if a release with that version already exists
   - If it exists, increment the version by 0.0.1 and retry automatically
   - Create a zip file with the structure: `ModName_Version/` containing all mod files
   - Upload the zip as a GitHub release

The release package follows Factorio's mod structure with translations in `locale/en/` directory.

## License

GPL-3.0
