-- Controls -> Blackbox -> Configuration page.

local blackboxPage = assert(loadfile("app/pages/blackbox_edit_page.lua"))()

return blackboxPage.new({
  kind = "config",
  title = "@i18n(app.modules.blackbox.name)@ / @i18n(app.modules.blackbox.menu_configuration)@",
})
