-- Standalone Minecraft / o62lte native-insmod backend.
-- Activation order follows the current SysPatch watch loader: resident check,
-- insmod, VFS preflight, UI-thread VFS activation. Its START protocol is NOT used.
-- Build replaces @PROFILE@; this source is never packaged without a build.
local lvgl = require("lvgl")
-- @INSTALLER_UI@
-- @INSTALLER_MANAGEMENT@
-- @PROFILE@
local device, attempted, sequence = "/dev/minecraft", false, 0
local module_path = SCRIPT_PATH .. "minecraft_o62.elf"
local function read(path, count)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read(count or "*a"); f:close(); return data
end
local function word(data, offset)
    if type(data) ~= "string" or #data < offset + 4 then return nil end
    return string.unpack("<I4", data, offset + 1)
end
local function identity()
    local f=io.open(device,"rb");if not f then return nil end
    local data=f:read(32);f:close()
    if type(data)~="string" or #data~=32 then
        return false,"安装接口读取失败；重启后使用 r3 安装包"
    end
    if word(data,0)~=0x4d435731 or word(data,8)~=32 or word(data,16)~=26 then
        return false,"安装接口格式不匹配，请重启后更新"
    end
    if word(data,4)~=PROFILE.build then
        return false,string.format("驻留版本 %08X，安装包 %08X\n请重启手表后更新",word(data,4),PROFILE.build)
    end
    return data
end
local function stage_icon()
    local data = read(SCRIPT_PATH .. "icon108.bin")
    if type(data) ~= "string" or #data ~= PROFILE.icon_size or data:byte(1) ~= 0x19
        or string.unpack("<I2",data,5) ~= 108 or string.unpack("<I2",data,7) ~= 108 then
        return nil, "图标资源校验失败"
    end
    os.execute("mkdir /data/band11-minecraft")
    local path = "/data/band11-minecraft/icon108.bin"
    local f = io.open(path,"wb"); if not f then return nil,"无法写入图标" end
    local ok = f:write(data); f:close()
    if not ok or read(path) ~= data then return nil,"图标写入校验失败" end
    return true
end
local function activate()
    sequence = sequence + 1
    local request = string.pack("<I4I2I2I2I2I4I4I4I4I4I4I4",
        0x43504332,36,1,2,0,40,13,sequence,0,0,4,0)
    local f=io.open(device,"wb");if not f then return nil,"无法打开安装接口" end
    local ok,result=pcall(f.write,f,request);pcall(f.close,f)
    if not ok or result==nil then return nil,"安装请求未被接受" end
    local response=read(device,36)
    if type(response)~="string" or #response~=36 or word(response,0)~=0x43504332
        or word(response,4)~=0x00010024 or word(response,8)~=2 or word(response,12)~=36
        or word(response,16)~=13 or word(response,20)~=sequence or word(response,32)~=0 then
        return nil,"安装回复校验失败"
    end
    if word(response,24)~=0 or word(response,28)~=5 then
        local rc=word(response,24);if rc>=0x80000000 then rc=rc-0x100000000 end
        return nil,"页面注册失败："..tostring(rc)
    end
    local status,error=identity()
    if not status or word(status,12)~=1 then return nil,error or "页面未完成注册" end
    return true
end
local function start()
    if attempted then return nil,"本次已尝试加载；更新后请重启手表" end
    attempted=true
    local resident,error=identity();if resident==false then return nil,error end
    local ok,message=stage_icon();if not ok then return nil,message end
    if not resident then
        local f=io.open(module_path,"rb");if not f then return nil,"模块文件缺失" end
        local header=f:read(52);local size=f:seek("end");f:close()
        if type(header)~="string" or #header~=52 or header:sub(1,7)~="\127ELF\1\1\1"
            or header:byte(17)~=1 or header:byte(18)~=0
            or header:byte(19)~=40 or header:byte(20)~=0
            or word(header,24)~=1 or word(header,36)~=0x05000400
            or size~=PROFILE.module_size then
            return nil,"模块文件校验失败"
        end
        collectgarbage("collect")
        local quoted="'"..module_path:gsub("'","'\\''").."'"
        os.execute("insmod "..quoted.." minecraft_o62")
        resident,error=identity()
        if not resident then return nil,error or "模块未加载，请检查固件版本" end
    end
    if word(resident,12)==1 then return true end
    return activate()
end
local view=installer_ui.new(lvgl)
local pages
local function install()
    pages:set_busy(true);pages:set_enabled(false)
    local ran,ok,error=pcall(start)
    pages:set_busy(false)
    pages:set_status(ran and (ok and "安装完成\n请从应用列表打开" or error) or ("安装失败："..tostring(ok)))
end
pages=installer_management.attach(view,{status="小米手表\n准备安装\n请点击下方按钮",
    ready=true,install=install,transport=installer_management.transport(io.open,device)})
