local lang = require 'lang'
local w2l
local wtg
local state
local chunk
local unpack_index
local read_eca

local arg_type_map = {
    [-1] = '禁用',
    [0]  = '预设',
    [1]  = '变量',
    [2]  = '函数',
    [3]  = '常量',
}

local multiple = {
    YDWERegionMultiple = {'动作'},
    YDWEEnumUnitsInRangeMultiple = {'动作'},
    YDWEForLoopLocVarMultiple = {'动作'},
    YDWETimerStartMultiple = {'动作', '动作'},
    YDWERegisterTriggerMultiple = {'事件', '动作', '动作'},
    YDWEExecuteTriggerMultiple = {'动作'},
    IfThenElseMultiple = {'条件', '动作', '动作'},
    ForLoopAMultiple = {'动作'},
    ForLoopBMultiple = {'动作'},
    ForLoopVarMultiple = {'动作'},
    ForGroupMultiple = {'动作'},
    EnumDestructablesInRectAllMultiple = {'动作'},
    EnumDestructablesInCircleBJMultiple = {'动作'},
    ForForceMultiple = {'动作'},
    EnumItemsInRectBJMultiple = {'动作'},
    AndMultiple = {'条件'},
    OrMultiple = {'条件'},
}

local function get_ui_define(type, name)
    return state.ui[type][name]
end

local function unpack(fmt)
    local result
    result, unpack_index = fmt:unpack(wtg, unpack_index)
    return result
end

local function read_head()
    local id  = unpack 'c4'
    assert(id == 'WTG!', '触发器文件错误')
    local ver = unpack 'l'
    assert(ver == 7, '触发器文件版本不正确')
end

local function read_category()
    local category = {}
    category.id      = unpack 'l'
    category.name    = unpack 'z'
    category.comment = unpack 'l'
    return category
end

local function read_categories()
    local count = unpack 'l'
    chunk.categories = {}
    for i = 1, count do
        table.insert(chunk.categories, read_category())
    end
end

local function read_var()
    local name    = unpack 'z'
    local type    = unpack 'z'
    local unknow  = unpack 'l'
    assert(unknow == 1, '未知数据2不正确')
    local array   = unpack 'l'
    local size    = unpack 'l'
    local default = unpack 'l'
    local value   = unpack 'z'

    local var = { name, type }
    if array == 1 then
        var[#var+1] = { '数组', size }
    end
    if default == 1 then
        var[#var+1] = { '默认', value }
    end

    return var
end

local function read_vars()
    local unknow = unpack 'l'
    assert(unknow == 2, '未知数据1不正确')
    local count = unpack 'l'
    chunk.vars = { '', false }
    for i = 1, count do
        chunk.vars[i+2] = read_var()
    end
end

local type_map = {
    [0] = '事件',
    [1] = '条件',
    [2] = '动作',
    [3] = '函数',
}

local type_index = {
    [0] = 'event',
    [1] = 'condition',
    [2] = 'action',
    [3] = 'call',
}

local function read_arg()
    local type        = unpack 'l'
    local value       = unpack 'z'
    local arg

    local insert_call = unpack 'l'
    if insert_call == 1 then
        arg = (read_eca(false, true))
    end

    local insert_index = unpack 'l'
    if insert_index == 1 then
        arg = { '数组', value, read_arg() }
    end

    if arg then
        return arg
    else
        return { arg_type_map[type], value }
    end
end

local function read_ecas(parent, count, is_child, multi_list)
    local ids = {}
    local max = 0
    local start = #parent+1
    for i = 1, count do
        local eca, type, id = read_eca(is_child)
        local list = parent[id+start]
        if not list then
            list = { type_map[type], false }
            parent[id+start] = list
            ids[#ids+1] = id
            if max < id then
                max = id
            end
        end
        list[#list+1] = eca
    end
    for id = 0, max-1 do
        if not parent[id+start] then
            if multi_list then
                parent[id+start] = { multi_list[id+1] or '列表' }
            else
                parent[id+start] = { '列表' }
            end
        end
    end
end

function read_eca(is_child, is_arg)
    local type = unpack 'l'
    local child_id
    if is_child then
        child_id = unpack 'l'
    end
    local name = unpack 'z'
    local enable = unpack 'l'

    local eca
    if enable == 0 then
        eca = { '禁用', name }
    elseif is_arg then
        eca = { type_map[type], name }
    else
        eca = { name, false }
    end
    local args
    local ui = get_ui_define(type_index[type], name)
    if not ui then
        error(lang.script.WTG_UI_NOT_FOUND:format(name))
    end
    if ui.args then
        for _, arg in ipairs(ui.args) do
            if arg.type ~= 'nothing' then
                local arg = read_arg(ui)
                if not args then
                    args = {}
                end
                args[#args+1] = arg
                eca[#eca+1] = arg
            end
        end
    end

    local count = unpack 'l'
    if count > 0 then
        read_ecas(eca, count, true, multiple[name])
    end
    return eca, type, child_id or type
end

local function read_trigger()
    local trigger = {}
    trigger.name     = unpack 'z'
    trigger.des      = unpack 'z'
    trigger.type     = unpack 'l'
    trigger.enable   = unpack 'l'
    trigger.wct      = unpack 'l'
    trigger.close    = unpack 'l'
    trigger.run      = unpack 'l'
    trigger.category = unpack 'l'

    trigger.trg = { '', false }
    local count = unpack 'l'
    read_ecas(trigger.trg, count, false, {'事件', '条件', '动作'})

    return trigger
end

local function read_triggers()
    local count = unpack 'l'
    chunk.triggers = {}
    for i = 1, count do
        chunk.triggers[i] = read_trigger()
    end
end

return function (w2l_, wtg_)
    w2l = w2l_
    wtg = wtg_
    local state_, err = w2l:trigger_data()
    state = state_
    if not state_ then
        error(err)
    end
    unpack_index = 1
    chunk = {}

    read_head()
    read_categories()
    read_vars()
    read_triggers()
    
    return chunk
end
