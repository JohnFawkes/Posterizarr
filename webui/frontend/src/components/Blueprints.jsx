import React, { useState, useEffect, useRef } from "react";
import { Loader2, Palette, Image, Layers, CheckCircle2, AlertCircle, Type, Square, Languages, Sparkles, Download, Upload, Info, Sliders, LayoutTemplate, ChevronDown, ChevronRight, Settings, ImagePlus, RotateCcw } from "lucide-react";
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

const ColorInput = ({ value, onChange, label }) => (
  <div className="flex items-center gap-2 mt-2">
    <div className="relative w-8 h-8 rounded-lg overflow-hidden border border-theme shadow-sm shrink-0">
      <input type="color" value={value || "#ffffff"} onChange={e => onChange(e.target.value)} className="absolute -top-2 -left-2 w-12 h-12 cursor-pointer p-0 border-0" title={label} />
    </div>
    <input type="text" value={value || "#ffffff"} onChange={e => onChange(e.target.value)} className="w-24 bg-transparent border border-theme rounded-md px-2 py-1 text-xs font-mono uppercase text-theme-text focus:border-theme-primary focus:outline-none transition-colors" />
  </div>
);

const NumberInput = ({ label, value, onChange, min = 0, max = 5000 }) => (
  <div className="flex items-center justify-between gap-4 mt-2">
    <span className="text-sm text-theme-muted">{label}</span>
    <input type="number" min={min} max={max} value={value || 0} onChange={(e) => onChange(e.target.value)} className="bg-theme-bg border border-theme rounded-md px-3 py-1.5 text-sm w-24 text-right focus:border-theme-primary outline-none transition-colors text-theme-text" />
  </div>
);

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
  const [customPreviewImage, setCustomPreviewImage] = useState(null);

  // Tabs: "presets" | "builder"
  const [activeTab, setActiveTab] = useState("presets");

  // Builder State
  const [builderState, setBuilderState] = useState({
    ImageProcessing: true,
    Poster: { AddBorder: false, AddText: false, UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+400" },
    Season: { AddBorder: false, AddText: false, ShowTitle: false, UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+400" },
    TitleCard: { AddBorder: false, AddOverlay: false, AddEPText: false, AddEPTitleText: false, UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+400" },
    Background: { AddBorder: false, AddText: false, AddOverlay: false, UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+200" },
    Global: { 
      UseClearlogo: true, 
      UseClearart: false, 
      UseOriginalTitle: false, 
      FlatWhiteLogo: false,
      TextlessOnly: false
    }
  });

  const [previewType, setPreviewType] = useState("Poster"); // "Poster", "Season", "TitleCard", "Background"
  const [importBlueprintState, setImportBlueprintState] = useState(null);

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
        
        // Populate Builder State from config
        setBuilderState(prev => ({
          ...prev,
          ImageProcessing: data.config.OverlayPart?.ImageProcessing === "true",
          Poster: {
             ...prev.Poster,
             AddBorder: data.config.PosterOverlayPart?.AddBorder === "true",
             AddText: data.config.PosterOverlayPart?.AddText === "true",
             UseResolutionOverlays: data.config.PrerequisitePart?.UsePosterResolutionOverlays === "true",
             bordercolor: data.config.PosterOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.PosterOverlayPart?.borderwidth || 30),
             fontcolor: data.config.PosterOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.PosterOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.PosterOverlayPart?.strokewidth || 6),
             text_offset: data.config.PosterOverlayPart?.text_offset || "+430"
          },
          Season: {
             ...prev.Season,
             AddBorder: data.config.SeasonPosterOverlayPart?.AddBorder === "true",
             AddText: data.config.SeasonPosterOverlayPart?.AddText === "true",
             ShowTitle: data.config.ShowTitleOnSeasonPosterPart?.AddShowTitletoSeason === "true",
             UseResolutionOverlays: data.config.PrerequisitePart?.UseSeasonResolutionOverlays === "true",
             bordercolor: data.config.SeasonPosterOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.SeasonPosterOverlayPart?.borderwidth || 30),
             fontcolor: data.config.SeasonPosterOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.SeasonPosterOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.SeasonPosterOverlayPart?.strokewidth || 6),
             text_offset: data.config.SeasonPosterOverlayPart?.text_offset || "+400"
          },
          Background: {
             ...prev.Background,
             AddBorder: data.config.BackgroundOverlayPart?.AddBorder === "true",
             AddText: data.config.BackgroundOverlayPart?.AddText === "true",
             AddOverlay: data.config.BackgroundOverlayPart?.AddOverlay === "true",
             UseResolutionOverlays: data.config.PrerequisitePart?.UseBackgroundResolutionOverlays === "true",
             bordercolor: data.config.BackgroundOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.BackgroundOverlayPart?.borderwidth || 30),
             fontcolor: data.config.BackgroundOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.BackgroundOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.BackgroundOverlayPart?.strokewidth || 6),
             text_offset: data.config.BackgroundOverlayPart?.text_offset || "+200"
          },
          TitleCard: {
             ...prev.TitleCard,
             AddBorder: data.config.TitleCardOverlayPart?.AddBorder === "true",
             AddOverlay: data.config.TitleCardOverlayPart?.AddOverlay === "true",
             AddEPText: data.config.TitleCardEPTextPart?.AddEPText === "true",
             AddEPTitleText: data.config.TitleCardTitleTextPart?.AddEPTitleText === "true",
             UseResolutionOverlays: data.config.PrerequisitePart?.UseTCResolutionOverlays === "true",
             bordercolor: data.config.TitleCardOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.TitleCardOverlayPart?.borderwidth || 30),
             fontcolor: data.config.TitleCardTitleTextPart?.fontcolor || "#ffffff",
             strokecolor: data.config.TitleCardTitleTextPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.TitleCardTitleTextPart?.strokewidth || 6),
             text_offset: data.config.TitleCardTitleTextPart?.text_offset || "+300"
          },
          Global: {
             UseClearlogo: data.config.PrerequisitePart?.UseClearlogo === "true",
             UseClearart: data.config.PrerequisitePart?.UseClearart === "true",
             UseOriginalTitle: data.config.PrerequisitePart?.UseOriginalTitle === "true",
             FlatWhiteLogo: data.config.PrerequisitePart?.ConvertLogoColor === "true",
             TextlessOnly: false
          }
        }));
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
        AddOverlay: builderState.Poster.AddBorder ? "true" : "false", // Sync overlay with border for typical use case
        bordercolor: builderState.Poster.bordercolor,
        borderwidth: builderState.Poster.borderwidth.toString(),
        fontcolor: builderState.Poster.fontcolor,
        strokecolor: builderState.Poster.strokecolor,
        strokewidth: builderState.Poster.strokewidth.toString(),
        text_offset: builderState.Poster.text_offset.toString()
      },
      SeasonPosterOverlayPart: {
        AddBorder: builderState.Season.AddBorder ? "true" : "false",
        AddText: builderState.Season.AddText ? "true" : "false",
        AddOverlay: builderState.Season.AddBorder ? "true" : "false",
        bordercolor: builderState.Season.bordercolor,
        borderwidth: builderState.Season.borderwidth.toString(),
        fontcolor: builderState.Season.fontcolor,
        strokecolor: builderState.Season.strokecolor,
        strokewidth: builderState.Season.strokewidth.toString(),
        text_offset: builderState.Season.text_offset.toString()
      },
      ShowTitleOnSeasonPosterPart: {
        AddShowTitletoSeason: builderState.Season.ShowTitle ? "true" : "false"
      },
      BackgroundOverlayPart: {
        AddBorder: builderState.Background.AddBorder ? "true" : "false",
        AddText: builderState.Background.AddText ? "true" : "false",
        AddOverlay: builderState.Background.AddOverlay ? "true" : "false",
        bordercolor: builderState.Background.bordercolor,
        borderwidth: builderState.Background.borderwidth.toString(),
        fontcolor: builderState.Background.fontcolor,
        strokecolor: builderState.Background.strokecolor,
        strokewidth: builderState.Background.strokewidth.toString(),
        text_offset: builderState.Background.text_offset.toString()
      },
      TitleCardOverlayPart: {
        AddBorder: builderState.TitleCard.AddBorder ? "true" : "false",
        AddOverlay: builderState.TitleCard.AddOverlay ? "true" : "false",
        bordercolor: builderState.TitleCard.bordercolor,
        borderwidth: builderState.TitleCard.borderwidth.toString(),
      },
      TitleCardTitleTextPart: {
        AddEPTitleText: builderState.TitleCard.AddEPTitleText ? "true" : "false",
        fontcolor: builderState.TitleCard.fontcolor,
        strokecolor: builderState.TitleCard.strokecolor,
        strokewidth: builderState.TitleCard.strokewidth.toString(),
        text_offset: builderState.TitleCard.text_offset.toString()
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
      Posterbordercolor: builderState.Poster.bordercolor,
      Posterborderwidth: builderState.Poster.borderwidth.toString(),
      Posterfontcolor: builderState.Poster.fontcolor,
      Posterstrokecolor: builderState.Poster.strokecolor,
      Posterstrokewidth: builderState.Poster.strokewidth.toString(),
      Postertext_offset: builderState.Poster.text_offset.toString(),
      SeasonPosterAddBorder: builderState.Season.AddBorder ? "true" : "false",
      SeasonPosterAddText: builderState.Season.AddText ? "true" : "false",
      SeasonPosterAddOverlay: builderState.Season.AddBorder ? "true" : "false",
      ShowTitleAddShowTitletoSeason: builderState.Season.ShowTitle ? "true" : "false",
      SeasonPosterbordercolor: builderState.Season.bordercolor,
      SeasonPosterborderwidth: builderState.Season.borderwidth.toString(),
      SeasonPosterfontcolor: builderState.Season.fontcolor,
      SeasonPosterstrokecolor: builderState.Season.strokecolor,
      SeasonPosterstrokewidth: builderState.Season.strokewidth.toString(),
      SeasonPostertext_offset: builderState.Season.text_offset.toString(),
      BackgroundAddBorder: builderState.Background.AddBorder ? "true" : "false",
      BackgroundAddText: builderState.Background.AddText ? "true" : "false",
      BackgroundAddOverlay: builderState.Background.AddOverlay ? "true" : "false",
      Backgroundbordercolor: builderState.Background.bordercolor,
      Backgroundborderwidth: builderState.Background.borderwidth.toString(),
      Backgroundfontcolor: builderState.Background.fontcolor,
      Backgroundstrokecolor: builderState.Background.strokecolor,
      Backgroundstrokewidth: builderState.Background.strokewidth.toString(),
      Backgroundtext_offset: builderState.Background.text_offset.toString(),
      TitleCardAddBorder: builderState.TitleCard.AddBorder ? "true" : "false",
      TitleCardAddOverlay: builderState.TitleCard.AddOverlay ? "true" : "false",
      TitleCardTitleAddEPTitleText: builderState.TitleCard.AddEPTitleText ? "true" : "false",
      TitleCardEPAddEPText: builderState.TitleCard.AddEPText ? "true" : "false",
      TitleCardbordercolor: builderState.TitleCard.bordercolor,
      TitleCardborderwidth: builderState.TitleCard.borderwidth.toString(),
      TitleCardTitlefontcolor: builderState.TitleCard.fontcolor,
      TitleCardTitlestrokecolor: builderState.TitleCard.strokecolor,
      TitleCardTitlestrokewidth: builderState.TitleCard.strokewidth.toString(),
      TitleCardTitletext_offset: builderState.TitleCard.text_offset.toString()
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

    try {
      const text = await file.text();
      const parsed = JSON.parse(text);
      if (!parsed.updates || (!parsed.updates.flat && !parsed.updates.nested)) {
        throw new Error("Invalid blueprint format. Missing updates object.");
      }
      setImportBlueprintState(parsed);
    } catch (err) {
      showError(t("blueprints.importError", { message: err.message }));
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  const confirmImport = async () => {
    if (!importBlueprintState) return;
    setIsImporting(true);
    try {
      const response = await fetch(`${API_URL}/config/import`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(importBlueprintState),
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
      setImportBlueprintState(null);
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

  const handleCustomPreview = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => { setCustomPreviewImage(e.target.result); };
      reader.readAsDataURL(file);
    }
  };

  const resetCustomPreview = () => setCustomPreviewImage(null);

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

  const getStyleObj = (partKey) => {
    const part = config?.[partKey] || {};
    const bColor = part.bordercolor || "white";
    const bWidth = Math.max(2, (parseInt(part.borderwidth) || 30) * 0.15); // scaled
    const fColor = part.fontcolor || "white";
    const sColor = part.strokecolor || "black";
    const sWidth = Math.max(1, (parseInt(part.strokewidth) || 6) * 0.15);
    const hasStroke = part.AddTextStroke === "true";
    const gravity = part.TextGravity?.toLowerCase() || "south";
    const offsetRaw = part.text_offset || "+400";
    let offset = parseInt(offsetRaw.replace('+', '').replace('-', '')) || 400;
    offset = Math.max(0, offset * 0.15);
    
    return {
      border: {
        borderColor: bColor,
        borderWidth: `${bWidth}px`,
        borderStyle: 'solid'
      },
      text: {
        color: fColor,
        WebkitTextStroke: hasStroke ? `${sWidth}px ${sColor}` : undefined,
        textShadow: hasStroke ? undefined : '0px 4px 10px rgba(0,0,0,0.5)',
        [gravity === 'north' ? 'top' : 'bottom']: `${offset}px`,
      }
    };
  };

  const previewStyles = getStyleObj(
    previewType === 'Poster' ? 'PosterOverlayPart' : 
    previewType === 'Season' ? 'SeasonPosterOverlayPart' : 
    previewType === 'Background' ? 'BackgroundOverlayPart' : 
    'TitleCardOverlayPart'
  );

  const seasonTitleStyles = getStyleObj('ShowTitleOnSeasonPosterPart');
  const tcTitleStyles = getStyleObj('TitleCardTitleTextPart');
  const tcEpStyles = getStyleObj('TitleCardEPTextPart');

  const getSampleImage = () => {
    if (customPreviewImage) return customPreviewImage;
    if (previewType === 'Background' || previewType === 'TitleCard') return `/images/default_background.jpg?t=${Date.now()}`;
    return `/images/default_poster.jpg?t=${Date.now()}`;
  };

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
                  <p className="text-sm text-theme-muted flex-grow mb-4">{t(blueprint.descriptionKey)}</p>
                  <Accordion title={t("blueprints.settingsChanged", "Settings Changed")} icon={Info}>
                    <ul className="space-y-1 text-xs">
                      {Object.entries(blueprint.updates.flat).map(([key, val]) => (
                        <li key={key} className="flex flex-col border-b border-theme/10 pb-1 last:border-0 last:pb-0">
                          <span className="text-theme-muted truncate" title={displayNames[key] || key}>{displayNames[key] || key}</span>
                          <span className="text-theme-primary font-mono text-right">{val}</span>
                        </li>
                      ))}
                    </ul>
                  </Accordion>
                  <button onClick={() => handleApplyBlueprint(blueprint)} disabled={applyingId !== null} className="w-full mt-2 flex items-center justify-center gap-2 py-2.5 bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary border border-theme-primary/30 rounded-lg font-medium transition-all disabled:opacity-50">
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
                {builderState.Poster.AddBorder && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Border Color" value={builderState.Poster.bordercolor} onChange={(v) => updateBuilder("Poster", "bordercolor", v)} />
                      <NumberInput label="Border Width" value={builderState.Poster.borderwidth} onChange={(v) => updateBuilder("Poster", "borderwidth", v)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.enableText", "Enable Text / Logo")} checked={builderState.Poster.AddText} onChange={(v) => { updateBuilder("Poster", "AddText", v); setPreviewType("Poster"); }} />
                {builderState.Poster.AddText && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Text Color" value={builderState.Poster.fontcolor} onChange={(v) => updateBuilder("Poster", "fontcolor", v)} />
                      <ColorInput label="Stroke Color" value={builderState.Poster.strokecolor} onChange={(v) => updateBuilder("Poster", "strokecolor", v)} />
                      <NumberInput label="Stroke Width" value={builderState.Poster.strokewidth} onChange={(v) => updateBuilder("Poster", "strokewidth", v)} />
                      <NumberInput label="Text Offset Y" value={parseInt(builderState.Poster.text_offset.replace('+','').replace('-','')) || 0} onChange={(v) => updateBuilder("Poster", "text_offset", `+${v}`)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.resolutionOverlays", "Resolution Overlays")} checked={builderState.Poster.UseResolutionOverlays} onChange={(v) => { updateBuilder("Poster", "UseResolutionOverlays", v); setPreviewType("Poster"); }} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categorySeason", "Season")} icon={Layers}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.Season.AddBorder} onChange={(v) => { updateBuilder("Season", "AddBorder", v); setPreviewType("Season"); }} />
                {builderState.Season.AddBorder && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Border Color" value={builderState.Season.bordercolor} onChange={(v) => updateBuilder("Season", "bordercolor", v)} />
                      <NumberInput label="Border Width" value={builderState.Season.borderwidth} onChange={(v) => updateBuilder("Season", "borderwidth", v)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.enableText", "Enable Text / Logo")} checked={builderState.Season.AddText} onChange={(v) => { updateBuilder("Season", "AddText", v); setPreviewType("Season"); }} />
                {builderState.Season.AddText && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Text Color" value={builderState.Season.fontcolor} onChange={(v) => updateBuilder("Season", "fontcolor", v)} />
                      <ColorInput label="Stroke Color" value={builderState.Season.strokecolor} onChange={(v) => updateBuilder("Season", "strokecolor", v)} />
                      <NumberInput label="Stroke Width" value={builderState.Season.strokewidth} onChange={(v) => updateBuilder("Season", "strokewidth", v)} />
                      <NumberInput label="Text Offset Y" value={parseInt(builderState.Season.text_offset.replace('+','').replace('-','')) || 0} onChange={(v) => updateBuilder("Season", "text_offset", `+${v}`)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.showTitleOnSeason", "Show Title on Season")} checked={builderState.Season.ShowTitle} onChange={(v) => { updateBuilder("Season", "ShowTitle", v); setPreviewType("Season"); }} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categoryBackground", "Background")} icon={Square}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.Background.AddBorder} onChange={(v) => { updateBuilder("Background", "AddBorder", v); setPreviewType("Background"); }} />
                {builderState.Background.AddBorder && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Border Color" value={builderState.Background.bordercolor} onChange={(v) => updateBuilder("Background", "bordercolor", v)} />
                      <NumberInput label="Border Width" value={builderState.Background.borderwidth} onChange={(v) => updateBuilder("Background", "borderwidth", v)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.enableText", "Enable Text / Logo")} checked={builderState.Background.AddText} onChange={(v) => { updateBuilder("Background", "AddText", v); setPreviewType("Background"); }} />
                {builderState.Background.AddText && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Text Color" value={builderState.Background.fontcolor} onChange={(v) => updateBuilder("Background", "fontcolor", v)} />
                      <ColorInput label="Stroke Color" value={builderState.Background.strokecolor} onChange={(v) => updateBuilder("Background", "strokecolor", v)} />
                      <NumberInput label="Stroke Width" value={builderState.Background.strokewidth} onChange={(v) => updateBuilder("Background", "strokewidth", v)} />
                      <NumberInput label="Text Offset Y" value={parseInt(builderState.Background.text_offset.replace('+','').replace('-','')) || 0} onChange={(v) => updateBuilder("Background", "text_offset", `+${v}`)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.enableProcessing", "Enable Overlays (Darken/Glow)")} checked={builderState.Background.AddOverlay} onChange={(v) => { updateBuilder("Background", "AddOverlay", v); setPreviewType("Background"); }} />
              </Accordion>

              <Accordion title={t("blueprints.builder.categoryTitleCard", "Title Card")} icon={Type}>
                <Toggle label={t("blueprints.builder.enableBorders", "Enable Borders")} checked={builderState.TitleCard.AddBorder} onChange={(v) => { updateBuilder("TitleCard", "AddBorder", v); setPreviewType("TitleCard"); }} />
                {builderState.TitleCard.AddBorder && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Border Color" value={builderState.TitleCard.bordercolor} onChange={(v) => updateBuilder("TitleCard", "bordercolor", v)} />
                      <NumberInput label="Border Width" value={builderState.TitleCard.borderwidth} onChange={(v) => updateBuilder("TitleCard", "borderwidth", v)} />
                   </div>
                )}
                <Toggle label={t("blueprints.builder.enableProcessing", "Enable Overlays (Darken/Glow)")} checked={builderState.TitleCard.AddOverlay} onChange={(v) => { updateBuilder("TitleCard", "AddOverlay", v); setPreviewType("TitleCard"); }} />
                <Toggle label="Enable Episode Title Text" checked={builderState.TitleCard.AddEPTitleText} onChange={(v) => { updateBuilder("TitleCard", "AddEPTitleText", v); setPreviewType("TitleCard"); }} />
                <Toggle label="Enable SxxExx Text" checked={builderState.TitleCard.AddEPText} onChange={(v) => { updateBuilder("TitleCard", "AddEPText", v); setPreviewType("TitleCard"); }} />
                {(builderState.TitleCard.AddEPTitleText || builderState.TitleCard.AddEPText) && (
                   <div className="pl-4 ml-2 border-l-2 border-theme/20 mb-4 pb-2">
                      <ColorInput label="Text Color" value={builderState.TitleCard.fontcolor} onChange={(v) => updateBuilder("TitleCard", "fontcolor", v)} />
                      <ColorInput label="Stroke Color" value={builderState.TitleCard.strokecolor} onChange={(v) => updateBuilder("TitleCard", "strokecolor", v)} />
                      <NumberInput label="Stroke Width" value={builderState.TitleCard.strokewidth} onChange={(v) => updateBuilder("TitleCard", "strokewidth", v)} />
                      <NumberInput label="Text Offset Y" value={parseInt(builderState.TitleCard.text_offset.replace('+','').replace('-','')) || 0} onChange={(v) => updateBuilder("TitleCard", "text_offset", `+${v}`)} />
                   </div>
                )}
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
                <div className={`relative overflow-hidden shadow-2xl transition-all duration-300 ${!customPreviewImage ? 'bg-black' : 'bg-black'} ${
                  previewType === 'Poster' || previewType === 'Season' ? 'w-2/3 aspect-[2/3] rounded-sm' : 
                  previewType === 'Background' || previewType === 'TitleCard' ? 'w-full aspect-[16/9] rounded-sm' : ''
                }`}>
                  {/* Base Image */}
                  <div className="absolute inset-0 flex flex-col items-center justify-center">
                    <img src={getSampleImage()} className="w-full h-full object-cover" alt="Preview Base" onError={(e) => { e.target.style.display = 'none'; e.target.nextSibling.style.display = 'flex'; }} />
                    <div className="hidden flex-col items-center opacity-30 mix-blend-overlay">
                      <Image className="w-16 h-16 mb-2" />
                      <span className="font-bold text-2xl tracking-widest uppercase">{previewType}</span>
                    </div>
                  </div>

                  {/* Dynamic Overlays */}
                  {builderState.ImageProcessing && (
                    <>
                      {/* BORDERS */}
                      {(previewType === 'Poster' && builderState.Poster.AddBorder) ||
                       (previewType === 'Season' && builderState.Season.AddBorder) ||
                       (previewType === 'Background' && builderState.Background.AddBorder) ||
                       (previewType === 'TitleCard' && builderState.TitleCard.AddBorder) ? (
                        <div className="absolute inset-0 z-10 shadow-[inset_0_0_20px_rgba(0,0,0,0.5)] rounded-sm pointer-events-none transition-all" style={{ ...previewStyles.border, margin: previewStyles.border.borderWidth }}></div>
                      ) : null}

                      {/* TEXT / LOGO */}
                      {((previewType === 'Poster' && builderState.Poster.AddText) ||
                       (previewType === 'Season' && builderState.Season.AddText) ||
                       (previewType === 'Background' && builderState.Background.AddText)) && (
                        <div className="absolute left-0 w-full flex justify-center z-20 pointer-events-none transition-all" style={previewStyles.text}>
                          {builderState.Global.UseClearlogo || builderState.Global.UseClearart ? (
                             <img 
                               src="https://image.tmdb.org/t/p/w500/b0gA3L7D57Vb1R5GZ7XJpC6jI3Z.png" 
                               alt="Sample Logo" 
                               className="w-2/3 object-contain drop-shadow-2xl transition-all"
                               style={{ 
                                  filter: builderState.Global.FlatWhiteLogo ? 'brightness(0) invert(1) drop-shadow(0px 4px 10px rgba(0,0,0,0.8))' : 'drop-shadow(0px 4px 10px rgba(0,0,0,0.8))' 
                               }} 
                             />
                          ) : (
                             <div className="text-2xl lg:text-3xl font-bold uppercase tracking-widest">Movie Title</div>
                          )}
                        </div>
                      )}

                      {/* SEASON SPECIFIC TEXT */}
                      {previewType === 'Season' && builderState.Season.AddText && (
                        <div className="absolute left-0 w-full flex flex-col items-center z-20 pointer-events-none transition-all" style={previewStyles.text}>
                          {builderState.Season.ShowTitle && (
                             <div className="text-lg lg:text-xl font-bold uppercase tracking-wider mb-2" style={{ ...seasonTitleStyles.text, position: 'static' }}>Movie Title</div>
                          )}
                          <div className="text-xl lg:text-2xl font-bold uppercase tracking-widest">{config?.SeasonPosterOverlayPart?.SeasonOverrideText || "Season"} 1</div>
                        </div>
                      )}

                      {/* TITLE CARD TEXT */}
                      {previewType === 'TitleCard' && (
                        <div className="absolute left-[8%] z-20 pointer-events-none transition-all text-left w-full h-full">
                          {builderState.TitleCard.AddEPText && <div className="absolute left-0 text-lg lg:text-xl font-medium" style={tcEpStyles.text}>S01E01</div>}
                          {builderState.TitleCard.AddEPTitleText && <div className="absolute left-0 text-2xl lg:text-3xl font-bold uppercase tracking-wide mt-1" style={tcTitleStyles.text}>Episode Title</div>}
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

              <div className="mt-4 flex items-center justify-center gap-2">
                 {customPreviewImage ? (
                    <button onClick={resetCustomPreview} className="px-3 py-1.5 text-xs font-medium bg-theme-hover hover:bg-theme-bg text-theme-muted hover:text-theme-text border border-theme rounded-md flex items-center gap-2 transition-colors shadow-sm">
                        <RotateCcw className="w-3 h-3" /> {t("overlayAssets.resetSample", "Reset Sample")}
                    </button>
                 ) : (
                    <label className="px-3 py-1.5 text-xs font-medium bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary border border-theme-primary/20 rounded-md flex items-center gap-2 cursor-pointer transition-all hover:shadow-sm" title={t("overlayAssets.uploadSample", "Upload Sample Image")}>
                        <ImagePlus className="w-3 h-3" /> {t("overlayAssets.uploadSample", "Upload Sample Image")}
                        <input type="file" accept="image/*" onChange={handleCustomPreview} className="hidden" />
                    </label>
                 )}
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

      {/* Import Confirmation Modal */}
      {importBlueprintState && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-theme-card border border-theme rounded-xl shadow-2xl w-full max-w-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div className="p-6 border-b border-theme bg-theme-bg/50">
              <h2 className="text-2xl font-bold text-theme-text flex items-center gap-2">
                <AlertCircle className="w-6 h-6 text-theme-primary" />
                {t("blueprints.importConfirmTitle", "Confirm Blueprint Import")}
              </h2>
              <p className="text-theme-muted mt-2">
                {t("blueprints.importConfirmDesc", "The following settings will be modified by this blueprint. Do you want to proceed?")}
              </p>
            </div>
            
            <div className="p-6 overflow-y-auto custom-scrollbar flex-grow space-y-4">
              <div className="bg-theme-bg/50 rounded-lg border border-theme p-4">
                <h3 className="font-semibold text-theme-text mb-4 border-b border-theme pb-2">Proposed Changes</h3>
                <ul className="space-y-2 text-sm">
                  {Object.entries(importBlueprintState.updates?.flat || {}).map(([key, val]) => (
                    <li key={key} className="flex flex-col sm:flex-row sm:items-center justify-between border-b border-theme/10 pb-2 last:border-0 last:pb-0">
                      <span className="text-theme-muted truncate mr-4" title={displayNames[key] || key}>{displayNames[key] || key}</span>
                      <span className="text-theme-primary font-mono bg-theme-primary/10 px-2 py-0.5 rounded shrink-0">{String(val)}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>

            <div className="p-6 border-t border-theme bg-theme-bg/50 flex justify-end gap-3">
              <button 
                onClick={() => setImportBlueprintState(null)} 
                disabled={isImporting}
                className="px-6 py-2.5 rounded-lg font-medium text-theme-text bg-theme-bg border border-theme hover:bg-theme-hover transition-colors"
              >
                {t("common.cancel", "Cancel")}
              </button>
              <button 
                onClick={confirmImport} 
                disabled={isImporting}
                className="flex items-center gap-2 bg-theme-primary text-white px-6 py-2.5 rounded-lg font-medium shadow-lg hover:bg-theme-primary/90 transition-colors disabled:opacity-50"
              >
                {isImporting ? <Loader2 className="w-5 h-5 animate-spin" /> : <CheckCircle2 className="w-5 h-5" />}
                {isImporting ? t("blueprints.importing", "Importing...") : t("blueprints.importConfirmBtn", "Confirm Import")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
