-- SPDX-License-Identifier: AGPL-3.0-only
-- Installer ordering, original io.open, CPC2 exchange and progress runner
-- follow Canopus. Standalone payload/node names are the required differences.
-- @RECOVERY@
-- @NATIVE_LOADER@
-- @PROGRESS@
-- @INSTALLER_UI@
-- @INSTALLER_MANAGEMENT@
-- @PROFILE@
local PROFILE_SELECTED,profile_error=recovery.select_profile({[PROFILE.firmware_version]=PROFILE})
local recovery_ok,recovery_result,recovery_message=false,profile_error,nil
if PROFILE_SELECTED then recovery_ok,recovery_result,recovery_message=pcall(recovery.recover,PROFILE) end
local execute=recovery_ok and type(recovery_result)=="function" and recovery_result or nil
local control_open
if PROFILE.loader_family=="staged-kmem-mpu" and execute then
    local address=tostring(io.open):match("0[xX](%x+)$") or tostring(io.open):match(":%s*(%x+)$")
    if address and (tonumber(address,16)&~1)==PROFILE.io_open then control_open=io.open end
end
if execute and type(debug.getupvalue)=="function" then
    local _,original=debug.getupvalue(io.open,1)
    local address=type(original)=="function" and (tostring(original):match("0[xX](%x+)$") or tostring(original):match(":%s*(%x+)$"))
    if address and (tonumber(address,16)&~1)==PROFILE.io_open then control_open=original end
end
local DEVICE_PATH="/dev/minecraft"
local CPC2_MAGIC,CPC2_HEADER,CPC2_ABI_MAJOR=0x43504332,36,2
local request_id=0
local function u32le(raw,offset) return string.unpack("<I4",raw,offset+1) end
local function exchange(command, payload, reply_size)
    payload = payload or ""
    request_id = request_id + 1
    local request = string.pack("<I4I2I2I2I2I4I4I4I4I4I4", CPC2_MAGIC, CPC2_HEADER,
        1, CPC2_ABI_MAJOR, 0, CPC2_HEADER + #payload, command, request_id, 0, 0, #payload) .. payload
    local file = control_open(DEVICE_PATH, "wb")
    if not file then return nil, "无法打开游戏安装接口" end
    local write_ok, write_result, write_error = pcall(file.write, file, request)
    -- Closing a character device only reports libc's close status and returns
    -- no value here, so it carries no protocol meaning. The reply check below
    -- is what decides whether the request landed.
    pcall(file.close, file)
    if not write_ok then return nil, "无法写入安装请求：" .. tostring(write_result) end
    if write_result == nil then
        return nil, "无法写入安装请求：" .. tostring(write_error or "请求被拒绝")
    end
    file = control_open(DEVICE_PATH, "rb")
    if not file then return nil, "无法打开游戏安装接口" end
    local reply = file:read(reply_size)
    file:close()
    if type(reply) ~= "string" or #reply ~= reply_size
        or u32le(reply, 0) ~= CPC2_MAGIC or u32le(reply, 16) ~= command
        or u32le(reply, 20) ~= request_id then
        return nil, string.format("安装响应异常（应为%d字节，实际%s）",
            reply_size, type(reply) == "string" and #reply or "未收到")
    end
    return reply
end

local lvgl=require("lvgl")
local ready=execute and control_open
local options=installer_ui.install_options(PROFILE,ready,recovery_message or recovery_result)
local view=installer_ui.new(lvgl,options)
local root,button=view.root,view.button
local attempted=false
local pages
local runner=progress.new(lvgl,function(text) pages:set_status(text) end,
    function(ok,result)
        pages:set_busy(false)
        pages:set_status(ok and result or ("安装失败\n"..tostring(result)))
    end)
local function install()
    if attempted or not ready then return end
    attempted=true;pages:set_enabled(false);pages:set_busy(true)
    local ok,message=runner.start(function()
        runner.checkpoint("正在加载游戏")
        native_loader.load(PROFILE,SCRIPT_PATH:gsub("/+$","").."/../resources/",execute,runner.checkpoint)
        runner.checkpoint("正在添加游戏\n请稍候")
        local reply,message=exchange(13,string.pack("<I4",0),36)
        if not reply then error(message,0) end
        if u32le(reply,28)~=5 then
            local rc=u32le(reply,24);if rc>=0x80000000 then rc=rc-0x100000000 end
            error("添加游戏失败\n错误码："..rc,0)
        end
        return "安装完成\n请前往应用列表\n打开「我的世界」"
    end)
    if not ok then pages:set_busy(false);pages:set_status(message) end
end
pages=installer_management.attach(view,{status=options.status,ready=ready,install=install,
    transport=installer_management.transport(control_open,DEVICE_PATH)})
if lvgl.EVENT.DELETE then root:onevent(lvgl.EVENT.DELETE,function() runner.cancel();native_loader.release() end) end
