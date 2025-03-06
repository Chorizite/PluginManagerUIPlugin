---@meta

---@class PluginManagerUIState
---@field isLoading boolean
---@field isLoadingDetails boolean
---@field showBetas boolean
---@field selectedVersion string
---@field selectedPluginDetails? CS.Chorizite.Plugins.Models.PluginDetailsModel
---@field selectedPlugin string
---@field availablePlugins { [string]: PluginInfo }
---@field installedPlugins { [string]: PluginInfo }
---@field pluginDetails { [string]: CS.Chorizite.Plugins.Models.PluginDetailsModel }

---@class PluginInfo
---@field name string
---@field version string
---@field isInstalled boolean
---@field description string
---@field author string
---@field icon? string