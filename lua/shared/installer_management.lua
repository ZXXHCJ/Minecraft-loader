-- Shared watchface-only page controller and resident visibility protocol.
local M={}
function M.transport(open,path)
    local sequence=0
    local function exchange(command,value)
        if type(open)~="function" then return nil,"游戏安装接口不可用" end
        sequence=sequence+1
        local request=string.pack("<I4I2I2I2I2I4I4I4I4I4I4I4",
            0x43504332,36,1,2,0,40,command,sequence,0,0,4,value)
        local file=open(path,"wb")
        if not file then return nil,"请先安装我的世界" end
        local ok,result=pcall(file.write,file,request);pcall(file.close,file)
        if not ok or result==nil then return nil,"游戏接口未接受请求\n请重启后更新安装包" end
        file=open(path,"rb")
        if not file then return nil,"无法读取应用显示状态" end
        local read_ok,reply=pcall(file.read,file,40);pcall(file.close,file)
        if not read_ok or type(reply)~="string" or #reply~=40 then
            return nil,"显示状态回复不完整"
        end
        local magic,header,abi,length,cmd,id,rc,phase,payload,hidden=string.unpack("<I4I4I4I4I4I4i4I4I4I4",reply)
        if magic~=0x43504332 or header~=0x00010024 or abi~=2 or length~=40
            or cmd~=command or id~=sequence or payload~=4 then return nil,"显示状态回复不匹配" end
        if rc~=0 or phase~=5 then
            return nil,rc==-19 and "请先安装我的世界" or ("无法更新应用显示状态\n错误码："..rc)
        end
        if hidden>1 then return nil,"显示状态回复无效" end
        return hidden==1
    end
    return {query=function() return exchange(14,0) end,
            set=function(hidden) return exchange(15,hidden and 1 or 0) end}
end
function M.attach(view,options)
    local manage,busy,hidden=false,false,nil
    local status=options.status or "准备安装"
    local install_enabled=not not options.ready
    local description="用于隐藏或恢复\n应用在应用列表中的显示\n点击标题返回安装"
    local function render_install()
        view:set_status(status);view:set_action("安装我的世界",install_enabled)
    end
    local function refresh()
        local value,message=options.transport.query()
        hidden=value
        view:set_status(value==nil and (message or "无法读取应用显示状态") or description)
        view:set_action(value and "显示我的世界" or "隐藏我的世界",value~=nil)
    end
    local controller={}
    function controller:set_status(text)
        status=tostring(text);if not manage then view:set_status(status) end
    end
    function controller:set_enabled(value)
        install_enabled=not not value
        if not manage then view:set_action("安装我的世界",install_enabled) end
    end
    function controller:set_busy(value) busy=not not value end
    view:on_title_click(function()
        if busy then return end
        manage=not manage
        if manage then refresh() else render_install() end
    end)
    view:on_click(function()
        if busy then return end
        if not manage then
            if install_enabled then options.install() end
        elseif hidden~=nil then
            busy=true;view:set_action("正在更新…",false)
            local result,message=options.transport.set(not hidden)
            refresh()
            if result==nil and message then view:set_status(message) end
            busy=false
        end
    end)
    render_install()
    return controller
end
return M
