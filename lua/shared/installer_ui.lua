-- Shared Minecraft installer view. Loading/registration stays in each backend.
-- The 466px layout preserves the o62 installer geometry and colours.
local M={}
function M.install_options(profile,ready,message)
    local device=profile.target_id=="o66-3.1.33" and "小米手环10" or profile.firmware_version
    return {title="我的世界",status=ready and (device.."\n准备安装\n请点击下方按钮")
        or ("暂时无法安装\n"..tostring(message or "系统接口不可用"))}
end
function M.new(lvgl,options)
    options=options or {}
    local width,height=lvgl.HOR_RES(),lvgl.VER_RES()
    local narrow=width<350
    local root=lvgl.Object(nil,{w=width,h=height,bg_color=0x252725,
        bg_opa=lvgl.OPA(100),border_width=0})
    root:clear_flag(lvgl.FLAG.SCROLLABLE)
    local title=lvgl.Label(root,{text=options.title or "Minecraft",text_color=0xffffff,
        text_font=lvgl.Font("MiSans-Demibold",narrow and 24 or 32),
        width=math.min(300,width-24),height=48,
        align={type=lvgl.ALIGN.CENTER,x_ofs=0,y_ofs=-120}})
    local status=lvgl.Label(root,{text=options.status or "准备安装",text_color=0xffffff,
        text_font=lvgl.Font("MiSans-Regular",narrow and 18 or 22),
        width=math.min(310,width-24),height=140,
        align={type=lvgl.ALIGN.CENTER,x_ofs=0,y_ofs=-10}})
    local button=lvgl.Object(root,{w=math.min(250,width-24),h=64,
        bg_color=0x43812c,bg_opa=lvgl.OPA(100),radius=10,
        align={type=lvgl.ALIGN.CENTER,x_ofs=0,y_ofs=125}})
    button:add_flag(lvgl.FLAG.CLICKABLE)
    button:clear_flag(lvgl.FLAG.SCROLLABLE)
    local caption=lvgl.Label(button,{text="安装我的世界",text_color=0xffffff,
        text_font=lvgl.Font("MiSans-Regular",narrow and 20 or 24),
        align=lvgl.ALIGN.CENTER})
    local view={root=root,status=status,button=button,title=title}
    function view:set_status(text) status:set{text=tostring(text)} end
    function view:set_action(text,enabled)
        caption:set{text=text}
        if enabled then button:add_flag(lvgl.FLAG.CLICKABLE)
        else button:clear_flag(lvgl.FLAG.CLICKABLE) end
    end
    local function bind(object,callback)
        if type(object.onevent)=="function" and lvgl.EVENT and lvgl.EVENT.CLICKED then
            object:onevent(lvgl.EVENT.CLICKED,callback)
        else
            object:onClicked(callback)
        end
    end
    function view:on_click(callback) bind(button,callback) end
    function view:on_title_click(callback)
        title:add_flag(lvgl.FLAG.CLICKABLE);bind(title,callback)
    end
    return view
end
return M
