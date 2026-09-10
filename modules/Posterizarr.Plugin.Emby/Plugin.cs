using System;
using System.Collections.Generic;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Plugins;
using MediaBrowser.Model.Plugins;
using MediaBrowser.Model.Serialization;
using Posterizarr.Plugin.Configuration;

namespace Posterizarr.Plugin
{
    public class Plugin : BasePlugin<PluginConfiguration>, IHasWebPages
    {
        public override string Name => "Posterizarr Emby";
        public override Guid Id => Guid.Parse("e62d8560-6123-4567-89ab-cdef12345678");
        public override string Description => "Local asset metadata provider and real-time WebSocket sync engine. Instantly maps and updates posters, backgrounds, seasons, and title cards.";

        public static Plugin? Instance { get; private set; }

        public Plugin(IApplicationPaths applicationPaths, IXmlSerializer xmlSerializer)
            : base(applicationPaths, xmlSerializer)
        {
            Instance = this;
        }

        public IEnumerable<PluginPageInfo> GetPages()
        {
            return new[]
            {
                new PluginPageInfo
                {
                    Name = Name,
                    EmbeddedResourcePath = GetType().Namespace + ".Web.configPage.html"
                },
                new PluginPageInfo
                {
                    Name = "PosterizarrConfigjs",
                    EmbeddedResourcePath = GetType().Namespace + ".Web.configPage.js"
                }
            };
        }
    }
}
