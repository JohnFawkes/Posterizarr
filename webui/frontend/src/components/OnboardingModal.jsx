import React, { useState, useEffect } from "react";
import { Check, ChevronRight, ChevronLeft, Save, Server, Key, Settings, Bell, Rocket, Shield, Activity, HardDrive, Database, ExternalLink } from "lucide-react";

const STEPS = [
  { id: "welcome", title: "Welcome", icon: <Rocket className="w-5 h-5" /> },
  { id: "server", title: "Media Server", icon: <Server className="w-5 h-5" /> },
  { id: "keys", title: "API Keys", icon: <Key className="w-5 h-5" /> },
  { id: "auto", title: "Automation", icon: <Settings className="w-5 h-5" /> },
  { id: "perf", title: "Performance", icon: <Activity className="w-5 h-5" /> },
  { id: "notif", title: "Notifications", icon: <Bell className="w-5 h-5" /> },
  { id: "finish", title: "Ready", icon: <Check className="w-5 h-5" /> },
];

export default function OnboardingModal({ onComplete }) {
  const [currentStep, setCurrentStep] = useState(0);
  
  // UI State for selections
  const [primaryServer, setPrimaryServer] = useState(null); // 'plex', 'jellyfin', 'emby'
  const [syncFromPlex, setSyncFromPlex] = useState(false);
  const [plexSyncServer, setPlexSyncServer] = useState(null); // 'jellyfin', 'emby'

  const [config, setConfig] = useState({
    // Server URLs and Tokens
    PlexUrl: "http://192.168.1.93:32400",
    PlexToken: "",
    UsePlex: "false",
    JellyfinUrl: "http://192.168.1.93:8096",
    JellyfinAPIKey: "",
    UseJellyfin: "false",
    EmbyUrl: "http://192.168.1.93:8096/emby",
    EmbyAPIKey: "",
    UseEmby: "false",
    
    // API Keys
    tmdbtoken: "",
    tvdbapi: "",
    FanartTvAPIKey: "",
    
    // Automation
    AssetCleanup: "false",
    SkipJapTitle: "false",
    SkipTBA: "false",
    
    // Performance
    ImageProcessing: "true",
    outputQuality: "92%",
    maxLogs: "5",
    
    // Notifications
    SendNotification: "false",
    Discord: "",
    DiscordUserName: "Posterizarr",
  });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = "unset";
    };
  }, []);

  const handleChange = (key, value) => {
    setConfig(prev => ({ ...prev, [key]: value }));
  };

  const handleNext = () => {
    if (currentStep < STEPS.length - 1) {
      setCurrentStep(prev => prev + 1);
    }
  };

  const handlePrev = () => {
    if (currentStep > 0) {
      setCurrentStep(prev => prev - 1);
    }
  };

  const handleFinish = async () => {
    setSaving(true);
    try {
      const finalConfig = { ...config };
      
      // Enforce Media Server flags based on UI selections
      finalConfig.UsePlex = (primaryServer === 'plex') ? "true" : "false";
      finalConfig.UseJellyfin = (primaryServer === 'jellyfin') ? "true" : "false";
      finalConfig.UseEmby = (primaryServer === 'emby') ? "true" : "false";
      // Note: If syncFromPlex is true, the secondary server URLs/Tokens are sent, but their 'Use' flag remains false.
      
      // Enforce Notification toggle
      if (finalConfig.Discord && finalConfig.Discord.trim() !== "") {
          finalConfig.SendNotification = "true";
      } else {
          finalConfig.SendNotification = "false";
      }
      
      // Save config updates
      await fetch("/api/config", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ config: finalConfig }),
      });
      
      // Mark onboarding as complete
      await fetch("/api/onboarding/complete", {
        method: "POST",
        headers: { "Content-Type": "application/json" }
      });
      
      onComplete();
    } catch (err) {
      console.error("Failed to complete onboarding", err);
    } finally {
      setSaving(false);
    }
  };

  const renderServerForm = (type) => {
    if (type === 'plex') {
      return (
        <div className="mt-4 p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 animate-fade-in">
          <h4 className="font-semibold text-theme-primary mb-3 flex items-center">
            <img src="/plex.png" alt="Plex" className="w-5 h-5 mr-2 object-contain" /> Plex Configuration
          </h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">Plex URL</label>
              <input type="text" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.PlexUrl} onChange={e => handleChange("PlexUrl", e.target.value)} />
            </div>
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">Plex Token</label>
              <input type="password" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.PlexToken} onChange={e => handleChange("PlexToken", e.target.value)} placeholder="Your Plex Token" />
            </div>
          </div>
        </div>
      );
    }
    if (type === 'jellyfin') {
      return (
        <div className="mt-4 p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 animate-fade-in">
          <h4 className="font-semibold text-theme-primary mb-3 flex items-center">
            <img src="/jellyfin.svg" alt="Jellyfin" className="w-5 h-5 mr-2 object-contain" /> Jellyfin Configuration
          </h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">Jellyfin URL</label>
              <input type="text" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.JellyfinUrl} onChange={e => handleChange("JellyfinUrl", e.target.value)} />
            </div>
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">API Key</label>
              <input type="password" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.JellyfinAPIKey} onChange={e => handleChange("JellyfinAPIKey", e.target.value)} placeholder="Jellyfin API Key" />
            </div>
          </div>
        </div>
      );
    }
    if (type === 'emby') {
      return (
        <div className="mt-4 p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 animate-fade-in">
          <h4 className="font-semibold text-theme-primary mb-3 flex items-center">
            <img src="/emby.svg" alt="Emby" className="w-5 h-5 mr-2 object-contain" /> Emby Configuration
          </h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">Emby URL</label>
              <input type="text" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.EmbyUrl} onChange={e => handleChange("EmbyUrl", e.target.value)} />
            </div>
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">API Key</label>
              <input type="password" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.EmbyAPIKey} onChange={e => handleChange("EmbyAPIKey", e.target.value)} placeholder="Emby API Key" />
            </div>
          </div>
        </div>
      );
    }
    return null;
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 0: // Welcome
        return (
          <div className="flex flex-col items-center justify-center text-center space-y-6 animate-fade-in py-10">
            <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-theme-primary to-theme-accent flex items-center justify-center mb-4 shadow-lg shadow-theme-primary/20">
              <Rocket className="w-12 h-12 text-white" />
            </div>
            <h2 className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-white to-theme-text/70 font-outfit">Welcome to Posterizarr</h2>
            <p className="text-theme-muted max-w-md text-lg">
              The ultimate automated tool for standardizing and enhancing your media server's artwork. Let's get you set up in just a few steps!
            </p>
          </div>
        );
      case 1: // Server
        return (
          <div className="space-y-6 animate-fade-in">
            <h3 className="text-2xl font-bold text-white mb-2">Primary Media Server</h3>
            <p className="text-theme-muted mb-6">Select your primary media server that Posterizarr should scan.</p>
            
            <div className="grid grid-cols-3 gap-4 mb-6">
              <button 
                onClick={() => setPrimaryServer('plex')}
                className={`py-4 px-4 rounded-xl border flex flex-col items-center justify-center transition-all ${primaryServer === 'plex' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-lg shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
              >
                <img src="/plex.png" alt="Plex" className="w-10 h-10 mb-3 object-contain drop-shadow-md grayscale-0 opacity-90 transition-opacity" />
                <span className="font-semibold">Plex</span>
              </button>
              <button 
                onClick={() => setPrimaryServer('jellyfin')}
                className={`py-4 px-4 rounded-xl border flex flex-col items-center justify-center transition-all ${primaryServer === 'jellyfin' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-lg shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
              >
                <img src="/jellyfin.svg" alt="Jellyfin" className="w-10 h-10 mb-3 object-contain drop-shadow-md grayscale-0 opacity-90 transition-opacity" />
                <span className="font-semibold">Jellyfin</span>
              </button>
              <button 
                onClick={() => setPrimaryServer('emby')}
                className={`py-4 px-4 rounded-xl border flex flex-col items-center justify-center transition-all ${primaryServer === 'emby' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-lg shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
              >
                <img src="/emby.svg" alt="Emby" className="w-10 h-10 mb-3 object-contain drop-shadow-md grayscale-0 opacity-90 transition-opacity" />
                <span className="font-semibold">Emby</span>
              </button>
            </div>

            {primaryServer && renderServerForm(primaryServer)}

            {primaryServer === 'plex' && (
              <div className="mt-6 border-t border-theme-border/30 pt-6 animate-fade-in">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h4 className="font-semibold text-white">Sync from Plex?</h4>
                    <p className="text-sm text-theme-muted">Do you sync media metadata from Plex to another media server?</p>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox" className="sr-only peer" checked={syncFromPlex} onChange={(e) => {
                      setSyncFromPlex(e.target.checked);
                      if (!e.target.checked) setPlexSyncServer(null);
                    }} />
                    <div className="w-11 h-6 bg-theme-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-theme-primary"></div>
                  </label>
                </div>

                {syncFromPlex && (
                  <div className="space-y-4 animate-fade-in">
                    <p className="text-sm text-theme-muted">Select the secondary server to supply its URL/API Key (it will NOT be enabled for primary scanning):</p>
                    <div className="grid grid-cols-2 gap-4">
                      <button 
                        onClick={() => setPlexSyncServer('jellyfin')}
                        className={`py-3 px-4 rounded-lg border flex items-center justify-center transition-all font-medium ${plexSyncServer === 'jellyfin' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-inner shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
                      >
                        <img src="/jellyfin.svg" alt="Jellyfin" className="w-5 h-5 mr-2 object-contain" /> Jellyfin
                      </button>
                      <button 
                        onClick={() => setPlexSyncServer('emby')}
                        className={`py-3 px-4 rounded-lg border flex items-center justify-center transition-all font-medium ${plexSyncServer === 'emby' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-inner shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
                      >
                        <img src="/emby.svg" alt="Emby" className="w-5 h-5 mr-2 object-contain" /> Emby
                      </button>
                    </div>
                    {plexSyncServer && renderServerForm(plexSyncServer)}
                  </div>
                )}
              </div>
            )}
          </div>
        );
      case 2: // API Keys
        return (
          <div className="space-y-6 animate-fade-in">
            <h3 className="text-2xl font-bold text-white mb-2">API Keys</h3>
            <p className="text-theme-muted mb-6">Required to fetch high-quality artwork from external sources.</p>
            
            <div className="space-y-6">
              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-white flex items-center">
                    <img src="/tmdb.png" alt="TMDb" className="w-6 h-6 mr-2 object-contain rounded" /> TMDb API Token (Required)
                  </label>
                  <a href="https://developer.themoviedb.org/docs/getting-started" target="_blank" rel="noreferrer" className="text-xs text-theme-primary flex items-center hover:underline">
                    How to get TMDb Token <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </div>
                <input type="password" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-all" value={config.tmdbtoken} onChange={e => handleChange("tmdbtoken", e.target.value)} placeholder="v3 API Key / v4 Token" />
              </div>

              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-white flex items-center">
                    <img src="/tvdb.png" alt="TVDb" className="w-6 h-6 mr-2 object-contain rounded bg-white/10 p-0.5" /> TVDb API Key (Optional)
                  </label>
                  <a href="https://thetvdb.com/api-information" target="_blank" rel="noreferrer" className="text-xs text-theme-primary flex items-center hover:underline">
                    How to get TVDb Key <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </div>
                <input type="password" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-all" value={config.tvdbapi} onChange={e => handleChange("tvdbapi", e.target.value)} placeholder="v4 API Key" />
              </div>

              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-white flex items-center">
                    <img src="/fanart.png" alt="Fanart" className="w-6 h-6 mr-2 object-contain rounded" /> Fanart.tv API Key (Optional)
                  </label>
                  <a href="https://fanart.tv/get-an-api-key/" target="_blank" rel="noreferrer" className="text-xs text-theme-primary flex items-center hover:underline">
                    How to get Fanart Key <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </div>
                <input type="password" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-all" value={config.FanartTvAPIKey} onChange={e => handleChange("FanartTvAPIKey", e.target.value)} placeholder="Personal API Key" />
              </div>
            </div>
          </div>
        );
      case 3: // Automation
        return (
          <div className="space-y-6 animate-fade-in">
            <h3 className="text-2xl font-bold text-white mb-2">Automation Preferences</h3>
            <p className="text-theme-muted mb-6">Configure how Posterizarr processes your items automatically.</p>
            
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 hover:border-theme-primary/50 transition-colors">
                <div>
                  <h4 className="font-semibold text-white">Asset Cleanup</h4>
                  <p className="text-sm text-theme-muted">Remove unused assets from storage to free space</p>
                </div>
                <select className="bg-theme-dark border border-theme-border rounded-lg px-3 py-1.5 text-white" value={config.AssetCleanup} onChange={e => handleChange("AssetCleanup", e.target.value)}>
                  <option value="true">Yes</option>
                  <option value="false">No</option>
                </select>
              </div>
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 hover:border-theme-primary/50 transition-colors">
                <div>
                  <h4 className="font-semibold text-white">Skip Japanese/Chinese Titles</h4>
                  <p className="text-sm text-theme-muted">Skip processing Asian media</p>
                </div>
                <select className="bg-theme-dark border border-theme-border rounded-lg px-3 py-1.5 text-white" value={config.SkipJapTitle} onChange={e => handleChange("SkipJapTitle", e.target.value)}>
                  <option value="true">Yes</option>
                  <option value="false">No</option>
                </select>
              </div>
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 hover:border-theme-primary/50 transition-colors">
                <div>
                  <h4 className="font-semibold text-white">Skip TBA Items</h4>
                  <p className="text-sm text-theme-muted">Skip items that are "To Be Announced"</p>
                </div>
                <select className="bg-theme-dark border border-theme-border rounded-lg px-3 py-1.5 text-white" value={config.SkipTBA} onChange={e => handleChange("SkipTBA", e.target.value)}>
                  <option value="true">Yes</option>
                  <option value="false">No</option>
                </select>
              </div>
            </div>
          </div>
        );
      case 4: // Performance
        return (
          <div className="space-y-6 animate-fade-in">
            <h3 className="text-2xl font-bold text-white mb-2">Performance & Quality</h3>
            <p className="text-theme-muted mb-6">Tune resource usage and output quality.</p>
            
            <div className="space-y-5">
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div>
                  <h4 className="font-semibold text-white">Image Processing</h4>
                  <p className="text-sm text-theme-muted">Use advanced ImageMagick processing</p>
                </div>
                <select className="bg-theme-dark border border-theme-border rounded-lg px-3 py-1.5 text-white" value={config.ImageProcessing} onChange={e => handleChange("ImageProcessing", e.target.value)}>
                  <option value="true">Enabled</option>
                  <option value="false">Disabled</option>
                </select>
              </div>

              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div>
                  <h4 className="font-semibold text-white">Output Quality</h4>
                  <p className="text-sm text-theme-muted">Set JPEG quality compression</p>
                </div>
                <input type="text" className="w-24 bg-theme-dark border border-theme-border rounded-lg px-3 py-1.5 text-white text-right" value={config.outputQuality} onChange={e => handleChange("outputQuality", e.target.value)} />
              </div>
              
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div>
                  <h4 className="font-semibold text-white">Max Logs Retained</h4>
                  <p className="text-sm text-theme-muted">Number of previous run logs to keep</p>
                </div>
                <input type="number" min="1" max="50" className="w-24 bg-theme-dark border border-theme-border rounded-lg px-3 py-1.5 text-white text-right" value={config.maxLogs} onChange={e => handleChange("maxLogs", e.target.value)} />
              </div>
            </div>
          </div>
        );
      case 5: // Notifications
        return (
          <div className="space-y-6 animate-fade-in">
            <h3 className="text-2xl font-bold text-white mb-2">Notifications</h3>
            <p className="text-theme-muted mb-6">Configure a Discord webhook for run completion alerts.</p>
            
            <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
              <label className="block text-sm font-medium text-white mb-2">Discord Webhook URL (Optional)</label>
              <input type="text" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" placeholder="https://discordapp.com/api/webhooks/..." value={config.Discord} onChange={e => handleChange("Discord", e.target.value)} />
              <p className="text-xs text-theme-muted mt-2">Leave blank to keep notifications disabled.</p>

              {config.Discord && (
                <div className="mt-4 pt-4 border-t border-theme-border/30">
                  <label className="block text-sm font-medium text-white mb-2">Discord Bot Name</label>
                  <input type="text" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.DiscordUserName} onChange={e => handleChange("DiscordUserName", e.target.value)} />
                </div>
              )}
            </div>
          </div>
        );
      case 6: // Finish
        return (
          <div className="flex flex-col items-center justify-center text-center space-y-6 animate-fade-in py-10">
            <div className="w-20 h-20 rounded-full bg-green-500/20 flex items-center justify-center mb-4 text-green-500 ring-4 ring-green-500/10">
              <Check className="w-10 h-10" />
            </div>
            <h2 className="text-3xl font-bold text-white">All Set!</h2>
            <p className="text-theme-muted max-w-md">
              Your configuration has been prepared. Click finish to save these settings and start exploring PosterizarrUI.
            </p>
            <div className="mt-8 p-4 bg-theme-bg/50 rounded-xl border border-theme-border text-sm text-theme-muted inline-flex items-center">
              <Shield className="w-4 h-4 mr-2 text-theme-primary" />
              You can change these settings anytime in the Config Editor.
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 font-sans">
      <div className="bg-theme-darker w-full max-w-4xl rounded-2xl shadow-2xl border border-theme-border/50 overflow-hidden flex flex-col md:flex-row h-full max-h-[600px] animate-scale-in">
        
        {/* Left Sidebar - Stepper */}
        <div className="w-full md:w-64 bg-theme-dark border-r border-theme-border/30 p-6 flex flex-col shrink-0 hidden md:flex">
          <div className="mb-8">
            <h1 className="text-xl font-bold text-white tracking-tight flex items-center">
              <Rocket className="w-6 h-6 mr-2 text-theme-primary" />
              Posterizarr
            </h1>
          </div>
          
          <div className="flex-1 space-y-1">
            {STEPS.map((step, index) => {
              const isActive = index === currentStep;
              const isPast = index < currentStep;
              return (
                <div 
                  key={step.id} 
                  className={`flex items-center px-4 py-3 rounded-xl transition-all duration-300 ${
                    isActive ? "bg-theme-primary/10 text-theme-primary" :
                    isPast ? "text-white hover:bg-theme-bg/50 cursor-pointer" : "text-theme-muted"
                  }`}
                  onClick={() => isPast && setCurrentStep(index)}
                >
                  <div className={`mr-3 ${isActive ? "text-theme-primary" : isPast ? "text-green-500" : "text-theme-muted"}`}>
                    {isPast ? <Check className="w-5 h-5" /> : step.icon}
                  </div>
                  <span className={`font-medium ${isActive ? "font-semibold" : ""}`}>{step.title}</span>
                </div>
              );
            })}
          </div>
        </div>
        
        {/* Main Content Area */}
        <div className="flex-1 flex flex-col relative overflow-hidden bg-gradient-to-br from-theme-darker to-theme-dark">
          {/* Mobile Stepper (visible only on small screens) */}
          <div className="md:hidden flex p-4 border-b border-theme-border/30 items-center justify-between bg-theme-dark">
            <span className="text-sm font-semibold text-theme-primary">Step {currentStep + 1} of {STEPS.length}</span>
            <span className="text-sm text-theme-muted">{STEPS[currentStep].title}</span>
          </div>

          <div className="flex-1 overflow-y-auto p-6 md:p-10 scrollbar-thin scrollbar-thumb-theme-border scrollbar-track-transparent">
            {renderStepContent()}
          </div>
          
          {/* Footer Actions */}
          <div className="p-6 bg-theme-darker border-t border-theme-border/30 flex justify-between items-center shrink-0">
            <button
              onClick={handlePrev}
              disabled={currentStep === 0 || saving}
              className={`flex items-center px-5 py-2.5 rounded-lg font-medium transition-colors ${
                currentStep === 0 
                  ? "opacity-0 cursor-default" 
                  : "text-theme-muted hover:text-white hover:bg-theme-bg"
              }`}
            >
              <ChevronLeft className="w-5 h-5 mr-1" />
              Back
            </button>
            
            {currentStep < STEPS.length - 1 ? (
              <button
                onClick={handleNext}
                disabled={currentStep === 1 && !primaryServer}
                className="flex items-center px-6 py-2.5 bg-theme-primary text-white rounded-lg font-medium shadow-lg shadow-theme-primary/20 hover:bg-theme-accent hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Continue
                <ChevronRight className="w-5 h-5 ml-1" />
              </button>
            ) : (
              <button
                onClick={handleFinish}
                disabled={saving}
                className="flex items-center px-8 py-2.5 bg-gradient-to-r from-theme-primary to-theme-accent text-white rounded-lg font-bold shadow-lg shadow-theme-primary/30 hover:shadow-theme-primary/50 hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving ? (
                  <span className="flex items-center">
                    <Activity className="w-5 h-5 mr-2 animate-spin" /> Saving...
                  </span>
                ) : (
                  <span className="flex items-center">
                    Finish Setup <Save className="w-5 h-5 ml-2" />
                  </span>
                )}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
