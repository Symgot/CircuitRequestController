-- =============================================================================
-- CIRCUIT REQUEST CONTROLLER DATA DEFINITIONS
-- =============================================================================

-- Import flib for better mod compatibility
local flib_data_util = require("__flib__.data-util")

-- =============================================================================
-- PROTOTYPE COPIES (Base templates from existing game prototypes)
-- =============================================================================

-- Circuit Request Controller prototypes (based on constant-combinator)
-- Using flib.data-util for consistent prototype copying
local circuitRequestEntity = flib_data_util.copy_prototype(
    data.raw["constant-combinator"]["constant-combinator"],
    "circuit-request-controller"
)
local circuitRequestRecipe = flib_data_util.copy_prototype(
    data.raw["recipe"]["constant-combinator"],
    "circuit-request-controller"
)
local circuitRequestItem = flib_data_util.copy_prototype(
    data.raw["item"]["constant-combinator"],
    "circuit-request-controller",
    true  -- remove_icon flag to handle custom icons
)

-- =============================================================================
-- CIRCUIT REQUEST CONTROLLER MODIFICATIONS
-- =============================================================================

-- Recipe configuration
circuitRequestRecipe.localised_name = "Circuit Request Controller"
circuitRequestRecipe.localised_description = "Controls logistics requests via circuit network signals."
circuitRequestRecipe.ingredients = { 
    { type = "item", name = "iron-plate", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 },
    { type = "item", name = "copper-cable", amount = 10 }
}
circuitRequestRecipe.results = { { type = "item", name = "circuit-request-controller", amount = 1 } }
circuitRequestRecipe.enabled = false

-- Item configuration with custom blue-tinted icon
circuitRequestItem.localised_name = "Circuit Request Controller"
-- Create custom icon using flib's create_icons for better compatibility
local base_combinator_item = data.raw["item"]["constant-combinator"]
circuitRequestItem.icons = flib_data_util.create_icons(base_combinator_item, {})
-- Apply blue tint to distinguish from other combinators
if circuitRequestItem.icons then
    for _, icon in ipairs(circuitRequestItem.icons) do
        icon.tint = { r = 0.5, g = 0.7, b = 1.0, a = 1.0 }
    end
end

-- Entity configuration
circuitRequestEntity.localised_name = "Circuit Request Controller"
circuitRequestEntity.minable = { mining_time = 0.2, result = "circuit-request-controller" }
circuitRequestEntity.item_slot_count = 0  -- No constant signals, only reads inputs

-- =============================================================================
-- DATA EXTEND - Register all prototypes with the game
-- =============================================================================

data:extend({
    circuitRequestItem,
    circuitRequestRecipe,
    circuitRequestEntity
})

-- =============================================================================
-- TECHNOLOGY
-- =============================================================================

data:extend({
    {
        type = "technology",
        name = "circuit-request-controller",
        localised_name = "Circuit Request Controller",
        localised_description = "Enables circuit network control of logistics requests.",
        icon = data.raw["item"]["constant-combinator"].icon,
        icon_size = data.raw["item"]["constant-combinator"].icon_size,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "circuit-request-controller"
            }
        },
        prerequisites = { "circuit-network" },
        unit = {
            count = 100,
            ingredients = {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 }
            },
            time = 15
        },
        order = "a-d-d-a"
    }
})
