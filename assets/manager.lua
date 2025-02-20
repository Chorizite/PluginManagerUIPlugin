
local rx = require('rx')
local ui = require('Plugins.Core.UI')
local PluginManagerUI = require('Plugins.PluginManagerUI')
local PluginManager = require('PluginManager')
local json = require('json')
local versionutils = require("versionutils")

local state = rx:CreateState({
  isLoading = true,
  isLoadingDetails = false,
  showBetas = false,
  selectedPlugin = "",
  selectedPluginDetails = nil,
  installedPlugins = {},
  availablePlugins = {},
  pluginDetails = {},
  selectedVersion = ""
}) --[[@as PluginManagerUIState]]

---@type ReleaseJson
local releases = { Plugins = {} }
local Reload = async(function()
  state.isLoading = true 
  releases = json.decode(await(PluginManagerUI:GetReleasesJson())) --[[@as ReleaseJson]]
  
  for i,manifest in pairs(PluginManager.PluginManifests) do
    local name = manifest.Name
    
    state.installedPlugins[name] = {
      name = name,
      description = manifest.Description,
      author = manifest.Author,
      version = manifest.Version,
      isInstalled = true,
      icon = manifest.Icon
    }
  end

  for name,plugin in pairs(releases.Plugins) do
    if not state.installedPlugins[name] then
      state.availablePlugins[name] = {
        name = name,
        version = plugin.Latest.Version or "0.0.0",
        description = plugin.Description,
        author = plugin.Author,
        isInstalled = true,
        icon = plugin.Icon
      }
    end
  end
  state.isLoading = false
end)

local LoadPluginDetails = async(function(plugin)
  state.selectedPluginDetails = nil
  
  if state.pluginDetails[plugin.name] ~= nil then
    state.selectedPluginDetails = state.pluginDetails[plugin.name]
  else
    state.isLoadingDetails = true
    local jsonResult = await(PluginManagerUI:GetPluginReleasesJson(plugin.name))
    if jsonResult ~= nil then
      state.pluginDetails[plugin.name] = json.decode(jsonResult)
      state.selectedPluginDetails = state.pluginDetails[plugin.name]
    else
      state.selectedPluginDetails = {
        Author = plugin.author,
        Name = plugin.name,
        Description = plugin.description,
        Latest = {
          Name = plugin.version,
          Description = plugin.description,
        },
        Releases = {}
      }
    end
    state.isLoadingDetails = false
  end
end)

---comment
---@param plugin PluginInfo
---@return CS.Core.UI.Lib.RmlUi.VDom.VirtualNode
local PluginLineView = function(plugin)
  local latestVersion = releases.Plugins[plugin.name] and releases.Plugins[plugin.name].Latest.Version or plugin.version

  if state.showBetas and releases.Plugins[plugin.name] and releases.Plugins[plugin.name].LatestBeta then
    if versionutils.compare(plugin.version, releases.Plugins[plugin.name].LatestBeta.Version) < 0 then
      latestVersion = releases.Plugins[plugin.name].LatestBeta.Version or ""
    end
  end

  if plugin.version == latestVersion or plugin.version == "0.0.0-dev" or versionutils.compare(plugin.version, latestVersion) > 0 then
    latestVersion = ""
  end

  return rx:Div({
    class = "plugin  " .. plugin.name,
    onclick = function() LoadPluginDetails(plugin) end
  }, {
    rx:Div({ class = "flex" }, {
      rx:Div({
        class = {
          ["has-icon"] = plugin.icon and #plugin.icon > 0,
          icon = true
        }
      }, function ()
        if plugin.icon and #plugin.icon > 0 then
          return { rx:Img({ src = ("@plugins/" .. plugin.name .. "/" .. plugin.icon)}) }
        else
          return { rx:Div() }
        end
      end),
      rx:Div({ class = "info" }, {
        rx:H3(plugin.name, {
          rx:Span(" by " .. plugin.author)
        }),
      }),
      rx:Div({ class = "version" }, {
        rx:Div({ class="remove" }, plugin.version),
        rx:Div({ class="update" }, latestVersion),
      })
    }),
    rx:P(plugin.description),
  })
end

---Render a list of plugins
---@param title string section title
---@param plugins { string: PluginInfo }
---@return CS.Core.UI.Lib.RmlUi.VDom.VirtualNode
local PluginsListView = function(title, plugins)
  return rx:Div({
    rx:H2(title),
    rx:Div({ class = "plugin-list"}, function()
      local res = {}
      if state.isLoading then
        table.insert(res, rx:Div("Loading..."))
      elseif plugins == nil or #plugins == 0 then
        table.insert(res, rx:Div("None"))
      else
        for name,plugin in pairs(plugins) do
          table.insert(res, PluginLineView(plugin))
        end
      end
      return res
    end)
  })
end

local PluginDetailsView = function()
  if state.isLoadingDetails then
    return rx:Div("Loading: " .. state.selectedPlugin)
  elseif state.selectedPluginDetails ~= nil then
    local plugin = state.selectedPluginDetails --[[@as PluginReleaseInfo]]
    return rx:Div({
      rx:Div({
        class = {
          ["has-icon"] = plugin.Icon and #plugin.Icon > 0,
          icon = true
        }
      }, function ()
        if plugin.Icon and #plugin.Icon > 0 then
          return { rx:Img({ src = ("@plugins/" .. plugin.Name .. "/" .. plugin.Icon)}) }
        else
          return { rx:Div() }
        end
      end),
      rx:H3(plugin.Name, {
        rx:Span(" by " .. plugin.Author)
      }),
      rx:Div(function()
        local res = {}

        if state.installedPlugins ~= nil and state.installedPlugins[plugin.Name] ~= nil then
          local installed = state.installedPlugins[plugin.Name]
          table.insert(res, rx:Div({ class = "action" }, {
            rx:Div("Installed: " .. installed.version, { class = "install"}),
            rx:Button({ 
              class = "secondary uninstall",
              onclick = function()
                (async(function()
                  await(PluginManagerUI:UninstallPlugin(plugin.Name))
                end))()
              end
            }, "Uninstall"),
          }))
        end

        if #plugin.Releases > 0 then
          table.insert(res, rx:Div({ class = "action" }, {
            rx:Div("Version: ", { class="update" }, {
              rx:Select({ id = "selected-version"}, {
                onchange = function(evt)
                  state.selectedVersion = evt.Params.value
                end
              }, function()
                local res = {}
                for k,v in ipairs(plugin.Releases) do
                  if state.showBetas or v.IsBeta == false then 
                    table.insert(res, rx:Option({
                      value = v.Version,
                      onclick = function()
                        state.selectedVersion = v.Version
                      end
                    }, v.Version))
                  end
                end
                return res
              end),
            }),
            rx:Button({ 
              class = "secondary update",
              disabled = state.installedPlugins and state.installedPlugins[plugin.Name] and state.selectedVersion == state.installedPlugins[plugin.Name].version,
              onclick = function()
                print("click")
                if state.installedPlugins and state.installedPlugins[plugin.Name] and state.selectedVersion == state.installedPlugins[plugin.Name].version then
                  return
                else
                  (async(function()
                    local release = nil;
                    for k,v in ipairs(plugin.Releases) do
                      if v.Version == state.selectedVersion then 
                        release = v
                      end
                    end
                    if release ~= nil then
                      await(PluginManagerUI:InstallPlugin(plugin.Name, release.DownloadUrl))
                    else
                      print("Could not find release:", state.selectedVersion)
                    end
                  end))()
                end
              end
            }, "Update"),
          }))
        end

        return res
      end),
      rx:P(plugin.Description),
      rx:H3("Changelog:"),
      rx:Div({ class = "release" }, function()
        local res = {}
        for k,v in ipairs(plugin.Releases) do
          if state.showBetas or v.IsBeta == false then 
            table.insert(res, rx:Div({
              rx:H5(v.Name .. " (" .. v.Date .. ")"),
              rx:P(v.Changelog)
            }))
          end
        end
        return res
      end)
    })
  else
    return rx:Div("Select a plugin from the list on the left")
  end
end

---Plugin Manager View
---@return CS.Core.UI.Lib.RmlUi.VDom.VirtualNode
local PluginManagerView = function()
  return rx:Div({
    rx:Div({ class = "settings" }, {
      rx:Label({
        rx:Input({
          id = "show-betas",
          type = "checkbox",
          checked = state.showBetas,
          onchange = function(evt)
            state.showBetas = #evt.Params.value > 0 and true or false
            -- Reload();
          end
        }),
        rx:Span("Show Betas"),
      }),
      rx:Button({
        class = "refresh",
        onclick = function() Reload() end
      }),
    }),
    rx:Div({ class = "contents" }, {
      rx:Div({ class = "list" }, {
        PluginsListView("Installed Plugins", state.installedPlugins),
        PluginsListView("Available Plugins", state.availablePlugins),
      }),
      rx:Div({ class = "details" }, {
        PluginDetailsView()
      })
    })
  })
end

document:Mount(function() return PluginManagerView() end, "#plugin-manager")

Reload()