using System.IO;
using System;
using Microsoft.Extensions.Logging;
using Chorizite.Core.Plugins;
using Chorizite.Core.Plugins.AssemblyLoader;
using Chorizite.Core;
using System.Threading.Tasks;
using System.Net.Http;
using System.IO.Compression;
using RmlUi;
using RmlUi.Lib;

namespace PluginManagerUI {
    /// <summary>
    /// Plugin manager UI
    /// </summary>
    public class PluginManagerUICore : IPluginCore {
        internal static ILogger? Log;
        private Panel? _panel;
        private HttpClient _http = new HttpClient();

        internal RmlUiPlugin UI { get; }
        internal IPluginManager Manager { get; }

        /// <summary>
        /// Plugin manager UI
        /// </summary>
        /// <param name="manifest"></param>
        /// <param name="manager"></param>
        /// <param name="coreUI"></param>
        /// <param name="log"></param>
        protected PluginManagerUICore(AssemblyPluginManifest manifest, IPluginManager manager, RmlUiPlugin coreUI, ILogger log) : base(manifest) {
            Log = log;
            UI = coreUI;
            Manager = manager;
        }

        /// <inheritdoc/>
        protected override void Initialize() {
            _panel = UI.CreatePanel("PluginManagerUI", Path.Combine(AssemblyDirectory, "assets", "manager.rml"));
            
            if (_panel is not null) {
                _panel.ShowInBar = true;
            }
        }

        /// <summary>
        /// Uninstall a plugin
        /// </summary>
        /// <param name="id"></param>
        /// <param name="reload"></param>
        /// <returns></returns>
        public bool UninstallPlugin(string id, bool reload = true) {
            try {
                if (Directory.Exists(Path.Combine(Manager.PluginDirectory, id))) {
                    Directory.Delete(Path.Combine(Manager.PluginDirectory, id), true);
                    if (reload) {
                        Manager.ReloadPlugins();
                    }
                    return true;
                }
                return false;
            }
            catch (Exception ex) {
                Log?.LogError(ex, "Failed to uninstall plugin");
                return false;
            }
        }

        /// <summary>
        /// Install a plugin by id and zip url / file
        /// </summary>
        /// <param name="id">The id of the plugin</param>
        /// <param name="zipUri">A url or local file path to the zip that contains the plugin.</param>
        /// <param name="reload"></param>
        /// <returns>True if successful</returns>
        public async Task<bool> InstallPlugin(string id, string zipUri, bool reload = true) {
            var zipTmpPath = Path.GetTempFileName();
            try {
                byte[] zipBytes;
                if (zipUri.StartsWith("http")) {
                    zipBytes = await _http.GetByteArrayAsync(zipUri);
                }
                else {
                    zipBytes = File.ReadAllBytes(zipUri);
                }
                File.WriteAllBytes(zipTmpPath, zipBytes);
                var zip = ZipFile.OpenRead(zipTmpPath);
                var pluginDir = Path.Combine(Manager.PluginDirectory, id);
                if (Directory.Exists(pluginDir)) {
                    Directory.Delete(pluginDir, true);
                }
                if (!Directory.Exists(pluginDir)) {
                    Directory.CreateDirectory(pluginDir);
                }
                zip.ExtractToDirectory(pluginDir, true);
                
                if (reload) {
                    Manager.ReloadPlugins();
                }
                return true;
            }
            catch (Exception ex) {
                Log?.LogError(ex, "Failed to install plugin");
                return false;
            }
            finally {
                try {
                    File.Delete(zipTmpPath);
                }
                catch { }
            }
        }

        /// <inheritdoc/>
        protected override void Dispose() {
            _panel?.Dispose();
            _http?.Dispose();
        }
    }
}
