# CircuitRequestController - Manual Test Guide

This guide helps you test the CircuitRequestController functionality in Factorio using VS Code debugging.

## Prerequisites

1. Install [VS Code](https://code.visualstudio.com/)
2. Install the [Factorio Mod Debug extension](https://marketplace.visualstudio.com/items?itemName=justarandomgeek.factoriomod-debug)
3. Set the `FACTORIO_PATH` environment variable:
   - Windows: `setx FACTORIO_PATH "C:\Program Files\Steam\steamapps\common\Factorio"`
   - Linux: Add `export FACTORIO_PATH="/path/to/factorio"` to your `~/.bashrc`
   - macOS: Add `export FACTORIO_PATH="/Applications/factorio.app/Contents"` to your `~/.zshrc`
4. Extract the flib library:
   ```bash
   unzip flib_0.16.5.zip
   ```

## Starting Debug Session

1. Open the project folder in VS Code
2. Press F5 or go to Run → Start Debugging
3. Select "Factorio Mod Debug" configuration
4. Factorio will launch with the debugger attached

## Test Cases

### Test 1: Basic Controller Registration

**Objective**: Verify that a Circuit Request Controller can be registered with a logistics group.

**Steps**:
1. Start a new game in Factorio
2. Enable the mod in the mod list if not already enabled
3. Use console command to research the technology:
   ```
   /c game.player.force.technologies["circuit-request-controller"].researched = true
   ```
4. Place a Circuit Request Controller entity
5. Open the entity GUI
6. Verify that the registration interface appears
7. Create a logistics group (if SpaceShipMod is available) or use remote interface
8. Select a group from the dropdown
9. Enter a target planet (e.g., "nauvis")
10. Click "Register Controller"

**Expected Result**:
- Controller should register successfully
- GUI should show controller configuration options
- Group should be marked as "locked" in the system

### Test 2: Circuit Signal Processing

**Objective**: Verify that circuit signals are read and processed correctly.

**Steps**:
1. Register a Circuit Request Controller (see Test 1)
2. Place a constant combinator next to the controller
3. Connect them with a red or green wire
4. Set signals in the constant combinator:
   - Iron plate: 1000
   - Copper plate: 500
5. Wait for the controller to process (updates every 60 ticks / 1 second)
6. Open the controller GUI

**Expected Result**:
- Controller GUI should show the requested items
- Minimum quantities should match the signal values (1000, 500)
- Maximum quantities should be calculated (default multiplier is 2.0):
  - Iron plate: 2000
  - Copper plate: 1000

### Test 3: Buffer Multiplier Configuration

**Objective**: Verify that the buffer multiplier can be changed.

**Steps**:
1. Complete Test 2 setup
2. Open the controller GUI
3. Find the "Default Buffer Multiplier" section
4. Change the value from 2.0 to 3.0
5. Click "Save"
6. Wait for the next update cycle

**Expected Result**:
- Maximum quantities should be recalculated with new multiplier:
  - Iron plate: 3000 (1000 × 3.0)
  - Copper plate: 1500 (500 × 3.0)

### Test 4: Item-Specific Overrides

**Objective**: Verify that per-item overrides work correctly.

**Steps**:
1. Complete Test 2 setup
2. Open the controller GUI
3. Click "Edit" next to Iron plate
4. Set buffer multiplier to 5.0
5. Click "Save"
6. Wait for the next update cycle

**Expected Result**:
- Iron plate maximum should be 5000 (1000 × 5.0)
- Copper plate maximum should remain at default multiplier
- Iron plate should show an asterisk (*) in the GUI indicating override

### Test 5: Fixed Maximum Override

**Objective**: Verify that a fixed maximum quantity can be set.

**Steps**:
1. Complete Test 2 setup
2. Open the controller GUI
3. Click "Edit" next to Copper plate
4. Set maximum quantity to 10000
5. Leave buffer multiplier unchanged
6. Click "Save"

**Expected Result**:
- Copper plate maximum should be 10000 (fixed)
- Value should not change based on signal value
- Copper plate should show an asterisk (*) in the GUI

### Test 6: Enable/Disable Items

**Objective**: Verify that items can be enabled/disabled.

**Steps**:
1. Complete Test 2 setup
2. Open the controller GUI
3. Uncheck the checkbox next to Iron plate
4. Close the GUI

**Expected Result**:
- Iron plate should remain in the group
- Iron plate should not be synchronized to the transfer system
- Copper plate should still be active

### Test 7: Multiple Signal Sources

**Objective**: Verify that signals from red and green networks are combined.

**Steps**:
1. Register a Circuit Request Controller
2. Place two constant combinators
3. Connect one with red wire, one with green wire
4. Set different signals in each:
   - Red: Iron plate: 500
   - Green: Iron plate: 300
5. Wait for update

**Expected Result**:
- Iron plate minimum should be 800 (500 + 300)
- Maximum should be 1600 (800 × 2.0)

### Test 8: Controller Unregistration

**Objective**: Verify that unregistering a controller works correctly.

**Steps**:
1. Complete Test 1 setup
2. Open the controller GUI
3. Click "Unregister Controller"

**Expected Result**:
- Controller should be unregistered
- Group should be unlocked
- GUI should show the registration interface again

### Test 9: Controller Destruction

**Objective**: Verify cleanup when controller is destroyed.

**Steps**:
1. Complete Test 1 setup
2. Mine or destroy the controller entity

**Expected Result**:
- Controller should be automatically unregistered
- Group should be unlocked
- No errors should occur

### Test 10: Reset Override

**Objective**: Verify that overrides can be reset.

**Steps**:
1. Complete Test 4 setup (with override on Iron plate)
2. Open the controller GUI
3. Click "Reset" next to Iron plate

**Expected Result**:
- Iron plate should revert to default buffer multiplier
- Asterisk should disappear
- Maximum should be recalculated with default multiplier

## Debugging Tips

### Setting Breakpoints

You can set breakpoints in VS Code by clicking on the left margin of any Lua file. The debugger will pause execution when the breakpoint is hit.

**Useful breakpoints**:
- `circuit-request-controller.lua:310` - When processing controllers
- `circuit-request-controller.lua:186` - When updating group from signals
- `circuit-request-controller.lua:840` - When handling GUI clicks

### Inspecting Variables

When paused at a breakpoint, you can:
- Hover over variables to see their values
- Use the Debug Console to evaluate Lua expressions
- Check the Call Stack to see how you got there

### Common Issues

**Issue**: Controller doesn't update
- **Solution**: Check if circuit wires are connected properly
- **Solution**: Verify that signals are being set correctly

**Issue**: GUI doesn't appear
- **Solution**: Check if the entity is valid
- **Solution**: Verify that the GUI isn't already open

**Issue**: Multiplier changes don't apply
- **Solution**: Wait for the next update cycle (60 ticks)
- **Solution**: Check that the value was saved correctly

## Remote Interface Testing

You can test the remote interface using the Factorio console:

```lua
-- Get the module
local CRC = remote.call("CircuitRequestController", "get_module")

-- Create a logistics group
local group_id = remote.call("CircuitRequestController", "create_logistics_group", 
    game.player.surface.platform, "Test Group")

-- Register a controller
local controller = game.player.surface.find_entities_filtered{
    name = "circuit-request-controller", 
    limit = 1
}[1]
local success, msg = remote.call("CircuitRequestController", "register_controller",
    controller, group_id, "nauvis")
game.print(success and "Success" or msg)

-- Set buffer multiplier
remote.call("CircuitRequestController", "set_controller_buffer_multiplier",
    controller.unit_number, 3.0)

-- Set item override
remote.call("CircuitRequestController", "set_item_override",
    controller.unit_number, "iron-plate", {
        buffer_multiplier = 2.5,
        maximum_quantity = 5000
    })
```

## Performance Testing

Monitor performance using:
- F4 → Show FPS and UPS
- F5 → Show time usage
- Check that the mod doesn't significantly impact UPS

Expected behavior:
- Processing occurs once per second (every 60 ticks)
- Should have minimal impact on game performance
- Cleanup occurs every 5 minutes (18000 ticks)
