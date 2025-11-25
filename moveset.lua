local pickerTimerMax = 150
gPlayerSyncTable[0].LTrigDown = false

local gExtraStates = {}
for i = 0, MAX_PLAYERS do
    gExtraStates[i] = {
        stickAngle = 0,
        movesMenu = false,
        movesMenuHover = 1,
        moveset = {},

        pickTimer = 0,
        pickVel = {x = 0, y = 0, z = 0},
        pickMult = 1,
    }
end

local movesetList = {}
local function update_moveset_picker_list()
    movesetList = {}
    for i = 0, #_G.charSelect.character_get_full_table() do
        if #_G.charSelect.character_get_moveset(i) > 0 then
            table.insert(movesetList, {
                graffiti = _G.charSelect.character_get_graffiti(i),
                charName = _G.charSelect.character_get_nickname(i),
                charNum = i,
            })
        end
    end
end

---@param m MarioState
local function init_celena_picker(m)
    local e = gExtraStates[m.playerIndex]
    if m.playerIndex == 0 then
        update_moveset_picker_list()
    end
    vec3f_copy(e.pickVel, m.vel)
end

---@param m MarioState
local function update_celena_picker(m)
    local e = gExtraStates[0]
    if e.pickTimer > pickerTimerMax then
        e.pickMult = e.pickMult*1.1
    else
        e.pickMult = e.pickMult/1.1
    end
    e.pickMult = math.clamp(e.pickMult, 0.001, 1)

    m.vel.x = e.pickVel.x * e.pickMult
    m.vel.y = e.pickVel.y * e.pickMult
    m.vel.z = e.pickVel.z * e.pickMult
    djui_chat_message_create("----")
    djui_chat_message_create(tostring(m.vel.x))
    djui_chat_message_create(tostring(m.vel.y))
    djui_chat_message_create(tostring(m.vel.z))

    e.pickTimer = e.pickTimer + 1
end

local function hud_render()
    local e = gExtraStates[0]

    if e.movesMenu then
        djui_hud_set_resolution(RESOLUTION_N64)
        local screenWidth = djui_hud_get_screen_width()
        local screenHeight = 240
        djui_hud_set_color(0, 0, 0, 100)
        djui_hud_render_rect(0, 0, screenWidth, screenHeight)
        for i = 1, #movesetList do
            local angle = -0x10000*((i - 1)/#movesetList) + 0x8000
            if i == e.movesMenuHover then
                djui_hud_set_color(200, 200, 255, 255)
            else
                djui_hud_set_color(100, 100, 255, 255)
            end
            local x = sins(angle)*80
            local y = coss(angle)*80
            djui_hud_render_rect(screenWidth*0.5 - 8 + x, screenHeight*0.5 - 8 + y, 16, 16)
        end

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_set_rotation(e.stickAngle, 0.5, 1)
        djui_hud_render_rect(screenWidth*0.5 - 4, screenHeight*0.5 - 64, 8, 64)
        djui_hud_set_rotation(0, 0, 0)
        djui_hud_set_font(FONT_RECOLOR_HUD)
        local tauntText = ""
        if movesetList[e.movesMenuHover] ~= nil then
            tauntText = movesetList[e.movesMenuHover].charName
        end
        djui_hud_print_text(tauntText, screenWidth*0.5 - djui_hud_measure_text(tauntText)*0.5, screenHeight*0.5 - 8, 1)
    end
end

local function nullify_inputs(m)
    local c = m.controller
    c.buttonDown = 0
    c.buttonPressed = 0
    c.extStickX = 0
    c.extStickY = 0
    c.rawStickX = 0
    c.rawStickY = 0
    c.stickMag = 0
    c.stickX = 0
    c.stickY = 0
end

local function before_mario_update(m)
    local e = gExtraStates[m.playerIndex]
    local p = gPlayerSyncTable[m.playerIndex]

    if m.playerIndex == 0 then
        gPlayerSyncTable[0].LTrigDown = m.controller.buttonDown & L_TRIG ~= 0
    end

    if p.LTrigDown then
        if not e.movesMenu then
            init_celena_picker(m)
            e.movesMenu = true
        end
        e.stickAngle = atan2s(m.controller.stickY, -m.controller.stickX)

        local lowestDist = nil
        e.movesMenuHover = 1
        for i = 1, #movesetList do
            local angle = -0x10000*((i - 1)/#movesetList) + 0x8000

            local dist = math.abs(e.stickAngle - angle)
            --djui_chat_message_create(tostring(dist))
            if lowestDist == nil or dist < lowestDist then
                lowestDist = dist
                e.movesMenuHover = movesetList[i].charNum
            end
        end

        nullify_inputs(m)
    else
        e.movesMenu = false
    end

    if p.LTrigDown or e.pickMult < 1 then
        update_celena_picker(m)
    end
end

_G.charSelect.character_hook_moveset(CT_CELENA, HOOK_ON_HUD_RENDER, hud_render)
_G.charSelect.character_hook_moveset(CT_CELENA, HOOK_BEFORE_MARIO_UPDATE, before_mario_update)