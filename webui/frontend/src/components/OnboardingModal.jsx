import React, { useState, useEffect } from "react";
import { Check, ChevronRight, ChevronLeft, Save, Server, Key, Settings, Bell, Rocket, Shield, Activity, HardDrive, Database, ExternalLink, Loader2, Clock } from "lucide-react";
import ValidateButton from "./ValidateButton";
import LibraryExclusionSelector from "./LibraryExclusionSelector";

const STEPS = [
  { id: "welcome", title: "Welcome", icon: <Rocket className="w-5 h-5" /> },
  { id: "server", title: "Media Server", icon: <Server className="w-5 h-5" /> },
  { id: "keys", title: "API Keys", icon: <Key className="w-5 h-5" /> },
  { id: "auto", title: "Automation", icon: <Settings className="w-5 h-5" /> },
  { id: "perf", title: "Performance", icon: <Activity className="w-5 h-5" /> },
  { id: "notif", title: "Notifications", icon: <Bell className="w-5 h-5" /> },
  { id: "schedule", title: "Schedule", icon: <Clock className="w-5 h-5" /> },
  { id: "finish", title: "Ready", icon: <Check className="w-5 h-5" /> },
];

export default function OnboardingModal({ onComplete }) {
  const [currentStep, setCurrentStep] = useState(0);
  
  // UI State for selections
  const [primaryServer, setPrimaryServer] = useState(null); // 'plex', 'jellyfin', 'emby'
  const [syncFromPlex, setSyncFromPlex] = useState(false);
  const [plexSyncServer, setPlexSyncServer] = useState(null); // 'jellyfin', 'emby'
  const [enableBasicSchedule, setEnableBasicSchedule] = useState(false);
  const [scheduleTime, setScheduleTime] = useState("03:00");
  const [notificationType, setNotificationType] = useState('none'); // 'none', 'discord', 'apprise'

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
    AppriseUrl: "",
  });
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    document.body.style.overflow = "hidden";
    
    // Fetch full config to prevent overwriting missing keys on save
    const fetchConfig = async () => {
      try {
        const response = await fetch('/api/config');
        const data = await response.json();
        if (data.success && data.config) {
          // Merge existing config into state so we don't lose anything
          const newConfig = { ...data.config, ...prev };
          setConfig(newConfig);
          if (newConfig.Discord) setNotificationType('discord');
          else if (newConfig.AppriseUrl) setNotificationType('apprise');
        }
      } catch (err) {
        console.error("Failed to fetch initial config", err);
      } finally {
        setLoading(false);
      }
    };
    
    fetchConfig();

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
      if (notificationType === 'discord') {
          finalConfig.SendNotification = finalConfig.Discord ? "true" : "false";
          finalConfig.AppriseUrl = "";
      } else if (notificationType === 'apprise') {
          finalConfig.SendNotification = finalConfig.AppriseUrl ? "true" : "false";
          finalConfig.Discord = "";
          finalConfig.DiscordUserName = "";
      } else {
          finalConfig.SendNotification = "false";
          finalConfig.Discord = "";
          finalConfig.AppriseUrl = "";
      }
      
      // Save config updates
      await fetch("/api/config", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ config: finalConfig }),
      });
      
      // Save Schedule if enabled
      if (enableBasicSchedule) {
        try {
          await fetch("/api/scheduler/enable", { method: "POST" });
          await fetch("/api/scheduler/schedule", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              time: scheduleTime,
              frequency: "daily",
              mode: "normal",
              description: "Default Onboarding Schedule",
              month: "*",
              day: "*",
              day_of_week: "*"
            })
          });
        } catch (scheduleErr) {
          console.error("Failed to setup schedule during onboarding", scheduleErr);
        }
      }
      
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
            <img src="/plex.svg" alt="Plex" className="w-5 h-5 mr-2 object-contain" /> Plex Configuration
          </h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-theme-muted mb-1">Plex URL</label>
              <input type="text" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.PlexUrl} onChange={e => handleChange("PlexUrl", e.target.value)} />
            </div>
            <div>
              <label className="flex items-center justify-between text-sm font-medium text-theme-muted mb-1">
                Plex Token
                <a href="https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/" target="_blank" rel="noreferrer" className="text-xs text-theme-primary hover:underline font-normal">
                  How to find this?
                </a>
              </label>
              <input type="password" className="w-full bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.PlexToken} onChange={e => handleChange("PlexToken", e.target.value)} placeholder="Your Plex Token" />
            </div>
          </div>
          <div className="mt-4 flex justify-end">
            <ValidateButton type="plex" config={config} label="Test Connection" disabled={!config.PlexUrl || !config.PlexToken} />
          </div>
          <div className="mt-6 border-t border-theme-border/30 pt-4">
            <LibraryExclusionSelector 
              value={config.PlexLibstoExclude || []}
              onChange={(val) => handleChange('PlexLibstoExclude', val)}
              label="Library Selection"
              helpText="Select which libraries Posterizarr should scan. Deselected libraries will be excluded."
              mediaServerType="plex"
              config={config}
              disabled={!config.PlexUrl || !config.PlexToken}
            />
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
          <div className="mt-4 flex justify-end">
            <ValidateButton type="jellyfin" config={config} label="Test Connection" disabled={!config.JellyfinUrl || !config.JellyfinAPIKey} />
          </div>
          <div className="mt-6 border-t border-theme-border/30 pt-4">
            <LibraryExclusionSelector 
              value={config.JellyfinLibstoExclude || []}
              onChange={(val) => handleChange('JellyfinLibstoExclude', val)}
              label="Library Selection"
              helpText="Select which libraries Posterizarr should scan. Deselected libraries will be excluded."
              mediaServerType="jellyfin"
              config={config}
              disabled={!config.JellyfinUrl || !config.JellyfinAPIKey}
            />
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
          <div className="mt-4 flex justify-end">
            <ValidateButton type="emby" config={config} label="Test Connection" disabled={!config.EmbyUrl || !config.EmbyAPIKey} />
          </div>
          <div className="mt-6 border-t border-theme-border/30 pt-4">
            <LibraryExclusionSelector 
              value={config.EmbyLibstoExclude || []}
              onChange={(val) => handleChange('EmbyLibstoExclude', val)}
              label="Library Selection"
              helpText="Select which libraries Posterizarr should scan. Deselected libraries will be excluded."
              mediaServerType="emby"
              config={config}
              disabled={!config.EmbyUrl || !config.EmbyAPIKey}
            />
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
                <img src="/plex.svg" alt="Plex" className="w-12 h-12 mb-3 object-contain drop-shadow-md opacity-90 transition-transform hover:scale-110" />
                <span className="font-semibold">Plex</span>
              </button>
              <button 
                onClick={() => setPrimaryServer('jellyfin')}
                className={`py-4 px-4 rounded-xl border flex flex-col items-center justify-center transition-all ${primaryServer === 'jellyfin' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-lg shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
              >
                <img src="/jellyfin.svg" alt="Jellyfin" className="w-12 h-12 mb-3 object-contain drop-shadow-md opacity-90 transition-transform hover:scale-110" />
                <span className="font-semibold">Jellyfin</span>
              </button>
              <button 
                onClick={() => setPrimaryServer('emby')}
                className={`py-4 px-4 rounded-xl border flex flex-col items-center justify-center transition-all ${primaryServer === 'emby' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-lg shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
              >
                <img src="/emby.svg" alt="Emby" className="w-12 h-12 mb-3 object-contain drop-shadow-md opacity-90 transition-transform hover:scale-110" />
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
                <div className="mt-4 flex justify-end">
                  <ValidateButton type="tmdb" config={config} label="Test Connection" disabled={!config.tmdbtoken} />
                </div>
              </div>

              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-white flex items-center">
                    <img src="/tvdb.png" alt="TVDb" className="w-6 h-6 mr-2 object-contain rounded bg-white/10 p-0.5" /> TVDb API Key (Required)
                  </label>
                  <a href="https://thetvdb.com/api-information" target="_blank" rel="noreferrer" className="text-xs text-theme-primary flex items-center hover:underline">
                    How to get TVDb Key <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </div>
                <input type="password" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-all" value={config.tvdbapi} onChange={e => handleChange("tvdbapi", e.target.value)} placeholder="v4 API Key" />
                <div className="mt-4 flex justify-end">
                  <ValidateButton type="tvdb" config={config} label="Test Connection" disabled={!config.tvdbapi} />
                </div>
              </div>

              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-white flex items-center">
                    <img src="/fanart.png" alt="Fanart" className="w-6 h-6 mr-2 object-contain rounded" /> Fanart.tv API Key (Required)
                  </label>
                  <a href="https://fanart.tv/get-an-api-key/" target="_blank" rel="noreferrer" className="text-xs text-theme-primary flex items-center hover:underline">
                    How to get Fanart Key <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </div>
                <input type="password" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-all" value={config.FanartTvAPIKey} onChange={e => handleChange("FanartTvAPIKey", e.target.value)} placeholder="Personal API Key" />
                <div className="mt-4 flex justify-end">
                  <ValidateButton type="fanart" config={config} label="Test Connection" disabled={!config.FanartTvAPIKey} />
                </div>
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
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" className="sr-only peer" checked={config.AssetCleanup === "true"} onChange={e => handleChange("AssetCleanup", e.target.checked ? "true" : "false")} />
                  <div className="w-11 h-6 bg-theme-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-theme-primary"></div>
                </label>
              </div>
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 hover:border-theme-primary/50 transition-colors">
                <div>
                  <h4 className="font-semibold text-white">Skip Japanese/Chinese Titles</h4>
                  <p className="text-sm text-theme-muted">Skip processing Asian media</p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" className="sr-only peer" checked={config.SkipJapTitle === "true"} onChange={e => handleChange("SkipJapTitle", e.target.checked ? "true" : "false")} />
                  <div className="w-11 h-6 bg-theme-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-theme-primary"></div>
                </label>
              </div>
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 hover:border-theme-primary/50 transition-colors">
                <div>
                  <h4 className="font-semibold text-white">Skip TBA Items</h4>
                  <p className="text-sm text-theme-muted">Skip items that are "To Be Announced"</p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" className="sr-only peer" checked={config.SkipTBA === "true"} onChange={e => handleChange("SkipTBA", e.target.checked ? "true" : "false")} />
                  <div className="w-11 h-6 bg-theme-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-theme-primary"></div>
                </label>
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
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" className="sr-only peer" checked={config.ImageProcessing === "true"} onChange={e => handleChange("ImageProcessing", e.target.checked ? "true" : "false")} />
                  <div className="w-11 h-6 bg-theme-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-theme-primary"></div>
                </label>
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
            <p className="text-theme-muted mb-6">Receive alerts when Posterizarr completes a run.</p>
            
            <div className="grid grid-cols-3 gap-4 mb-6">
              <button 
                onClick={() => setNotificationType('none')}
                className={`py-3 px-4 rounded-lg border flex flex-col items-center justify-center transition-all font-medium ${notificationType === 'none' ? 'bg-theme-primary/10 border-theme-primary text-theme-primary shadow-inner shadow-theme-primary/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-theme-primary/50'}`}
              >
                None
              </button>
              <button 
                onClick={() => setNotificationType('discord')}
                className={`py-3 px-4 rounded-lg border flex flex-col items-center justify-center transition-all font-medium ${notificationType === 'discord' ? 'bg-[#5865F2]/10 border-[#5865F2] text-[#5865F2] shadow-inner shadow-[#5865F2]/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-[#5865F2]/50'}`}
              >
                Discord
              </button>
              <button 
                onClick={() => setNotificationType('apprise')}
                className={`py-3 px-4 rounded-lg border flex flex-col items-center justify-center transition-all font-medium ${notificationType === 'apprise' ? 'bg-green-500/10 border-green-500 text-green-500 shadow-inner shadow-green-500/10' : 'bg-theme-dark border-theme-border text-theme-muted hover:border-green-500/50'}`}
              >
                Apprise
              </button>
            </div>

            {notificationType === 'discord' && (
              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 animate-fade-in">
                <label className="block text-sm font-medium text-white mb-2">Discord Webhook URL</label>
                <input type="text" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" placeholder="https://discordapp.com/api/webhooks/..." value={config.Discord} onChange={e => handleChange("Discord", e.target.value)} />
                
                <div className="mt-4 pt-4 border-t border-theme-border/30">
                  <label className="block text-sm font-medium text-white mb-2">Discord Bot Name</label>
                  <input type="text" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" value={config.DiscordUserName} onChange={e => handleChange("DiscordUserName", e.target.value)} />
                </div>
              </div>
            )}

            {notificationType === 'apprise' && (
              <div className="p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 animate-fade-in">
                <div className="flex justify-between items-center mb-2">
                  <label className="text-sm font-medium text-white flex items-center">
                    Apprise URL
                  </label>
                  <a href="https://github.com/caronc/apprise/wiki" target="_blank" rel="noreferrer" className="text-xs text-theme-primary flex items-center hover:underline">
                    How-to guide <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </div>
                <input type="text" className="w-full bg-theme-dark/50 border border-theme-border rounded-lg px-4 py-2.5 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-colors" placeholder="discord://webhook_id/webhook_token" value={config.AppriseUrl} onChange={e => handleChange("AppriseUrl", e.target.value)} />
                <p className="text-xs text-theme-muted mt-2">Uses Apprise - supports Discord, Slack, Telegram, email, and 70+ more via URL schemes.</p>
                <div className="mt-4 flex justify-end">
                  <ValidateButton type="apprise" config={config} label="Test Connection" disabled={!config.AppriseUrl} />
                </div>
              </div>
            )}
          </div>
        );
      case 6: // Schedule
        return (
          <div className="space-y-6 animate-fade-in">
            <h3 className="text-2xl font-bold text-white mb-2">Automated Schedule</h3>
            <p className="text-theme-muted mb-6">Set up a daily automated run. You can configure more complex schedules later.</p>
            
            <div className="space-y-5">
              <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50">
                <div>
                  <h4 className="font-semibold text-white">Enable Daily Automation</h4>
                  <p className="text-sm text-theme-muted">Run Posterizarr automatically every day</p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" className="sr-only peer" checked={enableBasicSchedule} onChange={e => setEnableBasicSchedule(e.target.checked)} />
                  <div className="w-11 h-6 bg-theme-bg peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-theme-primary"></div>
                </label>
              </div>

              {enableBasicSchedule && (
                <div className="flex items-center justify-between p-4 bg-theme-bg/50 rounded-xl border border-theme-border/50 animate-fade-in">
                  <div>
                    <h4 className="font-semibold text-white">Daily Run Time</h4>
                    <p className="text-sm text-theme-muted">Time to start processing (HH:MM)</p>
                  </div>
                  <input type="time" className="bg-theme-dark border border-theme-border rounded-lg px-4 py-2 text-white focus:border-theme-primary focus:ring-1 focus:ring-theme-primary transition-all" value={scheduleTime} onChange={e => setScheduleTime(e.target.value)} required />
                </div>
              )}
            </div>
          </div>
        );
      case 7: // Finish
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

  if (loading) {
    return (
      <div 
        className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 font-sans"
        style={{
          '--theme-primary': '#e5a00d', 
          '--theme-primary-hover': '#cc8f0c', 
          '--theme-accent': '#ffc107'
        }}
      >
        <div className="flex flex-col items-center">
          <Loader2 className="w-10 h-10 animate-spin text-theme-primary mb-4" />
          <p className="text-white font-medium">Preparing environment...</p>
        </div>
      </div>
    );
  }

  return (
    <div 
      className="fixed inset-0 z-[10000] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 font-sans"
      style={{
        '--theme-primary': '#e5a00d', 
        '--theme-primary-hover': '#cc8f0c', 
        '--theme-accent': '#ffc107'
      }}
    >
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
                disabled={
                  (currentStep === 1 && !primaryServer) ||
                  (currentStep === 2 && (!config.tmdbtoken || !config.tvdbapi || !config.FanartTvAPIKey))
                }
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
