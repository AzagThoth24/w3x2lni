require 'filesystem'
require 'utility'
local core  = require 'tool.sandbox_core'
local uni      = require 'ffi.unicode'
local stormlib = require 'ffi.stormlib'
local sleep = require 'ffi.sleep'
local prebuilt = require 'prebuilt.prebuilt'
local w2l = core()

local function task(f, ...)
    for i = 1, 99 do
        if pcall(f, ...) then
            return true
        end
        sleep(10)
    end
    return false
end

local mpq_names = {
    'War3.mpq',
    'War3x.mpq',
    'War3xLocal.mpq',
    'War3Patch.mpq',
}

local function open_mpq(dir)
    local mpqs = {}

    for i, name in ipairs(mpq_names) do
        mpqs[i] = stormlib.open(dir / name, true)
        if mpqs[i] == nil then
            print('文件打开失败：', (dir / name):string())
            return nil
        end
    end

    return mpqs
end

local result = {} 

local function extract_file(mpq, name)
    local path = fs.current_path():parent_path() / 'data' / 'mpq' / arg[2] / name
    if fs.exists(path) then
        return
    end
    if not mpq:has_file(name) then
        return
    end
    fs.create_directories(path:parent_path())
    local res = mpq:extract(name, path)
    result[path:string()] = res
end

local function report_fail()
    local tbl = {}
    for name, res in pairs(result) do
        if res == false then
            table.insert(tbl, name)
        end
    end
    table.sort(tbl)
    for _, name in ipairs(tbl) do
        print('文件导出失败：', name)
    end
end

local function extract_mpq(mpqs)
    local info = w2l:parse_lni(assert(io.load(fs.current_path() / 'core' / 'info.ini')))
    for i = 4, 1, -1 do
        local mpq = mpqs[i]
        for _, root in ipairs {'', 'Custom_V1\\'} do
            extract_file(mpq, root .. 'Scripts\\Common.j')
            extract_file(mpq, root .. 'Scripts\\Blizzard.j')
            
            extract_file(mpq, root .. 'UI\\MiscData.txt')
            extract_file(mpq, root .. 'UI\\WorldEditStrings.txt')

            extract_file(mpq, root .. 'units\\MiscGame.txt')
            extract_file(mpq, root .. 'units\\MiscData.txt')

            for type, slks in pairs(info.slk) do
                for _, name in ipairs(slks) do
                    extract_file(mpq, root .. name)
                end
            end

            for _, name in ipairs(info.txt) do
                extract_file(mpq, root .. name)
            end
        end
    end
end

local function main()
    local dir = fs.path(arg[1])
    if not fs.is_directory(dir) then
        dir:remove_filename()
    end

    local mpqs = open_mpq(dir)
    if not mpqs then
        return
    end
    local mpq_path = fs.current_path():parent_path() / 'data' / 'mpq' / arg[2]
    if fs.exists(mpq_path) then
        if not task(fs.remove_all, mpq_path) then
            error(('无法清空目录[%s]，请检查目录是否被占用。'):format(mpq_path:string()))
        end
    end
    if not task(fs.create_directories, mpq_path) then
        error(('无法创建目录[%s]，请检查目录是否被占用。'):format(mpq_path:string()))
    end

    extract_mpq(mpqs)
    report_fail()

    prebuilt:dofile(arg[2], 'zh-CN', 'Melee')
    prebuilt:dofile(arg[2], 'zh-CN', 'Custom')

    print('[完毕]: 用时 ' .. os.clock() .. ' 秒') 
end

main()
