-- Controls -> Beepers -> ESC Beacon page.

local beepersPage = assert(loadfile("app/pages/beepers_page.lua"))()

local page = beepersPage.new({
  title = "@i18n(app.modules.beepers.name)@ / @i18n(app.modules.beepers.menu_dshot)@",
  tone = true,
  fields = {
    {bit = 1, maskField = "dshotBeaconOffFlags", label = "@i18n(app.modules.beepers.field_rx_lost)@"},
    {bit = 9, maskField = "dshotBeaconOffFlags", label = "@i18n(app.modules.beepers.field_rx_set)@"},
  },
})

return page
