import React, { useState, useEffect, useRef } from "react";
import { Loader2, Palette, Image, Layers, CheckCircle2, AlertCircle, Type, Square, Languages, Sparkles, Download, Upload, Info, Sliders, LayoutTemplate, ChevronDown, ChevronRight, Settings } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useToast } from "../context/ToastContext";

const API_URL = "/api";

const BLUEPRINTS = [
  {
    id: "clearlogo-instead-of-text",
    titleKey: "blueprints.items.clearlogo.title",
    descriptionKey: "blueprints.items.clearlogo.description",
    icon: Image,
    images: ["/blueprint-previews/clearlogo-instead-of-text_poster.png", "/blueprint-previews/clearlogo-instead-of-text_background.png"],
    updates: {
      flat: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "true", UseClearart: "false", ConvertLogoColor: "false", PosterAddText: "true", BackgroundAddText: "true" },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "true", UseClearart: "false", ConvertLogoColor: "false" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "clearart-instead-of-text",
    titleKey: "blueprints.items.clearart.title",
    descriptionKey: "blueprints.items.clearart.description",
    icon: Image,
    images: ["/blueprint-previews/clearart-instead-of-text_poster.png", "/blueprint-previews/clearart-instead-of-text_background.png"],
    updates: {
      flat: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "false", UseClearart: "true", ConvertLogoColor: "false", PosterAddText: "true", BackgroundAddText: "true" },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "false", UseClearart: "true", ConvertLogoColor: "false" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "flat-clearlogo-instead-of-text",
    titleKey: "blueprints.items.flatClearlogo.title",
    descriptionKey: "blueprints.items.flatClearlogo.description",
    icon: Image,
    images: ["/blueprint-previews/flat-clearlogo-instead-of-text_poster.png", "/blueprint-previews/flat-clearlogo-instead-of-text_background.png"],
    updates: {
      flat: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "true", UseClearart: "false", ConvertLogoColor: "true", LogoFlatColor: "white", PosterAddText: "true", BackgroundAddText: "true" },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "true", UseClearart: "false", ConvertLogoColor: "true", LogoFlatColor: "white" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "flat-clearart-instead-of-text",
    titleKey: "blueprints.items.flatClearart.title",
    descriptionKey: "blueprints.items.flatClearart.description",
    icon: Image,
    images: ["/blueprint-previews/flat-clearart-instead-of-text_poster.png", "/blueprint-previews/flat-clearart-instead-of-text_background.png"],
    updates: {
      flat: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "false", UseClearart: "true", ConvertLogoColor: "true", LogoFlatColor: "white", PosterAddText: "true", BackgroundAddText: "true" },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "false", UseClearart: "true", ConvertLogoColor: "true", LogoFlatColor: "white" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "show-title-on-season",
    titleKey: "blueprints.items.showTitleSeason.title",
    descriptionKey: "blueprints.items.showTitleSeason.description",
    icon: Type,
    images: ["/blueprint-previews/show-title-on-season.png"],
    updates: { flat: { ShowTitleAddShowTitletoSeason: "true" }, nested: { ShowTitleOnSeasonPosterPart: { AddShowTitletoSeason: "true" } } }
  },
  {
    id: "minimalist-posters",
    titleKey: "blueprints.items.minimalist.title",
    descriptionKey: "blueprints.items.minimalist.description",
    icon: Palette,
    images: ["/blueprint-previews/minimalist-posters_en.png", "/blueprint-previews/minimalist-posters_textless.png", "/blueprint-previews/minimalist-posters_textless_background.png"],
    updates: { flat: { ImageProcessing: "false" }, nested: { OverlayPart: { ImageProcessing: "false" } } }
  },
  {
    id: "full-overlays",
    titleKey: "blueprints.items.fullOverlays.title",
    descriptionKey: "blueprints.items.fullOverlays.description",
    icon: Layers,
    images: ["/blueprint-previews/full-overlays.png", "/blueprint-previews/full-overlays_background-small.png"],
    updates: {
      flat: { PosterAddBorder: "true", PosterAddText: "true", PosterAddOverlay: "true", SeasonPosterAddBorder: "true", SeasonPosterAddText: "true", SeasonPosterAddOverlay: "true", BackgroundAddBorder: "true", BackgroundAddText: "true", BackgroundAddOverlay: "true", TitleCardAddOverlay: "true", TitleCardAddBorder: "true", TitleCardTitleAddEPTitleText: "true", TitleCardEPAddEPText: "true" },
      nested: {
        PosterOverlayPart: { AddBorder: "true", AddText: "true", AddOverlay: "true" },
        SeasonPosterOverlayPart: { AddBorder: "true", AddText: "true", AddOverlay: "true" },
        BackgroundOverlayPart: { AddBorder: "true", AddText: "true", AddOverlay: "true" },
        TitleCardOverlayPart: { AddOverlay: "true", AddBorder: "true" },
        TitleCardTitleTextPart: { AddEPTitleText: "true" },
        TitleCardEPTextPart: { AddEPText: "true" }
      }
    }
  },
  {
    id: "resolution-overlays",
    titleKey: "blueprints.items.resolutionOverlays.title",
    descriptionKey: "blueprints.items.resolutionOverlays.description",
    icon: Sparkles,
    images: ["/blueprint-previews/resolution-overlays_poster4k.png", "/blueprint-previews/resolution-overlays_Background4k.png", "/blueprint-previews/resolution-overlays_4KDoVi.png", "/blueprint-previews/resolution-overlays_4KHDR10.png", "/blueprint-previews/resolution-overlays_4KDoViHDR10.png"],
    updates: { flat: { UsePosterResolutionOverlays: "true", UseBackgroundResolutionOverlays: "true", UseTCResolutionOverlays: "true" }, nested: { PrerequisitePart: { UsePosterResolutionOverlays: "true", UseBackgroundResolutionOverlays: "true", UseTCResolutionOverlays: "true" } } }
  },
  {
    id: "only-borders",
    titleKey: "blueprints.items.onlyBorders.title",
    descriptionKey: "blueprints.items.onlyBorders.description",
    icon: Square,
    images: ["/blueprint-previews/only-borders.png", "/blueprint-previews/only-borders_background.png"],
    updates: {
      flat: { PosterAddBorder: "true", PosterAddText: "false", PosterAddOverlay: "false", SeasonPosterAddBorder: "true", SeasonPosterAddText: "false", SeasonPosterAddOverlay: "false", ShowTitleAddShowTitletoSeason: "false", BackgroundAddBorder: "true", BackgroundAddText: "false", BackgroundAddOverlay: "false", TitleCardAddBorder: "true", TitleCardAddOverlay: "false", TitleCardTitleAddEPTitleText: "false", TitleCardEPAddEPText: "false" },
      nested: {
        PosterOverlayPart: { AddBorder: "true", AddText: "false", AddOverlay: "false" },
        SeasonPosterOverlayPart: { AddBorder: "true", AddText: "false", AddOverlay: "false" },
        ShowTitleOnSeasonPosterPart: { AddShowTitletoSeason: "false" },
        BackgroundOverlayPart: { AddBorder: "true", AddText: "false", AddOverlay: "false" },
        TitleCardOverlayPart: { AddBorder: "true", AddOverlay: "false" },
        TitleCardTitleTextPart: { AddEPTitleText: "false" },
        TitleCardEPTextPart: { AddEPText: "false" }
      }
    }
  },
  {
    id: "only-text",
    titleKey: "blueprints.items.onlyText.title",
    descriptionKey: "blueprints.items.onlyText.description",
    icon: Type,
    images: ["/blueprint-previews/only-text.png", "/blueprint-previews/only-text_background.png"],
    updates: {
      flat: { PosterAddBorder: "false", PosterAddText: "true", PosterAddOverlay: "false", SeasonPosterAddBorder: "false", SeasonPosterAddText: "true", SeasonPosterAddOverlay: "false", ShowTitleAddShowTitletoSeason: "true", BackgroundAddBorder: "false", BackgroundAddText: "true", BackgroundAddOverlay: "false", TitleCardAddBorder: "false", TitleCardAddOverlay: "false", TitleCardTitleAddEPTitleText: "true", TitleCardEPAddEPText: "true" },
      nested: {
        PosterOverlayPart: { AddBorder: "false", AddText: "true", AddOverlay: "false" },
        SeasonPosterOverlayPart: { AddBorder: "false", AddText: "true", AddOverlay: "false" },
        ShowTitleOnSeasonPosterPart: { AddShowTitletoSeason: "true" },
        BackgroundOverlayPart: { AddBorder: "false", AddText: "true", AddOverlay: "false" },
        TitleCardOverlayPart: { AddBorder: "false", AddOverlay: "false" },
        TitleCardTitleTextPart: { AddEPTitleText: "true" },
        TitleCardEPTextPart: { AddEPText: "true" }
      }
    }
  },
  {
    id: "only-overlays",
    titleKey: "blueprints.items.onlyOverlays.title",
    descriptionKey: "blueprints.items.onlyOverlays.description",
    icon: Layers,
    images: ["/blueprint-previews/only-overlays.png", "/blueprint-previews/only-overlays_background.png"],
    updates: {
      flat: { PosterAddBorder: "false", PosterAddText: "false", PosterAddOverlay: "true", SeasonPosterAddBorder: "false", SeasonPosterAddText: "false", SeasonPosterAddOverlay: "true", ShowTitleAddShowTitletoSeason: "false", BackgroundAddBorder: "false", BackgroundAddText: "false", BackgroundAddOverlay: "true", TitleCardAddBorder: "false", TitleCardAddOverlay: "true", TitleCardTitleAddEPTitleText: "false", TitleCardEPAddEPText: "false" },
      nested: {
        PosterOverlayPart: { AddBorder: "false", AddText: "false", AddOverlay: "true" },
        SeasonPosterOverlayPart: { AddBorder: "false", AddText: "false", AddOverlay: "true" },
        ShowTitleOnSeasonPosterPart: { AddShowTitletoSeason: "false" },
        BackgroundOverlayPart: { AddBorder: "false", AddText: "false", AddOverlay: "true" },
        TitleCardOverlayPart: { AddBorder: "false", AddOverlay: "true" },
        TitleCardTitleTextPart: { AddEPTitleText: "false" },
        TitleCardEPTextPart: { AddEPText: "false" }
      }
    }
  },
  {
    id: "textless-posters-only",
    titleKey: "blueprints.items.textless.title",
    descriptionKey: "blueprints.items.textless.description",
    icon: Languages,
    images: ["/blueprint-previews/minimalist-posters_textless.png", "/blueprint-previews/minimalist-posters_textless_background.png"],
    updates: {
      flat: { PreferredLanguageOrder: ["xx"], PreferredSeasonLanguageOrder: ["xx"], PreferredBackgroundLanguageOrder: ["xx"], PreferredTCLanguageOrder: ["xx"] },
      nested: { ApiPart: { PreferredLanguageOrder: ["xx"], PreferredSeasonLanguageOrder: ["xx"], PreferredBackgroundLanguageOrder: ["xx"], PreferredTCLanguageOrder: ["xx"] } }
    }
  }
];

// Reusable Accordion Component for the Builder
const Accordion = ({ title, icon: Icon, children, defaultOpen = false }) => {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  return (
    <div className="border border-theme rounded-lg overflow-hidden bg-theme-bg/50 mb-4">
      <button 
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center justify-between p-4 bg-theme-card hover:bg-theme-bg transition-colors"
      >
        <div className="flex items-center gap-3">
          {Icon && <Icon className="w-5 h-5 text-theme-primary" />}
          <span className="font-semibold text-theme-text">{title}</span>
        </div>
        {isOpen ? <ChevronDown className="w-4 h-4 text-theme-muted" /> : <ChevronRight className="w-4 h-4 text-theme-muted" />}
      </button>
      {isOpen && (
        <div className="p-4 border-t border-theme space-y-4">
          {children}
        </div>
      )}
    </div>
  );
};

export default function Blueprints() {
  const { t } = useTranslation();
  const { showSuccess, showError } = useToast();
  const fileInputRef = useRef(null);

  const [config, setConfig] = useState(null);
  const [usingFlatStructure, setUsingFlatStructure] = useState(false);
  const [loading, setLoading] = useState(true);
  const [applyingId, setApplyingId] = useState(null);
  const [error, setError] = useState(null);
  const [displayNames, setDisplayNames] = useState({});
  const [isImporting, setIsImporting] = useState(false);

  // Tabs: "presets" | "builder"
  const [activeTab, setActiveTab] = useState("presets");

  // Builder State
  const [builderState, setBuilderState] = useState({
    ImageProcessing: true,
    Poster: { AddBorder: false, AddText: false, UseResolutionOverlays: false },
    Season: { AddBorder: false, AddText: false, ShowTitle: false, UseResolutionOverlays: false },
    TitleCard: { AddBorder: false, AddOverlay: false, AddEPText: false, AddEPTitleText: false, UseResolutionOverlays: false },
    Background: { AddBorder: false, AddText: false, AddOverlay: false, UseResolutionOverlays: false },
    Global: { 
      UseClearlogo: true, 
      UseClearart: false, 
      UseOriginalTitle: false, 
      FlatWhiteLogo: false,
      TextlessOnly: false
    }
  });

  const [previewType, setPreviewType] = useState("Poster"); // "Poster", "Season", "TitleCard", "Background"

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`${API_URL}/config`);
      const data = await response.json();
      if (data.success) {
        setConfig(data.config);
        setUsingFlatStructure(data.using_flat_structure || false);
        if (data.display_names) setDisplayNames(data.display_names);
      } else {
        setError("Failed to load config");
      }
    } catch (err) {
      setError(`Failed to load configuration: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleApplyBlueprint = async (blueprint) => {
    if (!config) return;

    setApplyingId(blueprint.id);
    try {
      let updatedConfig = { ...config };
      const updates = usingFlatStructure ? blueprint.updates.flat : blueprint.updates.nested;

      if (usingFlatStructure) {
        updatedConfig = { ...updatedConfig, ...updates };
      } else {
        for (const [section, fields] of Object.entries(updates)) {
          updatedConfig[section] = {
            ...(updatedConfig[section] || {}),
            ...fields
          };
        }
      }

      const response = await fetch(`${API_URL}/config`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ config: updatedConfig }),
      });

      const data = await response.json();
      if (data.success) {
        setConfig(updatedConfig);
        showSuccess(`Blueprint applied successfully!`);
      } else {
        showError("Failed to apply blueprint configuration");
      }
    } catch (err) {
      showError(`Error applying blueprint: ${err.message}`);
    } finally {
      setApplyingId(null);
    }
  };

  const applyBuilderConfig = async () => {
    const nestedUpdates = {
      OverlayPart: { ImageProcessing: builderState.ImageProcessing ? "true" : "false" },
      PrerequisitePart: {
        UseClearlogo: builderState.Global.UseClearlogo ? "true" : "false",
        UseClearart: builderState.Global.UseClearart ? "true" : "false",
        UseOriginalTitle: builderState.Global.UseOriginalTitle ? "true" : "false",
        ConvertLogoColor: builderState.Global.FlatWhiteLogo ? "true" : "false",
        LogoFlatColor: builderState.Global.FlatWhiteLogo ? "white" : undefined,
        UsePosterResolutionOverlays: builderState.Poster.UseResolutionOverlays ? "true" : "false",
        UseBackgroundResolutionOverlays: builderState.Background.UseResolutionOverlays ? "true" : "false",
        UseTCResolutionOverlays: builderState.TitleCard.UseResolutionOverlays ? "true" : "false",
      },
      PosterOverlayPart: {
        AddBorder: builderState.Poster.AddBorder ? "true" : "false",
        AddText: builderState.Poster.AddText ? "true" : "false",
        AddOverlay: builderState.Poster.AddBorder ? "true" : "false" // Sync overlay with border for typical use case
      },
      SeasonPosterOverlayPart: {
        AddBorder: builderState.Season.AddBorder ? "true" : "false",
        AddText: builderState.Season.AddText ? "true" : "false",
        AddOverlay: builderState.Season.AddBorder ? "true" : "false"
      },
      ShowTitleOnSeasonPosterPart: {
        AddShowTitletoSeason: builderState.Season.ShowTitle ? "true" : "false"
      },
      BackgroundOverlayPart: {
        AddBorder: builderState.Background.AddBorder ? "true" : "false",
        AddText: builderState.Background.AddText ? "true" : "false",
        AddOverlay: builderState.Background.AddOverlay ? "true" : "false"
      },
      TitleCardOverlayPart: {
        AddBorder: builderState.TitleCard.AddBorder ? "true" : "false",
        AddOverlay: builderState.TitleCard.AddOverlay ? "true" : "false"
      },
      TitleCardTitleTextPart: {
        AddEPTitleText: builderState.TitleCard.AddEPTitleText ? "true" : "false"
      },
      TitleCardEPTextPart: {
        AddEPText: builderState.TitleCard.AddEPText ? "true" : "false"
      }
    };

    const flatUpdates = {
      ImageProcessing: builderState.ImageProcessing ? "true" : "false",
      UseClearlogo: builderState.Global.UseClearlogo ? "true" : "false",
      UseClearart: builderState.Global.UseClearart ? "true" : "false",
      UseOriginalTitle: builderState.Global.UseOriginalTitle ? "true" : "false",
      ConvertLogoColor: builderState.Global.FlatWhiteLogo ? "true" : "false",
      LogoFlatColor: builderState.Global.FlatWhiteLogo ? "white" : undefined,
      UsePosterResolutionOverlays: builderState.Poster.UseResolutionOverlays ? "true" : "false",
      UseBackgroundResolutionOverlays: builderState.Background.UseResolutionOverlays ? "true" : "false",
      UseTCResolutionOverlays: builderState.TitleCard.UseResolutionOverlays ? "true" : "false",
      PosterAddBorder: builderState.Poster.AddBorder ? "true" : "false",
      PosterAddText: builderState.Poster.AddText ? "true" : "false",
      PosterAddOverlay: builderState.Poster.AddBorder ? "true" : "false",
      SeasonPosterAddBorder: builderState.Season.AddBorder ? "true" : "false",
      SeasonPosterAddText: builderState.Season.AddText ? "true" : "false",
      SeasonPosterAddOverlay: builderState.Season.AddBorder ? "true" : "false",
      ShowTitleAddShowTitletoSeason: builderState.Season.ShowTitle ? "true" : "false",
      BackgroundAddBorder: builderState.Background.AddBorder ? "true" : "false",
      BackgroundAddText: builderState.Background.AddText ? "true" : "false",
      BackgroundAddOverlay: builderState.Background.AddOverlay ? "true" : "false",
      TitleCardAddBorder: builderState.TitleCard.AddBorder ? "true" : "false",
      TitleCardAddOverlay: builderState.TitleCard.AddOverlay ? "true" : "false",
      TitleCardTitleAddEPTitleText: builderState.TitleCard.AddEPTitleText ? "true" : "false",
      TitleCardEPAddEPText: builderState.TitleCard.AddEPText ? "true" : "false"
    };

    if (builderState.Global.TextlessOnly) {
       const langs = ["xx"];
       nestedUpdates.ApiPart = {
          PreferredLanguageOrder: langs, PreferredSeasonLanguageOrder: langs,
          PreferredBackgroundLanguageOrder: langs, PreferredTCLanguageOrder: langs
       };
       flatUpdates.PreferredLanguageOrder = langs;
       flatUpdates.PreferredSeasonLanguageOrder = langs;
       flatUpdates.PreferredBackgroundLanguageOrder = langs;
       flatUpdates.PreferredTCLanguageOrder = langs;
    }

    const syntheticBlueprint = {
      id: "builder",
      title: "Custom Builder Config",
      updates: { nested: nestedUpdates, flat: flatUpdates }
    };

    await handleApplyBlueprint(syntheticBlueprint);
  };

  const handleExportBlueprint = () => {
    const downloadAnchorNode = document.createElement('a');
    downloadAnchorNode.setAttribute("href", `${API_URL}/config/export`);
    downloadAnchorNode.setAttribute("download", "custom_blueprint.json");
    document.body.appendChild(downloadAnchorNode);
    downloadAnchorNode.click();
    downloadAnchorNode.remove();
  };

  const handleFileChange = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    setIsImporting(true);
    try {
      const text = await file.text();
      JSON.parse(text); // validate
      const response = await fetch(`${API_URL}/config/import`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: text,
      });

      const result = await response.json();
      if (result.success) {
        showSuccess(t("blueprints.importSuccess"));
        fetchConfig();
      } else {
        showError(t("blueprints.importFailed", { message: result.message || "Unknown error" }));
      }
    } catch (err) {
      showError(t("blueprints.importError", { message: err.message }));
    } finally {
      setIsImporting(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  const updateBuilder = (category, field, value) => {
    if (category) {
      setBuilderState(prev => ({
        ...prev,
        [category]: { ...prev[category], [field]: value }
      }));
    } else {
      setBuilderState(prev => ({ ...prev, [field]: value }));
    }
  };

  const Toggle = ({ label, checked, onChange }) => (
    <label className="flex items-center justify-between cursor-pointer group">
      <span className="text-theme-text group-hover:text-theme-primary transition-colors">{label}</span>
      <div className="relative">
        <input type="checkbox" className="sr-only" checked={checked} onChange={(e) => onChange(e.target.checked)} />
        <div className={`block w-10 h-6 rounded-full transition-colors ${checked ? 'bg-theme-primary' : 'bg-theme-bg border border-theme'}`}></div>
        <div className={`dot absolute left-1 top-1 bg-white w-4 h-4 rounded-full transition-transform ${checked ? 'transform translate-x-4' : ''}`}></div>
      </div>
    </label>
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <Loader2 className="w-12 h-12 animate-spin text-theme-primary" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-950/40 rounded-xl p-6 border-2 border-red-600/50 text-center mx-auto max-w-2xl mt-10">
        <AlertCircle className="w-12 h-12 text-red-400 mx-auto mb-4" />
        <p className="text-red-300 text-lg font-semibold mb-2">Error Loading Configuration</p>
        <p className="text-red-200 mb-4">{error}</p>
        <button onClick={fetchConfig} className="px-6 py-2.5 bg-red-600 hover:bg-red-700 rounded-lg font-medium transition-all shadow-lg">Retry</button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-theme-card border border-theme rounded-xl p-6 shadow-sm">
        <div className="mb-6 flex flex-col md:flex-row md:items-start justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold text-theme-text">{t("blueprints.pageTitle")}</h1>
            <p className="text-theme-muted mt-2">
              {t("blueprints.pageDescription")}
            </p>
          </div>
          <div className="flex gap-3">
            <button onClick={handleExportBlueprint} className="flex items-center gap-2 px-4 py-2 bg-theme-bg border border-theme hover:border-theme-primary/50 text-theme-text rounded-lg transition-colors">
              <Download className="w-4 h-4" />
              <span>{t("blueprints.export")}</span>
            </button>
            <div className="relative">
              <input type="file" accept=".json" className="hidden" ref={fileInputRef} onChange={handleFileChange} />
              <button onClick={() => fileInputRef.current?.click()} disabled={isImporting} className="flex items-center gap-2 px-4 py-2 bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary border border-theme-primary/30 rounded-lg transition-colors disabled:opacity-50">
                {isImporting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Upload className="w-4 h-4" />}
                <span>{isImporting ? t("blueprints.importing") : t("blueprints.import")}</span>
              </button>
            </div>
          </div>
        </div>

        <div className="flex border-b border-theme mb-6">
          <button 
            onClick={() => setActiveTab("presets")} 
            className={`px-6 py-3 flex items-center gap-2 border-b-2 transition-colors ${activeTab === 'presets' ? 'border-theme-primary text-theme-primary font-medium' : 'border-transparent text-theme-muted hover:text-theme-text'}`}
          >
            <LayoutTemplate className="w-4 h-4" />
            {t("blueprints.builder.tabPresets", "Presets")}
          </button>
          <button 
            onClick={() => setActiveTab("builder")} 
            className={`px-6 py-3 flex items-center gap-2 border-b-2 transition-colors ${activeTab === 'builder' ? 'border-theme-primary text-theme-primary font-medium' : 'border-transparent text-theme-muted hover:text-theme-text'}`}
          >
            <Sliders className="w-4 h-4" />
            {t("blueprints.builder.tabBuilder", "Builder")}
          </button>
        </div>

        {activeTab === "presets" && (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            {BLUEPRINTS.map((blueprint) => {
              const Icon = blueprint.icon;
              const isApplying = applyingId === blueprint.id;
              return (
                <div key={blueprint.id} className="bg-theme-bg/50 border border-theme rounded-xl p-5 hover:border-theme-primary/50 transition-all flex flex-col h-full group shadow-md hover:shadow-lg">
                  <div className="flex items-start gap-4 mb-4">
                    <div className="p-3 bg-theme-primary/10 rounded-xl text-theme-primary group-hover:scale-110 transition-transform">
                      <Icon className="w-6 h-6" />
                    </div>
                    <div className="flex-grow">
                      <div className="flex items-center gap-2">
                        <h3 className="text-lg font-semibold text-theme-text">{t(blueprint.titleKey)}</h3>
                        <div className="relative group/info">
                          <Info className="w-4 h-4 text-theme-muted hover:text-theme-primary cursor-help" />
                          <div className="absolute z-50 hidden group-hover/info:block bg-theme-bg border border-theme rounded-lg shadow-xl p-3 text-xs w-64 translate-y-2 -left-32 mt-1 max-h-64 overflow-y-auto custom-scrollbar">
                            <div className="font-semibold text-theme-text mb-2 pb-1 border-b border-theme/50">{t("blueprints.settingsChanged")}</div>
                            <ul className="space-y-1">
                              {Object.entries(blueprint.updates.flat).map(([key, val]) => (
                                <li key={key} className="flex flex-col border-b border-theme/10 pb-1 last:border-0 last:pb-0">
                                  <span className="text-theme-muted truncate" title={displayNames[key] || key}>{displayNames[key] || key}</span>
                                  <span className="text-theme-primary font-mono text-right">{val}</span>
                                </li>
                              ))}
                            </ul>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  {blueprint.images && blueprint.images.length > 0 && (
                    <div className="flex gap-2 mb-4 overflow-x-auto pb-2 custom-scrollbar items-center">
                      {blueprint.images.map((img, idx) => (
                        <img key={idx} src={img} alt={`${t(blueprint.titleKey)} preview ${idx + 1}`} className="h-32 object-contain rounded-md bg-black/20 shrink-0 border border-theme/50 shadow-sm" />
                      ))}
                    </div>
                  )}
                  <p className="text-sm text-theme-muted flex-grow mb-6">{t(blueprint.descriptionKey)}</p>
                  <button onClick={() => handleApplyBlueprint(blueprint)} disabled={applyingId !== null} className="w-full flex items-center justify-center gap-2 py-2.5 bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary border border-theme-primary/30 rounded-lg font-medium transition-all disabled:opacity-50">
                    {isApplying ? <Loader2 className="w-5 h-5 animate-spin" /> : <CheckCircle2 className="w-5 h-5" />}
                    <span>{isApplying ? t("blueprints.applying") : t("blueprints.apply")}</span>
                  </button>
                </div>
              );
            })}
          </div>
        )}

        {activeTab === "builder" && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div className="space-y-2">
              <p className="text-theme-muted mb-6">{t("blueprints.builder.tabBuilderDesc", "Create your own custom blueprint by mixing and matching specific overlays.")}</p>
              
              <Accordion title={t("blueprints.builder.categoryGlobal", "Global Settings")} icon={Settings} defaultOpen={true}>
                <Toggle label={t("blueprints.builder.enableProcessing", "Enable Image Processing")} checked={builderState.ImageProcessing} onChange={(v) => updateBuilder(null, "ImageProcessing", v)} />
                <div className="border-t border-theme/50 my-2 pt-2"></div>
                <Toggle label={t("blueprints.builder.useClearlogo", "Use Clearlogo")} checked={builderState.Global.UseClearlogo} onChange={(v) => updateBuilder("Global", "UseClearlogo", v)} />
                <Toggle label={t("blueprints.builder.useClearart", "Use Clearart")} checked={builderState.Global.UseClearart} onChange={(v) => updateBuilder("Global", "UseClearart", v)} />
                <Toggle label={t("blueprints.builder.flatWhiteLogo", "Flat White Logo")} checked={builderState.Global.FlatWhiteLogo} onChange={(v) => updateBuilder("Global", "FlatWhiteLogo", v)} />
                <div className="border-t border-theme/50 my-2 pt-2"></div>
                <Toggle label={t("blueprints.builder.onlyTextless", "Only Download Textless Artwork")} checked={builderState.Global.TextlessOnly} onChange={(v) => updateBuilder("Global", "TextlessOnly", v)} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categoryPoster", "Poster")} icon={Image}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.Poster.AddBorder} onChange={(v) => { updateBuilder("Poster", "AddBorder", v); setPreviewType("Poster"); }} />
                <Toggle label={t("blueprints.builder.enableText", "Enable Text / Logo")} checked={builderState.Poster.AddText} onChange={(v) => { updateBuilder("Poster", "AddText", v); setPreviewType("Poster"); }} />
                <Toggle label={t("blueprints.builder.resolutionOverlays", "Resolution Overlays")} checked={builderState.Poster.UseResolutionOverlays} onChange={(v) => { updateBuilder("Poster", "UseResolutionOverlays", v); setPreviewType("Poster"); }} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categorySeason", "Season")} icon={Layers}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.Season.AddBorder} onChange={(v) => { updateBuilder("Season", "AddBorder", v); setPreviewType("Season"); }} />
                <Toggle label={t("blueprints.builder.enableText", "Enable Text / Logo")} checked={builderState.Season.AddText} onChange={(v) => { updateBuilder("Season", "AddText", v); setPreviewType("Season"); }} />
                <Toggle label={t("blueprints.builder.showTitleOnSeason", "Show Title on Season")} checked={builderState.Season.ShowTitle} onChange={(v) => { updateBuilder("Season", "ShowTitle", v); setPreviewType("Season"); }} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categoryBackground", "Background")} icon={Square}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.Background.AddBorder} onChange={(v) => { updateBuilder("Background", "AddBorder", v); setPreviewType("Background"); }} />
                <Toggle label={t("blueprints.builder.enableText", "Enable Text / Logo")} checked={builderState.Background.AddText} onChange={(v) => { updateBuilder("Background", "AddText", v); setPreviewType("Background"); }} />
                <Toggle label={t("blueprints.builder.enableProcessing", "Enable Overlays (Darken/Glow)")} checked={builderState.Background.AddOverlay} onChange={(v) => { updateBuilder("Background", "AddOverlay", v); setPreviewType("Background"); }} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categoryTitleCard", "Title Card")} icon={Type}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.TitleCard.AddBorder} onChange={(v) => { updateBuilder("TitleCard", "AddBorder", v); setPreviewType("TitleCard"); }} />
                <Toggle label={t("blueprints.builder.enableProcessing", "Enable Overlays (Darken/Glow)")} checked={builderState.TitleCard.AddOverlay} onChange={(v) => { updateBuilder("TitleCard", "AddOverlay", v); setPreviewType("TitleCard"); }} />
                <Toggle label="Enable Episode Title Text" checked={builderState.TitleCard.AddEPTitleText} onChange={(v) => { updateBuilder("TitleCard", "AddEPTitleText", v); setPreviewType("TitleCard"); }} />
                <Toggle label="Enable SxxExx Text" checked={builderState.TitleCard.AddEPText} onChange={(v) => { updateBuilder("TitleCard", "AddEPText", v); setPreviewType("TitleCard"); }} />
              </Accordion>

            </div>

            <div className="bg-theme-bg/50 rounded-xl border border-theme p-6 sticky top-6 h-fit shadow-md">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-xl font-bold text-theme-text flex items-center gap-2">
                  <Palette className="w-5 h-5 text-theme-primary" />
                  {t("blueprints.builder.preview", "Live Preview")}
                </h3>
                <select 
                  className="bg-theme-bg border border-theme text-theme-text text-sm rounded-lg px-2 py-1 outline-none focus:border-theme-primary"
                  value={previewType}
                  onChange={(e) => setPreviewType(e.target.value)}
                >
                  <option value="Poster">{t("blueprints.builder.categoryPoster", "Poster")}</option>
                  <option value="Season">{t("blueprints.builder.categorySeason", "Season")}</option>
                  <option value="Background">{t("blueprints.builder.categoryBackground", "Background")}</option>
                  <option value="TitleCard">{t("blueprints.builder.categoryTitleCard", "Title Card")}</option>
                </select>
              </div>

              {/* CSS Visual Preview Container */}
              <div className="w-full flex items-center justify-center bg-black/40 rounded-xl border border-theme/50 p-4 min-h-[400px]">
                <div className={`relative bg-gradient-to-br from-indigo-900 to-purple-900 overflow-hidden shadow-2xl transition-all duration-300 ${
                  previewType === 'Poster' || previewType === 'Season' ? 'w-2/3 aspect-[2/3] rounded-sm' : 
                  previewType === 'Background' || previewType === 'TitleCard' ? 'w-full aspect-[16/9] rounded-sm' : ''
                }`}>
                  {/* Base Image Placeholder */}
                  <div className="absolute inset-0 flex flex-col items-center justify-center opacity-30 mix-blend-overlay">
                    <Image className="w-16 h-16 mb-2" />
                    <span className="font-bold text-2xl tracking-widest uppercase">{previewType}</span>
                  </div>

                  {/* Dynamic Overlays */}
                  {builderState.ImageProcessing && (
                    <>
                      {/* BORDERS */}
                      {(previewType === 'Poster' && builderState.Poster.AddBorder) ||
                       (previewType === 'Season' && builderState.Season.AddBorder) ||
                       (previewType === 'Background' && builderState.Background.AddBorder) ||
                       (previewType === 'TitleCard' && builderState.TitleCard.AddBorder) ? (
                        <div className="absolute inset-0 border-[6px] border-white z-10 m-3 shadow-[inset_0_0_20px_rgba(0,0,0,0.5)] rounded-sm pointer-events-none transition-all"></div>
                      ) : null}

                      {/* TEXT / LOGO */}
                      {((previewType === 'Poster' && builderState.Poster.AddText) ||
                       (previewType === 'Season' && builderState.Season.AddText) ||
                       (previewType === 'Background' && builderState.Background.AddText)) && (
                        <div className="absolute bottom-[10%] left-0 w-full flex justify-center z-20 pointer-events-none transition-all">
                          {builderState.Global.UseClearlogo || builderState.Global.UseClearart ? (
                             <div className={`text-3xl lg:text-4xl font-black italic tracking-tighter ${builderState.Global.FlatWhiteLogo ? 'text-white' : 'text-yellow-400 drop-shadow-md'}`}>
                               TITLE LOGO
                             </div>
                          ) : (
                             <div className="text-2xl lg:text-3xl font-bold text-white uppercase tracking-widest drop-shadow-md">Movie Title</div>
                          )}
                        </div>
                      )}

                      {/* SEASON SPECIFIC TEXT */}
                      {previewType === 'Season' && builderState.Season.AddText && (
                        <div className="absolute bottom-[20%] left-0 w-full flex flex-col items-center z-20 pointer-events-none transition-all">
                          {builderState.Season.ShowTitle && (
                             <div className="text-lg lg:text-xl font-bold text-white/80 mb-1 drop-shadow-md uppercase tracking-wider">Movie Title</div>
                          )}
                          <div className="text-xl lg:text-2xl font-bold text-white uppercase tracking-widest drop-shadow-md">Season 1</div>
                        </div>
                      )}

                      {/* TITLE CARD TEXT */}
                      {previewType === 'TitleCard' && (
                        <div className="absolute bottom-[15%] left-[8%] z-20 pointer-events-none transition-all text-left">
                          {builderState.TitleCard.AddEPText && <div className="text-lg lg:text-xl font-medium text-white/80 drop-shadow">S01E01</div>}
                          {builderState.TitleCard.AddEPTitleText && <div className="text-2xl lg:text-3xl font-bold text-white drop-shadow uppercase tracking-wide mt-1">Episode Title</div>}
                        </div>
                      )}

                      {/* RESOLUTION OVERLAYS */}
                      {((previewType === 'Poster' && builderState.Poster.UseResolutionOverlays) ||
                       (previewType === 'Season' && builderState.Season.UseResolutionOverlays) ||
                       (previewType === 'Background' && builderState.Background.UseResolutionOverlays) ||
                       (previewType === 'TitleCard' && builderState.TitleCard.UseResolutionOverlays)) && (
                        <div className="absolute top-0 right-0 z-30 m-0 pointer-events-none transition-all">
                          <div className="bg-gradient-to-l from-yellow-500 to-yellow-600 text-black font-black text-[10px] lg:text-xs px-3 py-1 lg:px-4 lg:py-1 rounded-bl-xl shadow-lg">4K ULTRA HD</div>
                        </div>
                      )}
                    </>
                  )}
                </div>
              </div>

              <div className="mt-6">
                <button 
                  onClick={applyBuilderConfig} 
                  disabled={applyingId === "builder"}
                  className="w-full flex justify-center items-center gap-2 bg-theme-primary text-white px-6 py-3 rounded-lg font-medium shadow-lg hover:bg-theme-primary/90 hover:shadow-theme-primary/30 transition-all disabled:opacity-50"
                >
                  {applyingId === "builder" ? <Loader2 className="w-5 h-5 animate-spin" /> : <CheckCircle2 className="w-5 h-5" />}
                  {applyingId === "builder" ? t("blueprints.applying") : t("blueprints.builder.applyCustom", "Apply Custom Blueprint")}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
