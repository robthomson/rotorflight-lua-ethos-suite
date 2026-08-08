local modePage = assert(loadfile("app/pages/settings_activelook_mode.lua"))()
return modePage.create("inflight", "@i18n(app.modules.settings.activelook_inflight)@")
