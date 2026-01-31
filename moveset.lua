local pickerTimerMax = 150
gPlayerSyncTable[0].selectedMoveset = ''

local gExtraStates = {}
for i = 0, MAX_PLAYERS do
    gExtraStates[i] = {
        stickAngle = 0,
        movesMenu = false,
        movesMenuHover = 1,
        charNum = CT_CELENA,
        moveset = {},

        prevVel = {x = 0, y = 0, z = 0},
        prevAction = 0,
        prevActionTimer = 0,
        prevActionState = 0,
        prevActionArg = 0,
        prevAnimFrame = 0,
    }
end

local function get_mario_state(...)
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "table" and v.marioObj ~= nil then return v end
    end
    return gMarioStates[0]
end

local movesetList = {}
local function update_moveset_picker_list()
    movesetList = {
        {
            graffiti = get_texture_info("char_select_graffiti_default"),
            charName = "Vanilla",
            charNum = CT_CELENA,
            ogModel = E_MODEL_CELENA,
            saveName = "vanilla_moveset_celena",
        }
    }
    local charSelectTable = _G.charSelect.character_get_full_table()
    for i = 0, #charSelectTable do
        if #_G.charSelect.character_get_moveset(i) > 0 and i ~= CT_CELENA then
            table.insert(movesetList, {
                graffiti = _G.charSelect.character_get_graffiti(i),
                charName = _G.charSelect.character_get_nickname(i),
                charNum = i,
                ogModel = charSelectTable[i][1].ogModel,
                saveName = charSelectTable[i].saveName,
            })
        end
    end
end

local ACT_CELENA_PICKER = allocate_mario_action(ACT_GROUP_CUTSCENE)

---@param m MarioState
local function act_celena_picker(m)
    local e = gExtraStates[m.playerIndex]

    if m.actionState == 0 then
        update_moveset_picker_list()
        m.actionState = m.actionState + 1
    end

    if m.actionTimer < pickerTimerMax and m.controller.buttonDown & L_TRIG ~= 0 then
        m.actionTimer = m.actionTimer + 1
        local velMult = math.clamp(1 - math.sin((m.actionTimer/pickerTimerMax)*math.pi)*2, 0, 1)
        e.prevVel.y = e.prevVel.y - 2*velMult
        m.vel.x = e.prevVel.x * velMult
        m.vel.y = e.prevVel.y * velMult
        m.vel.z = e.prevVel.z * velMult
    else
        vec3f_copy(m.vel, e.prevVel)
        m.action = e.prevAction
        m.actionTimer = e.prevActionTimer
        m.actionState = e.prevActionState
        m.actionArg = e.prevActionArg
        m.marioObj.header.gfx.animInfo.animFrame = e.prevAnimFrame
        
        if #movesetList > 0 then
            for i = 1, #movesetList do
                gExtraStates[m.playerIndex].moveset = {}
                if movesetList[i].saveName == gPlayerSyncTable[m.playerIndex].selectedMoveset then
                    gExtraStates[m.playerIndex].moveset = movesetList[i].charNum ~= CT_CELENA and _G.charSelect.character_get_moveset(movesetList[i].charNum) or {}
                    local animTable = _G.charSelect.character_get_animations(movesetList[i].ogModel)
                    _G.charSelect.character_add_animations(E_MODEL_CELENA, animTable.anims or {}, animTable.eyes or {}, animTable.hands or {})
                    return
                end
            end
        end
    end

    perform_air_step(m, AIR_STEP_NONE)
end

hook_mario_action(ACT_CELENA_PICKER, {every_frame = act_celena_picker, gravity = function ()
    return 0
end})

local function hud_render()
    local m = gMarioStates[0]
    local e = gExtraStates[0]
    local p = gPlayerSyncTable[0]

    if m.action == ACT_CELENA_PICKER then
        djui_hud_set_resolution(RESOLUTION_N64)
        local screenWidth = djui_hud_get_screen_width()
        local screenHeight = 240
        local stickAngle = atan2s(m.controller.stickY, -m.controller.stickX)
        djui_hud_set_color(0, 0, 0, 100)
        djui_hud_render_rect(0, 0, screenWidth, screenHeight)
        djui_hud_set_color(0, 0, 255, 100)
        djui_hud_render_rect(0, 230, djui_hud_get_screen_width()*(m.actionTimer/pickerTimerMax), 11)
        local lowestDist = 99999
        local charName = ""
        for i = 1, #movesetList do
            local angle = math.s16(-0x10000*((i - 1)/#movesetList))
            local dist = (stickAngle - angle)
            if lowestDist == nil or math.abs(dist) < math.abs(lowestDist) then
                lowestDist = dist
                p.selectedMoveset = movesetList[i].saveName
                e.charNum = movesetList[i].charNum
                charName = movesetList[i].charName
            end
        end
        for i = 1, #movesetList do
            local angle = math.s16(-0x10000*((i - 1)/#movesetList) - 0x8000)
            if movesetList[i].saveName == p.selectedMoveset then
                djui_hud_set_color(200, 200, 255, 255)
            else
                djui_hud_set_color(100, 100, 255, 255)
            end
            local x = sins(angle)*80
            local y = coss(angle)*80
            djui_hud_render_texture(movesetList[i].graffiti, screenWidth*0.5 - 8 + x, screenHeight*0.5 - 8 + y, 0.1, 0.1)
        end

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_set_rotation(stickAngle, 0.5, 1)
        djui_hud_render_rect(screenWidth*0.5 - 4, screenHeight*0.5 - 64, 8, 64)
        djui_hud_set_rotation(0, 0, 0)
        djui_hud_set_font(FONT_RECOLOR_HUD)
        djui_hud_print_text(charName, screenWidth*0.5 - djui_hud_measure_text(charName)*0.5, screenHeight*0.5 - 8, 1)
    end
end

local function before_mario_action(m, nextAct)
    local e = gExtraStates[m.playerIndex]
    if nextAct == ACT_CELENA_PICKER then
        vec3f_copy(e.prevVel, m.vel)
        e.prevAction = m.action
        e.prevActionTimer = m.actionTimer
        e.prevActionState = m.actionState
        e.prevActionArg = m.actionArg
        e.prevAnimFrame = m.marioObj.header.gfx.animInfo.animFrame
    end
end

local function mario_update(m)
    if m.controller.buttonPressed & L_TRIG ~= 0 then
        set_mario_action(m, ACT_CELENA_PICKER, 0)
    end
end

local celenaFunction = {
    [HOOK_BEFORE_SET_MARIO_ACTION] = before_mario_action,
    [HOOK_MARIO_UPDATE] = mario_update,
    [HOOK_ON_HUD_RENDER] = hud_render,
}

-- Hook Everything
for i = 0, HOOK_MAX - 1 do
    _G.charSelect.character_hook_moveset(CT_CELENA, i, function(...)
        if celenaFunction[i] then
            local celenaReturn = celenaFunction[i](...)
            if celenaReturn ~= nil then return celenaReturn end
        end
        local moveset = gExtraStates[get_mario_state(...).playerIndex].moveset
        if moveset ~= nil and moveset[i] ~= nil then
            return moveset[i](...)
        end
    end)
end

local og_char_edit = _G.charSelect.character_edit
local function character_edit(charNum, name, description, credit, color, modelInfo, baseChar, lifeIcon, camScale)
    local e = gExtraStates[0]
    if e.charNum == charNum then
        djui_chat_message_create(tostring(modelInfo == _G.charSelect.character_get_current_table(charNum, 1).ogModel))
        local model = (modelInfo == _G.charSelect.character_get_current_table(charNum, 1).ogModel) and E_MODEL_CELENA or modelInfo
        og_char_edit(CT_CELENA, nil, nil, nil, nil, model, nil, nil, nil)
    else
        og_char_edit(charNum, name, description, credit, color, modelInfo, baseChar, lifeIcon, camScale)
    end
end

_G.charSelect.character_edit = character_edit