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
4. Send item signals where the signal value represents the requested quantity
   - Example: Iron plate signal with value 1000 = request 1000 iron plates

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

-- And more...
```

## Requirements

- **Factorio**: Version 2.0.0 or higher
- **Dependencies**: None (works standalone)
- **Optional**: TransferRequestSystem mod for platform transfers
- **Optional**: SpaceShipMod for full GUI support

## License

GPL-3.0
