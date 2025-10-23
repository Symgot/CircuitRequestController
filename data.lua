-- =============================================================================
-- CIRCUIT REQUEST CONTROLLER DATA DEFINITIONS
-- =============================================================================

-- =============================================================================
-- PROTOTYPE COPIES (Base templates from existing game prototypes)
-- =============================================================================

-- Circuit Request Controller prototypes (based on constant-combinator)
local circuitRequestEntity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
local circuitRequestRecipe = table.deepcopy(data.raw["recipe"]["constant-combinator"])
local circuitRequestItem = table.deepcopy(data.raw["item"]["constant-combinator"])

-- =============================================================================
-- CIRCUIT REQUEST CONTROLLER MODIFICATIONS
-- =============================================================================

circuitRequestRecipe.name = "circuit-request-controller"
circuitRequestRecipe.localised_name = "Circuit Request Controller"
circuitRequestRecipe.localised_description = "Controls logistics requests via circuit network signals."
circuitRequestRecipe.ingredients = { 
    { type = "item", name = "iron-plate", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 },
    { type = "item", name = "copper-cable", amount = 10 }
}
circuitRequestRecipe.results = { { type = "item", name = "circuit-request-controller", amount = 1 } }
circuitRequestRecipe.enabled = false

circuitRequestItem.name = "circuit-request-controller"
circuitRequestItem.localised_name = "Circuit Request Controller"
circuitRequestItem.place_result = "circuit-request-controller"
-- Create blue-tinted icon for circuit request controller
circuitRequestItem.icon = nil
circuitRequestItem.icon_size = nil
circuitRequestItem.icons = {
    {
        icon = data.raw["item"]["constant-combinator"].icon,
        icon_size = data.raw["item"]["constant-combinator"].icon_size,
        tint = { r = 0.5, g = 0.7, b = 1.0, a = 1.0 }  -- Blue tint to distinguish from other combinators
    }
}

circuitRequestEntity.name = "circuit-request-controller"
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
