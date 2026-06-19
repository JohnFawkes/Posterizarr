import React, { useState, useEffect, useRef } from "react";
import { Loader2, Palette, Image, Layers, CheckCircle2, AlertCircle, Type, Square, Languages, Sparkles, Download, Upload, Info, Sliders, LayoutTemplate, ChevronDown, ChevronRight, Settings, ImagePlus, RotateCcw, Wand2, MousePointerClick, Trash2, Save, X } from "lucide-react";
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
  <div className="flex items-center gap-2 mt-2 w-full">
    <div className="relative w-8 h-8 rounded-lg overflow-hidden border border-theme shadow-sm shrink-0">
      <input type="color" value={value || "#ffffff"} onChange={e => onChange(e.target.value)} className="absolute -top-2 -left-2 w-12 h-12 cursor-pointer p-0 border-0" title={label} />
    </div>
    <div className="flex-grow flex flex-col">
       <span className="text-xs text-theme-muted uppercase tracking-wider">{label}</span>
       <input type="text" value={value || "#ffffff"} onChange={e => onChange(e.target.value)} className="w-full bg-transparent border-b border-theme/50 px-1 py-0.5 text-sm font-mono uppercase text-theme-text focus:border-theme-primary focus:outline-none transition-colors" />
    </div>
  </div>
);

const NumberInput = ({ label, value, onChange, min = 0, max = 5000 }) => (
  <div className="flex flex-col gap-1 mt-3 w-full">
    <span className="text-xs text-theme-muted uppercase tracking-wider">{label}</span>
    <input type="number" min={min} max={max} value={value || 0} onChange={(e) => onChange(e.target.value)} className="bg-theme-bg border border-theme rounded-md px-3 py-1.5 text-sm w-full focus:border-theme-primary outline-none transition-colors text-theme-text" />
  </div>
);

const SelectInput = ({ label, value, onChange, options }) => (
  <div className="flex flex-col gap-1 mt-3 w-full">
    <span className="text-xs text-theme-muted uppercase tracking-wider">{label}</span>
    <select value={value} onChange={(e) => onChange(e.target.value)} className="bg-theme-bg border border-theme rounded-md px-3 py-1.5 text-sm w-full focus:border-theme-primary outline-none transition-colors text-theme-text">
      {options.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
    </select>
  </div>
);

const TextInput = ({ label, value, onChange, placeholder = "" }) => (
  <div className="flex flex-col gap-1 mt-3 w-full">
    <span className="text-xs text-theme-muted uppercase tracking-wider">{label}</span>
    <input type="text" placeholder={placeholder} value={value || ""} onChange={(e) => onChange(e.target.value)} className="bg-theme-bg border border-theme rounded-md px-3 py-1.5 text-sm w-full focus:border-theme-primary outline-none transition-colors text-theme-text" />
  </div>
);

const LayerItem = ({ id, label, icon: Icon, active, onSelect, enabled, onToggle, showToggle = true }) => (
  <div
    onClick={() => onSelect(id)}
    className={`flex items-center justify-between p-3 rounded-lg cursor-pointer border transition-all duration-200 ${
      active ? 'bg-theme-primary/10 border-theme-primary shadow-sm' : 'bg-theme-bg/50 border-theme hover:bg-theme-card'
    }`}
  >
    <div className="flex items-center gap-3">
      <Icon className={`w-4 h-4 ${active ? 'text-theme-primary' : 'text-theme-muted'}`} />
      <span className={`text-sm font-medium ${active ? 'text-theme-text' : 'text-theme-muted'}`}>{label}</span>
    </div>
    {showToggle && (
      <button onClick={(e) => { e.stopPropagation(); onToggle(!enabled); }} className={`p-1.5 rounded-md transition-colors ${enabled ? 'text-theme-primary hover:bg-theme-primary/20' : 'text-theme-muted hover:bg-theme-hover'}`}>
        {enabled ? <CheckCircle2 className="w-4 h-4" /> : <Square className="w-4 h-4 opacity-50" />}
      </button>
    )}
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
    outputQuality: 100,
    Poster: { AddBorder: false, AddOverlay: false, overlayfile: "overlay-innerglow.png", AddText: false, AddTextStroke: false, UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+430", fontAllCaps: true, minPointSize: 45, maxPointSize: 300, lineSpacing: 0, MaxWidth: 1900, MaxHeight: 500, TextGravity: "south" },
    Season: { AddBorder: false, AddOverlay: false, overlayfile: "overlay-innerglow.png", AddText: false, AddTextStroke: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+400", fontAllCaps: true, minPointSize: 95, maxPointSize: 250, lineSpacing: 0, MaxWidth: 1900, MaxHeight: 500, TextGravity: "south", ShowFallback: false, OverrideSeasonName: false, SeasonOverrideText: "Season", SpecialSeasonOverrideText: "Specials" },
    SeasonTitle: { ShowTitle: false, fontAllCaps: true, AddTextStroke: false, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", minPointSize: 45, maxPointSize: 300, MaxWidth: 1900, MaxHeight: 500, text_offset: "+300", lineSpacing: 0, TextGravity: "south" },
    TitleCard: { AddBorder: false, AddOverlay: false, overlayfile: "backgroundoverlay-innerglow.png", UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, UseBackgroundAsTitleCard: false, BackgroundFallback: true },
    TitleCardEPTitle: { AddEPTitleText: false, fontAllCaps: true, AddTextStroke: false, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", minPointSize: 50, maxPointSize: 150, MaxWidth: 3640, MaxHeight: 280, text_offset: "+300", lineSpacing: 0, TextGravity: "south" },
    TitleCardEPText: { AddEPText: false, fontAllCaps: true, AddTextStroke: false, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", minPointSize: 50, maxPointSize: 150, MaxWidth: 3640, MaxHeight: 280, text_offset: "+100", lineSpacing: 0, TextGravity: "south", SeasonTCText: "Season", EpisodeTCText: "Episode" },
    Background: { AddBorder: false, AddText: false, AddTextStroke: false, AddOverlay: false, overlayfile: "backgroundoverlay-innerglow.png", UseResolutionOverlays: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+200", fontAllCaps: true, minPointSize: 100, maxPointSize: 300, lineSpacing: 0, MaxWidth: 3640, MaxHeight: 500, TextGravity: "south" },
    Collection: { AddBorder: false, AddOverlay: false, overlayfile: "overlay-innerglow.png", AddText: false, AddTextStroke: false, bordercolor: "#ffffff", borderwidth: 30, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", text_offset: "+300", fontAllCaps: true, minPointSize: 100, maxPointSize: 250, lineSpacing: 0, MaxWidth: 1900, MaxHeight: 500, TextGravity: "south" },
    CollectionTitle: { AddCollectionTitle: true, CollectionTitle: "Collection", fontAllCaps: true, AddTextStroke: false, strokecolor: "#000000", strokewidth: 6, fontcolor: "#ffffff", minPointSize: 50, maxPointSize: 100, MaxWidth: 1000, MaxHeight: 140, text_offset: "+150", lineSpacing: 0, TextGravity: "south" },
    ResolutionOverlays: {
      poster4k: "overlay-innerglow.png",
      Poster1080p: "overlay-innerglow.png",
      Background4k: "backgroundoverlay-innerglow.png",
      Background1080p: "backgroundoverlay-innerglow.png",
      TC4k: "backgroundoverlay-innerglow.png",
      TC1080p: "backgroundoverlay-innerglow.png",
      "4KDoVi": "overlay-innerglow.png",
      "4KHDR10": "overlay-innerglow.png",
      "4KDoViHDR10": "overlay-innerglow.png",
      "4KDoViBackground": "backgroundoverlay-innerglow.png",
      "4KHDR10Background": "backgroundoverlay-innerglow.png",
      "4KDoViHDR10Background": "backgroundoverlay-innerglow.png",
      "4KDoViTC": "backgroundoverlay-innerglow.png",
      "4KHDR10TC": "backgroundoverlay-innerglow.png"
    },
    Global: {
      UseClearlogo: true,
      UseClearart: false,
      UseOriginalTitle: false,
      FlatWhiteLogo: false,
      TextlessOnly: false
    }
  });

  const [previewType, setPreviewType] = useState("Poster"); // "Poster", "Season", "TitleCard", "Background", "Collection"
  const [selectedLayer, setSelectedLayer] = useState("Global");
  const [importBlueprintState, setImportBlueprintState] = useState(null);

  // Custom Presets State
  const [customBlueprints, setCustomBlueprints] = useState([]);
  const [savePresetModalState, setSavePresetModalState] = useState(null);

  // Preview Data State
  const [sampleText, setSampleText] = useState("Movie Title");
  const [sampleLogoUrl, setSampleLogoUrl] = useState("https://wsrv.nl/?url=images.fanart.tv/fanart/forrest-gump-5067372b0496a.png");
  const [sampleArtUrl, setSampleArtUrl] = useState("https://wsrv.nl/?url=images.fanart.tv/fanart/forrest-gump-513da6251196a.png");

  useEffect(() => {
    fetchConfig();
    const stored = localStorage.getItem("posterizarr_custom_blueprints");
    if (stored) {
      try {
        setCustomBlueprints(JSON.parse(stored));
      } catch (e) {
        console.error("Failed to parse custom blueprints", e);
      }
    }
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
          outputQuality: parseInt(data.config.OverlayPart?.outputQuality?.replace('%', '') || 100),
          Poster: {
             ...prev.Poster,
             AddBorder: data.config.PosterOverlayPart?.AddBorder === "true",
             AddOverlay: data.config.PosterOverlayPart?.AddOverlay === "true",
             overlayfile: data.config.PrerequisitePart?.overlayfile || "overlay-innerglow.png",
             AddText: data.config.PosterOverlayPart?.AddText === "true",
             AddTextStroke: data.config.PosterOverlayPart?.AddTextStroke === "true",
             UseResolutionOverlays: data.config.PrerequisitePart?.UsePosterResolutionOverlays === "true",
             bordercolor: data.config.PosterOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.PosterOverlayPart?.borderwidth || 30),
             fontcolor: data.config.PosterOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.PosterOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.PosterOverlayPart?.strokewidth || 6),
             text_offset: data.config.PosterOverlayPart?.text_offset || "+430",
             fontAllCaps: data.config.PosterOverlayPart?.fontAllCaps === "true",
             minPointSize: parseInt(data.config.PosterOverlayPart?.minPointSize || 45),
             maxPointSize: parseInt(data.config.PosterOverlayPart?.maxPointSize || 300),
             lineSpacing: parseInt(data.config.PosterOverlayPart?.lineSpacing || 0),
             MaxWidth: parseInt(data.config.PosterOverlayPart?.MaxWidth || 1900),
             MaxHeight: parseInt(data.config.PosterOverlayPart?.MaxHeight || 500),
             TextGravity: data.config.PosterOverlayPart?.TextGravity || "south"
          },
          Season: {
             ...prev.Season,
             AddBorder: data.config.SeasonPosterOverlayPart?.AddBorder === "true",
             AddOverlay: data.config.SeasonPosterOverlayPart?.AddOverlay === "true",
             overlayfile: data.config.PrerequisitePart?.seasonoverlayfile || "overlay-innerglow.png",
             AddText: data.config.SeasonPosterOverlayPart?.AddText === "true",
             AddTextStroke: data.config.SeasonPosterOverlayPart?.AddTextStroke === "true",
             bordercolor: data.config.SeasonPosterOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.SeasonPosterOverlayPart?.borderwidth || 30),
             fontcolor: data.config.SeasonPosterOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.SeasonPosterOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.SeasonPosterOverlayPart?.strokewidth || 6),
             text_offset: data.config.SeasonPosterOverlayPart?.text_offset || "+400",
             fontAllCaps: data.config.SeasonPosterOverlayPart?.fontAllCaps === "true",
             minPointSize: parseInt(data.config.SeasonPosterOverlayPart?.minPointSize || 95),
             maxPointSize: parseInt(data.config.SeasonPosterOverlayPart?.maxPointSize || 250),
             lineSpacing: parseInt(data.config.SeasonPosterOverlayPart?.lineSpacing || 0),
             MaxWidth: parseInt(data.config.SeasonPosterOverlayPart?.MaxWidth || 1900),
             MaxHeight: parseInt(data.config.SeasonPosterOverlayPart?.MaxHeight || 500),
             TextGravity: data.config.SeasonPosterOverlayPart?.TextGravity || "south",
             ShowFallback: data.config.SeasonPosterOverlayPart?.ShowFallback === "true",
             OverrideSeasonName: data.config.SeasonPosterOverlayPart?.OverrideSeasonName === "true",
             SeasonOverrideText: data.config.SeasonPosterOverlayPart?.SeasonOverrideText || "Season",
             SpecialSeasonOverrideText: data.config.SeasonPosterOverlayPart?.SpecialSeasonOverrideText || "Specials"
          },
          SeasonTitle: {
             ...prev.SeasonTitle,
             ShowTitle: data.config.ShowTitleOnSeasonPosterPart?.AddShowTitletoSeason === "true",
             fontAllCaps: data.config.ShowTitleOnSeasonPosterPart?.fontAllCaps === "true",
             AddTextStroke: data.config.ShowTitleOnSeasonPosterPart?.AddTextStroke === "true",
             strokecolor: data.config.ShowTitleOnSeasonPosterPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.ShowTitleOnSeasonPosterPart?.strokewidth || 6),
             fontcolor: data.config.ShowTitleOnSeasonPosterPart?.fontcolor || "#ffffff",
             minPointSize: parseInt(data.config.ShowTitleOnSeasonPosterPart?.minPointSize || 45),
             maxPointSize: parseInt(data.config.ShowTitleOnSeasonPosterPart?.maxPointSize || 300),
             MaxWidth: parseInt(data.config.ShowTitleOnSeasonPosterPart?.MaxWidth || 1900),
             MaxHeight: parseInt(data.config.ShowTitleOnSeasonPosterPart?.MaxHeight || 500),
             text_offset: data.config.ShowTitleOnSeasonPosterPart?.text_offset || "+300",
             lineSpacing: parseInt(data.config.ShowTitleOnSeasonPosterPart?.lineSpacing || 0),
             TextGravity: data.config.ShowTitleOnSeasonPosterPart?.TextGravity || "south"
          },
          Background: {
             ...prev.Background,
             AddBorder: data.config.BackgroundOverlayPart?.AddBorder === "true",
             AddText: data.config.BackgroundOverlayPart?.AddText === "true",
             AddTextStroke: data.config.BackgroundOverlayPart?.AddTextStroke === "true",
             AddOverlay: data.config.BackgroundOverlayPart?.AddOverlay === "true",
             overlayfile: data.config.PrerequisitePart?.backgroundoverlayfile || "backgroundoverlay-innerglow.png",
             UseResolutionOverlays: data.config.PrerequisitePart?.UseBackgroundResolutionOverlays === "true",
             bordercolor: data.config.BackgroundOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.BackgroundOverlayPart?.borderwidth || 30),
             fontcolor: data.config.BackgroundOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.BackgroundOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.BackgroundOverlayPart?.strokewidth || 6),
             text_offset: data.config.BackgroundOverlayPart?.text_offset || "+200",
             fontAllCaps: data.config.BackgroundOverlayPart?.fontAllCaps === "true",
             minPointSize: parseInt(data.config.BackgroundOverlayPart?.minPointSize || 100),
             maxPointSize: parseInt(data.config.BackgroundOverlayPart?.maxPointSize || 300),
             lineSpacing: parseInt(data.config.BackgroundOverlayPart?.lineSpacing || 0),
             MaxWidth: parseInt(data.config.BackgroundOverlayPart?.MaxWidth || 3640),
             MaxHeight: parseInt(data.config.BackgroundOverlayPart?.MaxHeight || 500),
             TextGravity: data.config.BackgroundOverlayPart?.TextGravity || "south"
          },
          TitleCard: {
             ...prev.TitleCard,
             AddBorder: data.config.TitleCardOverlayPart?.AddBorder === "true",
             AddOverlay: data.config.TitleCardOverlayPart?.AddOverlay === "true",
             overlayfile: data.config.PrerequisitePart?.titlecardoverlayfile || "backgroundoverlay-innerglow.png",
             UseResolutionOverlays: data.config.PrerequisitePart?.UseTCResolutionOverlays === "true",
             bordercolor: data.config.TitleCardOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.TitleCardOverlayPart?.borderwidth || 30),
             UseBackgroundAsTitleCard: data.config.TitleCardOverlayPart?.UseBackgroundAsTitleCard === "true",
             BackgroundFallback: data.config.TitleCardOverlayPart?.BackgroundFallback === "true",
          },
          TitleCardEPTitle: {
             ...prev.TitleCardEPTitle,
             AddEPTitleText: data.config.TitleCardTitleTextPart?.AddEPTitleText === "true",
             fontAllCaps: data.config.TitleCardTitleTextPart?.fontAllCaps === "true",
             AddTextStroke: data.config.TitleCardTitleTextPart?.AddTextStroke === "true",
             strokecolor: data.config.TitleCardTitleTextPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.TitleCardTitleTextPart?.strokewidth || 6),
             fontcolor: data.config.TitleCardTitleTextPart?.fontcolor || "#ffffff",
             minPointSize: parseInt(data.config.TitleCardTitleTextPart?.minPointSize || 50),
             maxPointSize: parseInt(data.config.TitleCardTitleTextPart?.maxPointSize || 150),
             MaxWidth: parseInt(data.config.TitleCardTitleTextPart?.MaxWidth || 3640),
             MaxHeight: parseInt(data.config.TitleCardTitleTextPart?.MaxHeight || 280),
             text_offset: data.config.TitleCardTitleTextPart?.text_offset || "+300",
             lineSpacing: parseInt(data.config.TitleCardTitleTextPart?.lineSpacing || 0),
             TextGravity: data.config.TitleCardTitleTextPart?.TextGravity || "south"
          },
          TitleCardEPText: {
             ...prev.TitleCardEPText,
             AddEPText: data.config.TitleCardEPTextPart?.AddEPText === "true",
             fontAllCaps: data.config.TitleCardEPTextPart?.fontAllCaps === "true",
             AddTextStroke: data.config.TitleCardEPTextPart?.AddTextStroke === "true",
             strokecolor: data.config.TitleCardEPTextPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.TitleCardEPTextPart?.strokewidth || 6),
             fontcolor: data.config.TitleCardEPTextPart?.fontcolor || "#ffffff",
             minPointSize: parseInt(data.config.TitleCardEPTextPart?.minPointSize || 50),
             maxPointSize: parseInt(data.config.TitleCardEPTextPart?.maxPointSize || 150),
             MaxWidth: parseInt(data.config.TitleCardEPTextPart?.MaxWidth || 3640),
             MaxHeight: parseInt(data.config.TitleCardEPTextPart?.MaxHeight || 280),
             text_offset: data.config.TitleCardEPTextPart?.text_offset || "+100",
             lineSpacing: parseInt(data.config.TitleCardEPTextPart?.lineSpacing || 0),
             TextGravity: data.config.TitleCardEPTextPart?.TextGravity || "south",
             SeasonTCText: data.config.TitleCardEPTextPart?.SeasonTCText || "Season",
             EpisodeTCText: data.config.TitleCardEPTextPart?.EpisodeTCText || "Episode"
          },
          Collection: {
             ...prev.Collection,
             AddBorder: data.config.CollectionPosterOverlayPart?.AddBorder === "true",
             AddOverlay: data.config.CollectionPosterOverlayPart?.AddOverlay === "true",
             overlayfile: data.config.PrerequisitePart?.collectionoverlayfile || "overlay-innerglow.png",
             AddText: data.config.CollectionPosterOverlayPart?.AddText === "true",
             AddTextStroke: data.config.CollectionPosterOverlayPart?.AddTextStroke === "true",
             bordercolor: data.config.CollectionPosterOverlayPart?.bordercolor || "#000000",
             borderwidth: parseInt(data.config.CollectionPosterOverlayPart?.borderwidth || 30),
             fontcolor: data.config.CollectionPosterOverlayPart?.fontcolor || "#ffffff",
             strokecolor: data.config.CollectionPosterOverlayPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.CollectionPosterOverlayPart?.strokewidth || 6),
             text_offset: data.config.CollectionPosterOverlayPart?.text_offset || "+300",
             fontAllCaps: data.config.CollectionPosterOverlayPart?.fontAllCaps === "true",
             minPointSize: parseInt(data.config.CollectionPosterOverlayPart?.minPointSize || 100),
             maxPointSize: parseInt(data.config.CollectionPosterOverlayPart?.maxPointSize || 250),
             lineSpacing: parseInt(data.config.CollectionPosterOverlayPart?.lineSpacing || 0),
             MaxWidth: parseInt(data.config.CollectionPosterOverlayPart?.MaxWidth || 1900),
             MaxHeight: parseInt(data.config.CollectionPosterOverlayPart?.MaxHeight || 500),
             TextGravity: data.config.CollectionPosterOverlayPart?.TextGravity || "south"
          },
          CollectionTitle: {
             ...prev.CollectionTitle,
             AddCollectionTitle: data.config.CollectionTitlePosterPart?.AddCollectionTitle === "true",
             CollectionTitle: data.config.CollectionTitlePosterPart?.CollectionTitle || "Collection",
             fontAllCaps: data.config.CollectionTitlePosterPart?.fontAllCaps === "true",
             AddTextStroke: data.config.CollectionTitlePosterPart?.AddTextStroke === "true",
             strokecolor: data.config.CollectionTitlePosterPart?.strokecolor || "#000000",
             strokewidth: parseInt(data.config.CollectionTitlePosterPart?.strokewidth || 6),
             fontcolor: data.config.CollectionTitlePosterPart?.fontcolor || "#ffffff",
             minPointSize: parseInt(data.config.CollectionTitlePosterPart?.minPointSize || 50),
             maxPointSize: parseInt(data.config.CollectionTitlePosterPart?.maxPointSize || 100),
             MaxWidth: parseInt(data.config.CollectionTitlePosterPart?.MaxWidth || 1000),
             MaxHeight: parseInt(data.config.CollectionTitlePosterPart?.MaxHeight || 140),
             text_offset: data.config.CollectionTitlePosterPart?.text_offset || "+150",
             lineSpacing: parseInt(data.config.CollectionTitlePosterPart?.lineSpacing || 0),
             TextGravity: data.config.CollectionTitlePosterPart?.TextGravity || "south"
          },
          ResolutionOverlays: {
      poster4k: "overlay-innerglow.png",
      Poster1080p: "overlay-innerglow.png",
      Background4k: "backgroundoverlay-innerglow.png",
      Background1080p: "backgroundoverlay-innerglow.png",
      TC4k: "backgroundoverlay-innerglow.png",
      TC1080p: "backgroundoverlay-innerglow.png",
      "4KDoVi": "overlay-innerglow.png",
      "4KHDR10": "overlay-innerglow.png",
      "4KDoViHDR10": "overlay-innerglow.png",
      "4KDoViBackground": "backgroundoverlay-innerglow.png",
      "4KHDR10Background": "backgroundoverlay-innerglow.png",
      "4KDoViHDR10Background": "backgroundoverlay-innerglow.png",
      "4KDoViTC": "backgroundoverlay-innerglow.png",
      "4KHDR10TC": "backgroundoverlay-innerglow.png"
    },
    Global: {
             UseClearlogo: data.config.PrerequisitePart?.UseClearlogo === "true",
             UseClearart: data.config.PrerequisitePart?.UseClearart === "true",
             UseOriginalTitle: data.config.PrerequisitePart?.UseOriginalTitle === "true",
             FlatWhiteLogo: data.config.PrerequisitePart?.ConvertLogoColor === "true",
             TextlessOnly: data.config.PrerequisitePart?.SkipAddText === "true"
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

  const generateBlueprintUpdates = () => {
    return {
      OverlayPart: {
        ImageProcessing: builderState.ImageProcessing ? "true" : "false",
        outputQuality: `${builderState.outputQuality}%`
      },
      PrerequisitePart: {
        UseClearlogo: builderState.Global.UseClearlogo ? "true" : "false",
        UseClearart: builderState.Global.UseClearart ? "true" : "false",
        UseOriginalTitle: builderState.Global.UseOriginalTitle ? "true" : "false",
        ConvertLogoColor: builderState.Global.FlatWhiteLogo ? "true" : "false",
        LogoFlatColor: builderState.Global.FlatWhiteLogo ? "white" : undefined,
        SkipAddText: builderState.Global.TextlessOnly ? "true" : "false",
        UsePosterResolutionOverlays: builderState.Poster.UseResolutionOverlays ? "true" : "false",
        UseBackgroundResolutionOverlays: builderState.Background.UseResolutionOverlays ? "true" : "false",
        UseTCResolutionOverlays: builderState.TitleCard.UseResolutionOverlays ? "true" : "false",
                backgroundoverlayfile: builderState.Background.overlayfile,
        showbackgroundoverlayfile: builderState.Background.overlayfile,
        titlecardoverlayfile: builderState.TitleCard.overlayfile,
        overlayfile: builderState.Poster.overlayfile,
        showoverlayfile: builderState.Poster.overlayfile,
        seasonoverlayfile: builderState.Season.overlayfile,
        collectionoverlayfile: builderState.Collection.overlayfile,
        poster4k: builderState.ResolutionOverlays.poster4k,
        Poster1080p: builderState.ResolutionOverlays.Poster1080p,
        Background4k: builderState.ResolutionOverlays.Background4k,
        Background1080p: builderState.ResolutionOverlays.Background1080p,
        TC4k: builderState.ResolutionOverlays.TC4k,
        TC1080p: builderState.ResolutionOverlays.TC1080p,
        "4KDoVi": builderState.ResolutionOverlays["4KDoVi"],
        "4KHDR10": builderState.ResolutionOverlays["4KHDR10"],
        "4KDoViHDR10": builderState.ResolutionOverlays["4KDoViHDR10"],
        "4KDoViBackground": builderState.ResolutionOverlays["4KDoViBackground"],
        "4KHDR10Background": builderState.ResolutionOverlays["4KHDR10Background"],
        "4KDoViHDR10Background": builderState.ResolutionOverlays["4KDoViHDR10Background"],
        "4KDoViTC": builderState.ResolutionOverlays["4KDoViTC"],
        "4KHDR10TC": builderState.ResolutionOverlays["4KHDR10TC"]
      },
      PosterOverlayPart: {
        AddBorder: builderState.Poster.AddBorder ? "true" : "false",
        AddText: builderState.Poster.AddText ? "true" : "false",
        AddTextStroke: builderState.Poster.AddTextStroke ? "true" : "false",
        AddOverlay: builderState.Poster.AddOverlay ? "true" : "false",
        bordercolor: builderState.Poster.bordercolor,
        borderwidth: builderState.Poster.borderwidth.toString(),
        fontcolor: builderState.Poster.fontcolor,
        strokecolor: builderState.Poster.strokecolor,
        strokewidth: builderState.Poster.strokewidth.toString(),
        text_offset: builderState.Poster.text_offset,
        fontAllCaps: builderState.Poster.fontAllCaps ? "true" : "false",
        minPointSize: builderState.Poster.minPointSize.toString(),
        maxPointSize: builderState.Poster.maxPointSize.toString(),
        lineSpacing: builderState.Poster.lineSpacing.toString(),
        MaxWidth: builderState.Poster.MaxWidth.toString(),
        MaxHeight: builderState.Poster.MaxHeight.toString(),
        TextGravity: builderState.Poster.TextGravity
      },
      SeasonPosterOverlayPart: {
        AddBorder: builderState.Season.AddBorder ? "true" : "false",
        AddText: builderState.Season.AddText ? "true" : "false",
        AddTextStroke: builderState.Season.AddTextStroke ? "true" : "false",
        AddOverlay: builderState.Season.AddOverlay ? "true" : "false",
        bordercolor: builderState.Season.bordercolor,
        borderwidth: builderState.Season.borderwidth.toString(),
        fontcolor: builderState.Season.fontcolor,
        strokecolor: builderState.Season.strokecolor,
        strokewidth: builderState.Season.strokewidth.toString(),
        text_offset: builderState.Season.text_offset,
        fontAllCaps: builderState.Season.fontAllCaps ? "true" : "false",
        minPointSize: builderState.Season.minPointSize.toString(),
        maxPointSize: builderState.Season.maxPointSize.toString(),
        lineSpacing: builderState.Season.lineSpacing.toString(),
        MaxWidth: builderState.Season.MaxWidth.toString(),
        MaxHeight: builderState.Season.MaxHeight.toString(),
        TextGravity: builderState.Season.TextGravity,
        ShowFallback: builderState.Season.ShowFallback ? "true" : "false",
        OverrideSeasonName: builderState.Season.OverrideSeasonName ? "true" : "false",
        SeasonOverrideText: builderState.Season.SeasonOverrideText,
        SpecialSeasonOverrideText: builderState.Season.SpecialSeasonOverrideText
      },
      ShowTitleOnSeasonPosterPart: {
        AddShowTitletoSeason: builderState.SeasonTitle.ShowTitle ? "true" : "false",
        fontAllCaps: builderState.SeasonTitle.fontAllCaps ? "true" : "false",
        AddTextStroke: builderState.SeasonTitle.AddTextStroke ? "true" : "false",
        strokecolor: builderState.SeasonTitle.strokecolor,
        strokewidth: builderState.SeasonTitle.strokewidth.toString(),
        fontcolor: builderState.SeasonTitle.fontcolor,
        minPointSize: builderState.SeasonTitle.minPointSize.toString(),
        maxPointSize: builderState.SeasonTitle.maxPointSize.toString(),
        MaxWidth: builderState.SeasonTitle.MaxWidth.toString(),
        MaxHeight: builderState.SeasonTitle.MaxHeight.toString(),
        text_offset: builderState.SeasonTitle.text_offset,
        lineSpacing: builderState.SeasonTitle.lineSpacing.toString(),
        TextGravity: builderState.SeasonTitle.TextGravity
      },
      BackgroundOverlayPart: {
        AddBorder: builderState.Background.AddBorder ? "true" : "false",
        AddText: builderState.Background.AddText ? "true" : "false",
        AddTextStroke: builderState.Background.AddTextStroke ? "true" : "false",
        AddOverlay: builderState.Background.AddOverlay ? "true" : "false",
        bordercolor: builderState.Background.bordercolor,
        borderwidth: builderState.Background.borderwidth.toString(),
        fontcolor: builderState.Background.fontcolor,
        strokecolor: builderState.Background.strokecolor,
        strokewidth: builderState.Background.strokewidth.toString(),
        text_offset: builderState.Background.text_offset,
        fontAllCaps: builderState.Background.fontAllCaps ? "true" : "false",
        minPointSize: builderState.Background.minPointSize.toString(),
        maxPointSize: builderState.Background.maxPointSize.toString(),
        lineSpacing: builderState.Background.lineSpacing.toString(),
        MaxWidth: builderState.Background.MaxWidth.toString(),
        MaxHeight: builderState.Background.MaxHeight.toString(),
        TextGravity: builderState.Background.TextGravity
      },
      TitleCardOverlayPart: {
        AddBorder: builderState.TitleCard.AddBorder ? "true" : "false",
        AddOverlay: builderState.TitleCard.AddOverlay ? "true" : "false",
        bordercolor: builderState.TitleCard.bordercolor,
        borderwidth: builderState.TitleCard.borderwidth.toString(),
        UseBackgroundAsTitleCard: builderState.TitleCard.UseBackgroundAsTitleCard ? "true" : "false",
        BackgroundFallback: builderState.TitleCard.BackgroundFallback ? "true" : "false"
      },
      TitleCardTitleTextPart: {
        AddEPTitleText: builderState.TitleCardEPTitle.AddEPTitleText ? "true" : "false",
        AddTextStroke: builderState.TitleCardEPTitle.AddTextStroke ? "true" : "false",
        fontcolor: builderState.TitleCardEPTitle.fontcolor,
        strokecolor: builderState.TitleCardEPTitle.strokecolor,
        strokewidth: builderState.TitleCardEPTitle.strokewidth.toString(),
        text_offset: builderState.TitleCardEPTitle.text_offset,
        fontAllCaps: builderState.TitleCardEPTitle.fontAllCaps ? "true" : "false",
        minPointSize: builderState.TitleCardEPTitle.minPointSize.toString(),
        maxPointSize: builderState.TitleCardEPTitle.maxPointSize.toString(),
        lineSpacing: builderState.TitleCardEPTitle.lineSpacing.toString(),
        MaxWidth: builderState.TitleCardEPTitle.MaxWidth.toString(),
        MaxHeight: builderState.TitleCardEPTitle.MaxHeight.toString(),
        TextGravity: builderState.TitleCardEPTitle.TextGravity
      },
      TitleCardEPTextPart: {
        AddEPText: builderState.TitleCardEPText.AddEPText ? "true" : "false",
        AddTextStroke: builderState.TitleCardEPText.AddTextStroke ? "true" : "false",
        fontcolor: builderState.TitleCardEPText.fontcolor,
        strokecolor: builderState.TitleCardEPText.strokecolor,
        strokewidth: builderState.TitleCardEPText.strokewidth.toString(),
        text_offset: builderState.TitleCardEPText.text_offset,
        fontAllCaps: builderState.TitleCardEPText.fontAllCaps ? "true" : "false",
        minPointSize: builderState.TitleCardEPText.minPointSize.toString(),
        maxPointSize: builderState.TitleCardEPText.maxPointSize.toString(),
        lineSpacing: builderState.TitleCardEPText.lineSpacing.toString(),
        MaxWidth: builderState.TitleCardEPText.MaxWidth.toString(),
        MaxHeight: builderState.TitleCardEPText.MaxHeight.toString(),
        TextGravity: builderState.TitleCardEPText.TextGravity,
        SeasonTCText: builderState.TitleCardEPText.SeasonTCText,
        EpisodeTCText: builderState.TitleCardEPText.EpisodeTCText
      },
      CollectionTitlePosterPart: {
        AddCollectionTitle: builderState.CollectionTitle.AddCollectionTitle ? "true" : "false",
        CollectionTitle: builderState.CollectionTitle.CollectionTitle,
        fontAllCaps: builderState.CollectionTitle.fontAllCaps ? "true" : "false",
        AddTextStroke: builderState.CollectionTitle.AddTextStroke ? "true" : "false",
        strokecolor: builderState.CollectionTitle.strokecolor,
        strokewidth: builderState.CollectionTitle.strokewidth.toString(),
        fontcolor: builderState.CollectionTitle.fontcolor,
        minPointSize: builderState.CollectionTitle.minPointSize.toString(),
        maxPointSize: builderState.CollectionTitle.maxPointSize.toString(),
        MaxWidth: builderState.CollectionTitle.MaxWidth.toString(),
        MaxHeight: builderState.CollectionTitle.MaxHeight.toString(),
        text_offset: builderState.CollectionTitle.text_offset,
        lineSpacing: builderState.CollectionTitle.lineSpacing.toString(),
        TextGravity: builderState.CollectionTitle.TextGravity
      },
      CollectionPosterOverlayPart: {
        AddBorder: builderState.Collection.AddBorder ? "true" : "false",
        AddText: builderState.Collection.AddText ? "true" : "false",
        AddTextStroke: builderState.Collection.AddTextStroke ? "true" : "false",
        AddOverlay: builderState.Collection.AddOverlay ? "true" : "false",
        bordercolor: builderState.Collection.bordercolor,
        borderwidth: builderState.Collection.borderwidth.toString(),
        fontcolor: builderState.Collection.fontcolor,
        strokecolor: builderState.Collection.strokecolor,
        strokewidth: builderState.Collection.strokewidth.toString(),
        text_offset: builderState.Collection.text_offset,
        fontAllCaps: builderState.Collection.fontAllCaps ? "true" : "false",
        minPointSize: builderState.Collection.minPointSize.toString(),
        maxPointSize: builderState.Collection.maxPointSize.toString(),
        lineSpacing: builderState.Collection.lineSpacing.toString(),
        MaxWidth: builderState.Collection.MaxWidth.toString(),
        MaxHeight: builderState.Collection.MaxHeight.toString(),
        TextGravity: builderState.Collection.TextGravity
      }
    };
  };

  const handleSavePresetClick = () => {
    const updates = generateBlueprintUpdates();
    setSavePresetModalState({ updates });
  };

  const saveCustomPreset = (title, description) => {
    if (!title) return;
    const newBlueprint = {
      id: "custom_" + Date.now(),
      titleKey: null,
      customTitle: title,
      customDescription: description,
      icon: "User",
      updates: { nested: savePresetModalState.updates }
    };
    const updatedBlueprints = [...customBlueprints, newBlueprint];
    setCustomBlueprints(updatedBlueprints);
    localStorage.setItem("posterizarr_custom_blueprints", JSON.stringify(updatedBlueprints));
    setSavePresetModalState(null);
    showSuccess("Custom Preset saved!");
    setActiveTab("presets");
  };

  const deleteCustomPreset = (id) => {
    const updatedBlueprints = customBlueprints.filter(b => b.id !== id);
    setCustomBlueprints(updatedBlueprints);
    localStorage.setItem("posterizarr_custom_blueprints", JSON.stringify(updatedBlueprints));
    showSuccess("Custom Preset deleted!");
  };

  const applyBuilderConfig = async () => {
    const nestedUpdates = generateBlueprintUpdates();

    const syntheticBlueprint = {
      id: "builder",
      title: "Custom Builder Config",
      updates: { nested: nestedUpdates }
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
      if (!parsed.updates && !parsed.PosterOverlayPart) {
        throw new Error("Invalid blueprint format. Missing updates object.");
      }

      let updates = parsed;
      if (parsed.updates) {
         updates = parsed.updates.nested || parsed.updates.flat || parsed.updates;
      }

      setSavePresetModalState({ updates, isImport: true });
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

  const getStyleObj = (categoryState) => {
    const part = categoryState || {};
    const bColor = part.bordercolor || "white";
    const bWidth = Math.max(2, (parseInt(part.borderwidth) || 30) * 0.15); // scaled
    const fColor = part.fontcolor || "white";
    const sColor = part.strokecolor || "black";
    const sWidth = Math.max(1, (parseInt(part.strokewidth) || 6) * 0.15);
    const hasStroke = part.AddTextStroke;
    const gravity = part.TextGravity?.toLowerCase() || "south";
    const offsetRaw = part.text_offset || "+400";
    let offset = parseInt(String(offsetRaw).replace('+', '').replace('-', '')) || 400;
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
        textShadow: hasStroke ? undefined : '0px 4px 10px rgba(0,0,0,0.5)'
      }
    };
  };


  const getBoundingBoxStyle = (layer) => {
    if (!layer) return {};
    const canvasW = (previewType === 'Background' || previewType === 'TitleCard') ? 3840 : 2000;
    const canvasH = (previewType === 'Background' || previewType === 'TitleCard') ? 2160 : 3000;
    const offsetRaw = layer.text_offset || "+400";
    const offset = parseInt(String(offsetRaw).replace('+', '').replace('-', '')) || 400;
    const gravity = layer.TextGravity?.toLowerCase() || "south";
    const offsetPercent = (offset / canvasH) * 100;
    const w = Math.min(100, (layer.MaxWidth / canvasW) * 100);
    const h = Math.min(100, (layer.MaxHeight / canvasH) * 100);

    let justifyContent = 'center';
    let alignItems = 'center';
    if (gravity.includes('north')) justifyContent = 'flex-start';
    if (gravity.includes('south')) justifyContent = 'flex-end';
    if (gravity.includes('west')) alignItems = 'flex-start';
    if (gravity.includes('east')) alignItems = 'flex-end';

    return {
      position: 'absolute',
      left: '50%',
      transform: 'translateX(-50%)',
      [gravity.includes('north') ? 'top' : 'bottom']: `${offsetPercent}%`,
      width: `${w}%`,
      height: `${h}%`,
      display: 'flex',
      flexDirection: 'column',
      justifyContent,
      alignItems,
      containerType: 'size'
    };
  };

  const previewStyles = getStyleObj(builderState[previewType]);


  const seasonTitleStyles = getStyleObj(builderState.SeasonTitle);
  const tcTitleStyles = getStyleObj(builderState.TitleCardEPTitle);
  const tcEpStyles = getStyleObj(builderState.TitleCardEPText);
  const collectionTitleStyles = getStyleObj(builderState.CollectionTitle);

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
            {[...BLUEPRINTS, ...customBlueprints].map((blueprint) => {
              const Icon = typeof blueprint.icon === "string" ? Layers : blueprint.icon;
              const isApplying = applyingId === blueprint.id;
              return (
                <div key={blueprint.id} className="bg-theme-bg/50 border border-theme rounded-xl p-5 hover:border-theme-primary/50 transition-all flex flex-col h-full group shadow-md hover:shadow-lg">
                  <div className="flex items-start gap-4 mb-4">
                    <div className="p-3 bg-theme-primary/10 rounded-xl text-theme-primary group-hover:scale-110 transition-transform">
                      <Icon className="w-6 h-6" />
                    </div>
                    <div className="flex-grow">
                      <div className="flex items-center gap-2">
                        <h3 className="text-lg font-semibold text-theme-text">{blueprint.customTitle || t(blueprint.titleKey)}</h3>
                      </div>
                    </div>
                  </div>
                  {blueprint.images && blueprint.images.length > 0 && (
                    <div className="flex gap-2 mb-4 overflow-x-auto pb-2 custom-scrollbar items-center">
                      {blueprint.images.map((img, idx) => (
                        <img key={idx} src={img} alt={`${blueprint.customTitle || t(blueprint.titleKey)} preview ${idx + 1}`} className="h-32 object-contain rounded-md bg-black/20 shrink-0 shadow-sm" />
                      ))}
                    </div>
                  )}
                  <p className="text-sm text-theme-muted flex-grow mb-4">{blueprint.customDescription || t(blueprint.descriptionKey)}</p>

                  {blueprint.id.startsWith("custom_") && (
                    <button onClick={(e) => { e.stopPropagation(); deleteCustomPreset(blueprint.id); }} className="text-theme-muted hover:text-red-500 p-1.5 rounded-lg bg-theme-bg/50 hover:bg-red-500/10 transition-colors w-min mb-4 self-end" title="Delete Preset">
                      <Trash2 className="w-5 h-5" />
                    </button>
                  )}
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
          <div className="grid grid-cols-1 xl:grid-cols-12 gap-6 items-start">

            {/* Left Column: Layers */}
            <div className="xl:col-span-3 space-y-4">
              <div className="bg-theme-bg/50 border border-theme rounded-xl p-4 shadow-sm h-full max-h-[800px] overflow-y-auto custom-scrollbar">
                <h3 className="font-bold text-theme-text border-b border-theme pb-3 mb-4 flex items-center gap-2">
                  <Layers className="w-5 h-5 text-theme-primary" /> Layers
                </h3>

                <div className="space-y-6">
                  <div className="space-y-2">
                    <h4 className="text-xs font-semibold text-theme-muted uppercase tracking-wider mb-2">Global</h4>
                    <LayerItem id="Global" label="Global Settings" icon={Settings} active={selectedLayer === "Global"} onSelect={setSelectedLayer} showToggle={false} />
                  </div>

                  <div className="space-y-2">
                    <h4 className="text-xs font-semibold text-theme-muted uppercase tracking-wider mb-2">{previewType} Overlays</h4>

                    {previewType === "Poster" && (
                      <>
                        <LayerItem id="Poster.Border" label="Border" icon={Square} active={selectedLayer === "Poster.Border"} onSelect={setSelectedLayer} enabled={builderState.Poster.AddBorder} onToggle={(v) => updateBuilder("Poster", "AddBorder", v)} />
                        <LayerItem id="Poster.Overlay" label="Overlay" icon={Layers} active={selectedLayer === "Poster.Overlay"} onSelect={setSelectedLayer} enabled={builderState.Poster.AddOverlay} onToggle={(v) => updateBuilder("Poster", "AddOverlay", v)} />
                        <LayerItem id="Poster.Text" label="Text / Logo" icon={Type} active={selectedLayer === "Poster.Text"} onSelect={setSelectedLayer} enabled={builderState.Poster.AddText} onToggle={(v) => updateBuilder("Poster", "AddText", v)} />
                        <LayerItem id="Poster.Resolution" label="Resolution Overlays" icon={Image} active={selectedLayer === "Poster.Resolution"} onSelect={setSelectedLayer} enabled={builderState.Poster.UseResolutionOverlays} onToggle={(v) => updateBuilder("Poster", "UseResolutionOverlays", v)} />
                      </>
                    )}

                    {previewType === "Season" && (
                      <>
                        <LayerItem id="Season.Border" label="Border" icon={Square} active={selectedLayer === "Season.Border"} onSelect={setSelectedLayer} enabled={builderState.Season.AddBorder} onToggle={(v) => updateBuilder("Season", "AddBorder", v)} />
                        <LayerItem id="Season.Overlay" label="Overlay" icon={Layers} active={selectedLayer === "Season.Overlay"} onSelect={setSelectedLayer} enabled={builderState.Season.AddOverlay} onToggle={(v) => updateBuilder("Season", "AddOverlay", v)} />
                        <LayerItem id="Season.Text" label="Text / Logo" icon={Type} active={selectedLayer === "Season.Text"} onSelect={setSelectedLayer} enabled={builderState.Season.AddText} onToggle={(v) => updateBuilder("Season", "AddText", v)} />
                        <LayerItem id="SeasonTitle" label="Show Title" icon={Type} active={selectedLayer === "SeasonTitle"} onSelect={setSelectedLayer} enabled={builderState.SeasonTitle.ShowTitle} onToggle={(v) => updateBuilder("SeasonTitle", "ShowTitle", v)} />
                      </>
                    )}

                    {previewType === "Background" && (
                      <>
                        <LayerItem id="Background.Border" label="Border" icon={Square} active={selectedLayer === "Background.Border"} onSelect={setSelectedLayer} enabled={builderState.Background.AddBorder} onToggle={(v) => updateBuilder("Background", "AddBorder", v)} />
                        <LayerItem id="Background.Text" label="Text / Logo" icon={Type} active={selectedLayer === "Background.Text"} onSelect={setSelectedLayer} enabled={builderState.Background.AddText} onToggle={(v) => updateBuilder("Background", "AddText", v)} />
                        <LayerItem id="Background.Overlay" label="Overlay" icon={Layers} active={selectedLayer === "Background.Overlay"} onSelect={setSelectedLayer} enabled={builderState.Background.AddOverlay} onToggle={(v) => updateBuilder("Background", "AddOverlay", v)} />
                        <LayerItem id="Background.Resolution" label="Resolution Overlays" icon={Image} active={selectedLayer === "Background.Resolution"} onSelect={setSelectedLayer} enabled={builderState.Background.UseResolutionOverlays} onToggle={(v) => updateBuilder("Background", "UseResolutionOverlays", v)} />
                      </>
                    )}

                    {previewType === "TitleCard" && (
                      <>
                        <LayerItem id="TitleCard.Border" label="Border" icon={Square} active={selectedLayer === "TitleCard.Border"} onSelect={setSelectedLayer} enabled={builderState.TitleCard.AddBorder} onToggle={(v) => updateBuilder("TitleCard", "AddBorder", v)} />
                        <LayerItem id="TitleCard.Overlay" label="Overlay" icon={Layers} active={selectedLayer === "TitleCard.Overlay"} onSelect={setSelectedLayer} enabled={builderState.TitleCard.AddOverlay} onToggle={(v) => updateBuilder("TitleCard", "AddOverlay", v)} />
                        <LayerItem id="TitleCardEPTitle" label="Episode Title" icon={Type} active={selectedLayer === "TitleCardEPTitle"} onSelect={setSelectedLayer} enabled={builderState.TitleCardEPTitle.AddEPTitleText} onToggle={(v) => updateBuilder("TitleCardEPTitle", "AddEPTitleText", v)} />
                        <LayerItem id="TitleCardEPText" label="SxxExx Text" icon={Type} active={selectedLayer === "TitleCardEPText"} onSelect={setSelectedLayer} enabled={builderState.TitleCardEPText.AddEPText} onToggle={(v) => updateBuilder("TitleCardEPText", "AddEPText", v)} />
                        <LayerItem id="TitleCard.Resolution" label="Resolution Overlays" icon={Image} active={selectedLayer === "TitleCard.Resolution"} onSelect={setSelectedLayer} enabled={builderState.TitleCard.UseResolutionOverlays} onToggle={(v) => updateBuilder("TitleCard", "UseResolutionOverlays", v)} />
                      </>
                    )}

                    {previewType === "Collection" && (
                      <>
                        <LayerItem id="Collection.Border" label="Border" icon={Square} active={selectedLayer === "Collection.Border"} onSelect={setSelectedLayer} enabled={builderState.Collection.AddBorder} onToggle={(v) => updateBuilder("Collection", "AddBorder", v)} />
                        <LayerItem id="Collection.Overlay" label="Overlay" icon={Layers} active={selectedLayer === "Collection.Overlay"} onSelect={setSelectedLayer} enabled={builderState.Collection.AddOverlay} onToggle={(v) => updateBuilder("Collection", "AddOverlay", v)} />
                        <LayerItem id="Collection.Text" label="Text / Logo" icon={Type} active={selectedLayer === "Collection.Text"} onSelect={setSelectedLayer} enabled={builderState.Collection.AddText} onToggle={(v) => updateBuilder("Collection", "AddText", v)} />
                        <LayerItem id="CollectionTitle" label="Collection Title" icon={Type} active={selectedLayer === "CollectionTitle"} onSelect={setSelectedLayer} enabled={builderState.CollectionTitle.AddCollectionTitle} onToggle={(v) => updateBuilder("CollectionTitle", "AddCollectionTitle", v)} />
                      </>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Center Column: Canvas */}
            <div className="xl:col-span-6 flex flex-col h-full space-y-4">
              <div className="bg-[#121212] rounded-xl border border-theme p-4 flex-grow flex flex-col shadow-inner relative overflow-hidden" style={{ backgroundImage: 'radial-gradient(rgba(255, 255, 255, 0.05) 1px, transparent 1px)', backgroundSize: '20px 20px' }}>

                {/* Header Dropdown */}
                <div className="flex justify-between items-center mb-4 z-10">
                  <div className="flex gap-1 bg-black/60 backdrop-blur-md p-1 rounded-lg border border-theme/50 shadow-lg">
                    {["Poster", "Season", "Background", "TitleCard", "Collection"].map((t) => (
                       <button key={t} onClick={() => { setPreviewType(t); setSelectedLayer(null); }} className={`px-4 py-1.5 text-xs lg:text-sm font-medium rounded-md transition-colors ${previewType === t ? 'bg-theme-primary text-white shadow-sm' : 'text-theme-muted hover:text-theme-text hover:bg-white/5'}`}>{t}</button>
                    ))}
                  </div>
                  <div className="flex gap-2 z-10">
                    <div className="flex flex-col gap-1 mr-4 hidden md:flex">
                        <input type="text" value={sampleText} onChange={(e) => setSampleText(e.target.value)} className="bg-black/60 backdrop-blur-md border border-theme/50 rounded text-xs px-2 py-1 text-white placeholder-white/50 w-32 focus:outline-none focus:border-theme-primary" placeholder="Sample Text" />
                        <div className="flex gap-1">
                          <input type="text" value={sampleLogoUrl} onChange={(e) => setSampleLogoUrl(e.target.value)} className="bg-black/60 backdrop-blur-md border border-theme/50 rounded text-xs px-2 py-1 text-white placeholder-white/50 w-24 focus:outline-none focus:border-theme-primary" placeholder="Clearlogo URL" title="Sample Clearlogo" />
                          <input type="text" value={sampleArtUrl} onChange={(e) => setSampleArtUrl(e.target.value)} className="bg-black/60 backdrop-blur-md border border-theme/50 rounded text-xs px-2 py-1 text-white placeholder-white/50 w-24 focus:outline-none focus:border-theme-primary" placeholder="Clearart URL" title="Sample Clearart" />
                        </div>
                    </div>
                    {customPreviewImage ? (
                      <button onClick={resetCustomPreview} className="p-2 text-theme-muted hover:text-white bg-black/60 backdrop-blur-md border border-theme/50 rounded-lg transition-colors shadow-lg" title="Reset Sample Image">
                          <RotateCcw className="w-4 h-4" />
                      </button>
                    ) : (
                      <label className="p-2 text-theme-primary hover:text-theme-primary/80 bg-theme-primary/10 hover:bg-theme-primary/20 backdrop-blur-md border border-theme-primary/30 rounded-lg cursor-pointer transition-colors shadow-lg" title="Upload Sample Image">
                          <ImagePlus className="w-4 h-4" />
                          <input type="file" accept="image/*" onChange={handleCustomPreview} className="hidden" />
                      </label>
                    )}
                  </div>
                </div>

                {/* CSS Visual Preview Container */}
                <div className="w-full flex-grow flex items-center justify-center p-4 min-h-[400px] z-10">
                  <div className={`relative overflow-hidden shadow-2xl transition-all duration-300 ${!customPreviewImage ? 'bg-black' : 'bg-black'} ${
                    previewType === 'Poster' || previewType === 'Season' || previewType === 'Collection' ? 'w-2/3 aspect-[2/3] rounded-sm' :
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
                         (previewType === 'Collection' && builderState.Collection.AddBorder) ||
                         (previewType === 'TitleCard' && builderState.TitleCard.AddBorder) ? (
                          <div className={`absolute inset-0 z-10 shadow-[inset_0_0_20px_rgba(0,0,0,0.5)] rounded-sm pointer-events-none transition-all ${selectedLayer?.endsWith('.Border') ? 'ring-2 ring-theme-primary' : ''}`} style={{ ...previewStyles.border, margin: previewStyles.border.borderWidth }}></div>
                        ) : null}

                        {/* TEXT / LOGO */}
                        {((previewType === 'Poster' && builderState.Poster.AddText) ||
                         (previewType === 'Season' && builderState.Season.AddText) ||
                         (previewType === 'Collection' && builderState.Collection.AddText) ||
                         (previewType === 'Background' && builderState.Background.AddText)) && (
                          <div className={`z-20 pointer-events-none transition-all ${selectedLayer?.endsWith('.Text') ? 'border-2 border-dashed border-red-500/50 bg-red-500/5 ring-2 ring-theme-primary ring-inset' : ''}`} style={{ ...getBoundingBoxStyle(builderState[previewType]), ...previewStyles.text }}>
                            {builderState.Global.UseClearlogo ? (
                               <img
                                 src={sampleLogoUrl}
                                 alt="Sample Logo"
                                 crossOrigin="anonymous"
                                 referrerPolicy="no-referrer"
                                 className="w-full h-full object-contain drop-shadow-2xl transition-all"
                                 style={{
                                    filter: builderState.Global.FlatWhiteLogo ? 'brightness(0) invert(1) drop-shadow(0px 4px 10px rgba(0,0,0,0.8))' : 'drop-shadow(0px 4px 10px rgba(0,0,0,0.8))'
                                 }}
                               />
                            ) : builderState.Global.UseClearart ? (
                               <img
                                 src={sampleArtUrl}
                                 alt="Sample Art"
                                 crossOrigin="anonymous"
                                 referrerPolicy="no-referrer"
                                 className="w-full h-full object-contain drop-shadow-2xl transition-all"
                               />
                            ) : (
                               <div className="font-bold tracking-widest text-center leading-none" style={{ fontSize: "min(12cqw, 90cqh)", color: previewStyles.text.color, WebkitTextStroke: previewStyles.text.WebkitTextStroke }}>{sampleText}</div>
                            )}
                          </div>
                        )}

                        {/* SEASON SPECIFIC TEXT */}
                        {previewType === 'Season' && (
                          <>
                            {builderState.SeasonTitle.ShowTitle && (
                               <div className={`z-20 pointer-events-none transition-all ${selectedLayer === 'SeasonTitle' ? 'border-2 border-dashed border-red-500/50 bg-red-500/5 ring-2 ring-theme-primary ring-inset' : ''}`} style={{ ...getBoundingBoxStyle(builderState.SeasonTitle), ...seasonTitleStyles.text }}>
                                  <div className="font-bold tracking-wider leading-none text-center" style={{ fontSize: "min(12cqw, 90cqh)" }}>{sampleText}</div>
                               </div>
                            )}
                          </>
                        )}

                        {/* TITLE CARD TEXT */}
                        {previewType === 'TitleCard' && (
                          <>
                            {builderState.TitleCardEPText.AddEPText && (
                               <div className={`z-20 pointer-events-none transition-all ${selectedLayer === 'TitleCardEPText' ? 'border-2 border-dashed border-red-500/50 bg-red-500/5 ring-2 ring-theme-primary ring-inset' : ''}`} style={{ ...getBoundingBoxStyle(builderState.TitleCardEPText), ...tcEpStyles.text }}>
                                  <div className="font-medium leading-none text-center" style={{ fontSize: "min(10cqw, 90cqh)" }}>{builderState.TitleCardEPText.SeasonTCText} 1 {builderState.TitleCardEPText.EpisodeTCText} 1</div>
                               </div>
                            )}
                            {builderState.TitleCardEPTitle.AddEPTitleText && (
                               <div className={`z-20 pointer-events-none transition-all ${selectedLayer === 'TitleCardEPTitle' ? 'border-2 border-dashed border-red-500/50 bg-red-500/5 ring-2 ring-theme-primary ring-inset' : ''}`} style={{ ...getBoundingBoxStyle(builderState.TitleCardEPTitle), ...tcTitleStyles.text }}>
                                  <div className="font-bold tracking-wide leading-none text-center" style={{ fontSize: "min(10cqw, 90cqh)" }}>{sampleText}</div>
                               </div>
                            )}
                          </>
                        )}

                        {/* COLLECTION SPECIFIC TEXT */}
                        {previewType === 'Collection' && builderState.Collection.AddText && (
                          <>
                            {builderState.CollectionTitle.AddCollectionTitle && (
                               <div className={`z-20 pointer-events-none transition-all ${selectedLayer === 'CollectionTitle' ? 'border-2 border-dashed border-red-500/50 bg-red-500/5 ring-2 ring-theme-primary ring-inset' : ''}`} style={{ ...getBoundingBoxStyle(builderState.CollectionTitle), ...collectionTitleStyles.text }}>
                                  <div className="font-bold tracking-wider leading-none text-center" style={{ fontSize: "min(12cqw, 90cqh)" }}>{builderState.CollectionTitle.CollectionTitle}</div>
                               </div>
                            )}
                          </>
                        )}

                        {/* RESOLUTION OVERLAYS */}
                        {((previewType === 'Poster' && builderState.Poster.UseResolutionOverlays) ||
                         (previewType === 'Season' && builderState.Season.UseResolutionOverlays) ||
                         (previewType === 'Background' && builderState.Background.UseResolutionOverlays) ||
                         (previewType === 'TitleCard' && builderState.TitleCard.UseResolutionOverlays)) && (
                          <div className={`absolute top-0 right-0 z-30 m-0 pointer-events-none transition-all ${selectedLayer?.endsWith('.Resolution') ? 'ring-2 ring-theme-primary ring-inset' : ''}`}>
                            <div className="bg-gradient-to-l from-yellow-500 to-yellow-600 text-black font-black text-[10px] lg:text-xs px-3 py-1 lg:px-4 lg:py-1 rounded-bl-xl shadow-lg">4K ULTRA HD</div>
                          </div>
                        )}
                        </>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Right Column: Properties */}
            <div className="xl:col-span-3 space-y-4">
              <div className="bg-theme-bg/50 border border-theme rounded-xl p-4 shadow-sm h-full max-h-[800px] overflow-y-auto custom-scrollbar flex flex-col">
                <h3 className="font-bold text-theme-text border-b border-theme pb-3 mb-4 flex items-center gap-2">
                  <Sliders className="w-5 h-5 text-theme-primary" /> Properties
                </h3>

                <div className="flex-grow space-y-4">
                  {!selectedLayer && (
                    <div className="flex flex-col items-center justify-center h-40 text-theme-muted opacity-50">
                      <MousePointerClick className="w-8 h-8 mb-2" />
                      <p className="text-sm">Select a layer to edit</p>
                    </div>
                  )}

                  {selectedLayer === "Global" && (
                    <div className="space-y-4">
                      <Toggle label={t("blueprints.builder.enableProcessing", "Enable Processing")} checked={builderState.ImageProcessing} onChange={(v) => updateBuilder(null, "ImageProcessing", v)} />
                      <div className="border-t border-theme/50 my-2 pt-2"></div>
                      <Toggle label={t("blueprints.builder.useClearlogo", "Use Clearlogo")} checked={builderState.Global.UseClearlogo} onChange={(v) => updateBuilder("Global", "UseClearlogo", v)} />
                      <Toggle label={t("blueprints.builder.useClearart", "Use Clearart")} checked={builderState.Global.UseClearart} onChange={(v) => updateBuilder("Global", "UseClearart", v)} />
                      <Toggle label={t("blueprints.builder.flatWhiteLogo", "Flat White Logo")} checked={builderState.Global.FlatWhiteLogo} onChange={(v) => updateBuilder("Global", "FlatWhiteLogo", v)} />
                      <div className="border-t border-theme/50 my-2 pt-2"></div>
                      <Toggle label={t("blueprints.builder.onlyTextless", "Textless Artwork")} checked={builderState.Global.TextlessOnly} onChange={(v) => updateBuilder("Global", "TextlessOnly", v)} />
                    </div>
                  )}

                  {selectedLayer?.endsWith(".Border") && (
                    <div className="space-y-4">
                      <ColorInput label="Border Color" value={builderState[selectedLayer.split('.')[0]].bordercolor} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "bordercolor", v)} />
                      <NumberInput label="Border Width" value={builderState[selectedLayer.split('.')[0]].borderwidth} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "borderwidth", v)} />
                    </div>
                  )}

                  {selectedLayer?.endsWith(".Resolution") && (
                    <div className="space-y-4">
                      {previewType === 'Poster' || previewType === 'Season' || previewType === 'Collection' ? (
                         <>
                           <TextInput label="4K Overlay File" value={builderState.ResolutionOverlays.poster4k} onChange={(v) => updateBuilder("ResolutionOverlays", "poster4k", v)} />
                           <TextInput label="1080p Overlay File" value={builderState.ResolutionOverlays.Poster1080p} onChange={(v) => updateBuilder("ResolutionOverlays", "Poster1080p", v)} />
                           <TextInput label="4K DoVi Overlay File" value={builderState.ResolutionOverlays["4KDoVi"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KDoVi", v)} />
                           <TextInput label="4K HDR10 Overlay File" value={builderState.ResolutionOverlays["4KHDR10"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KHDR10", v)} />
                           <TextInput label="4K DoVi+HDR10 Overlay File" value={builderState.ResolutionOverlays["4KDoViHDR10"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KDoViHDR10", v)} />
                         </>
                      ) : previewType === 'Background' ? (
                         <>
                           <TextInput label="4K Overlay File" value={builderState.ResolutionOverlays.Background4k} onChange={(v) => updateBuilder("ResolutionOverlays", "Background4k", v)} />
                           <TextInput label="1080p Overlay File" value={builderState.ResolutionOverlays.Background1080p} onChange={(v) => updateBuilder("ResolutionOverlays", "Background1080p", v)} />
                           <TextInput label="4K DoVi Overlay File" value={builderState.ResolutionOverlays["4KDoViBackground"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KDoViBackground", v)} />
                           <TextInput label="4K HDR10 Overlay File" value={builderState.ResolutionOverlays["4KHDR10Background"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KHDR10Background", v)} />
                           <TextInput label="4K DoVi+HDR10 Overlay File" value={builderState.ResolutionOverlays["4KDoViHDR10Background"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KDoViHDR10Background", v)} />
                         </>
                      ) : (
                         <>
                           <TextInput label="4K Overlay File" value={builderState.ResolutionOverlays.TC4k} onChange={(v) => updateBuilder("ResolutionOverlays", "TC4k", v)} />
                           <TextInput label="1080p Overlay File" value={builderState.ResolutionOverlays.TC1080p} onChange={(v) => updateBuilder("ResolutionOverlays", "TC1080p", v)} />
                           <TextInput label="4K DoVi Overlay File" value={builderState.ResolutionOverlays["4KDoViTC"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KDoViTC", v)} />
                           <TextInput label="4K HDR10 Overlay File" value={builderState.ResolutionOverlays["4KHDR10TC"]} onChange={(v) => updateBuilder("ResolutionOverlays", "4KHDR10TC", v)} />
                         </>
                      )}
                    </div>
                  )}

                  {selectedLayer?.endsWith(".Overlay") && (
                    <div className="space-y-4">
                      <TextInput label="Overlay File" value={builderState[selectedLayer.split('.')[0]].overlayfile} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "overlayfile", v)} placeholder="backgroundoverlay-innerglow.png" />
                    </div>
                  )}

                  {selectedLayer === "TitleCard.Border" && (
                    <div className="space-y-4 border-t border-theme/50 pt-4">
                      <Toggle label="Use Background as Title Card" checked={builderState.TitleCard.UseBackgroundAsTitleCard} onChange={(v) => updateBuilder("TitleCard", "UseBackgroundAsTitleCard", v)} />
                      <Toggle label="Background Fallback" checked={builderState.TitleCard.BackgroundFallback} onChange={(v) => updateBuilder("TitleCard", "BackgroundFallback", v)} />
                    </div>
                  )}

                  {(selectedLayer?.endsWith(".Text") || selectedLayer === "TitleCardEPTitle" || selectedLayer === "TitleCardEPText" || selectedLayer === "SeasonTitle" || selectedLayer === "CollectionTitle") && (
                    <div className="space-y-4">
                        {selectedLayer === "SeasonTitle" && (
                          <Toggle label="Show Title" checked={builderState.SeasonTitle.ShowTitle} onChange={(v) => updateBuilder("SeasonTitle", "ShowTitle", v)} />
                        )}
                        <Toggle label="All Caps" checked={builderState[selectedLayer.split('.')[0]].fontAllCaps} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "fontAllCaps", v)} />
                        <Toggle label="Enable Stroke" checked={builderState[selectedLayer.split('.')[0]].AddTextStroke} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "AddTextStroke", v)} />

                        <ColorInput label="Text Color" value={builderState[selectedLayer.split('.')[0]].fontcolor} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "fontcolor", v)} />
                        {selectedLayer === "TitleCardEPText" && (
                          <>
                            <TextInput label="Season Text" value={builderState.TitleCardEPText.SeasonTCText} onChange={(v) => updateBuilder("TitleCardEPText", "SeasonTCText", v)} />
                            <TextInput label="Episode Text" value={builderState.TitleCardEPText.EpisodeTCText} onChange={(v) => updateBuilder("TitleCardEPText", "EpisodeTCText", v)} />
                          </>
                        )}
                        {builderState[selectedLayer.split('.')[0]].AddTextStroke && (
                          <>
                            <ColorInput label="Stroke Color" value={builderState[selectedLayer.split('.')[0]].strokecolor} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "strokecolor", v)} />
                            <NumberInput label="Stroke Width" value={builderState[selectedLayer.split('.')[0]].strokewidth} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "strokewidth", v)} />
                          </>
                        )}

                        <div className="grid grid-cols-2 gap-4">
                          <NumberInput label="Min Point Size" value={builderState[selectedLayer.split('.')[0]].minPointSize} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "minPointSize", parseInt(v))} />
                          <NumberInput label="Max Point Size" value={builderState[selectedLayer.split('.')[0]].maxPointSize} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "maxPointSize", parseInt(v))} />
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                          <NumberInput label="Max Width" value={builderState[selectedLayer.split('.')[0]].MaxWidth} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "MaxWidth", parseInt(v))} />
                          <NumberInput label="Max Height" value={builderState[selectedLayer.split('.')[0]].MaxHeight} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "MaxHeight", parseInt(v))} />
                        </div>

                        <NumberInput label="Line Spacing" value={builderState[selectedLayer.split('.')[0]].lineSpacing} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "lineSpacing", parseInt(v))} />

                        <SelectInput
                          label="Text Gravity"
                          value={builderState[selectedLayer.split('.')[0]].TextGravity}
                          onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "TextGravity", v)}
                          options={[
                            {label: "North", value: "north"}, {label: "South", value: "south"}, {label: "Center", value: "center"},
                            {label: "East", value: "east"}, {label: "West", value: "west"}, {label: "NorthWest", value: "northwest"},
                            {label: "NorthEast", value: "northeast"}, {label: "SouthWest", value: "southwest"}, {label: "SouthEast", value: "southeast"}
                          ]}
                        />
                        <TextInput label="Text Offset Y" value={builderState[selectedLayer.split('.')[0]].text_offset} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "text_offset", v)} placeholder="+400" />

                        {selectedLayer === "TitleCardEPText" && (
                          <div className="grid grid-cols-2 gap-4 border-t border-theme/50 pt-4 mt-4">
                             <TextInput label="Season Prefix" value={builderState.TitleCardEPText.SeasonTCText} onChange={(v) => updateBuilder("TitleCardEPText", "SeasonTCText", v)} placeholder="Season" />
                             <TextInput label="Episode Prefix" value={builderState.TitleCardEPText.EpisodeTCText} onChange={(v) => updateBuilder("TitleCardEPText", "EpisodeTCText", v)} placeholder="Episode" />
                          </div>
                        )}

                        {selectedLayer === "Season.Text" && (
                          <div className="space-y-4 border-t border-theme/50 pt-4 mt-4">
                             <Toggle label="Show Fallback Text" checked={builderState.Season.ShowFallback} onChange={(v) => updateBuilder("Season", "ShowFallback", v)} />
                             <Toggle label="Override Season Name" checked={builderState.Season.OverrideSeasonName} onChange={(v) => updateBuilder("Season", "OverrideSeasonName", v)} />
                             {builderState.Season.OverrideSeasonName && (
                               <div className="grid grid-cols-2 gap-4">
                                  <TextInput label="Season Override" value={builderState.Season.SeasonOverrideText} onChange={(v) => updateBuilder("Season", "SeasonOverrideText", v)} placeholder="Season" />
                                  <TextInput label="Special Season Override" value={builderState.Season.SpecialSeasonOverrideText} onChange={(v) => updateBuilder("Season", "SpecialSeasonOverrideText", v)} placeholder="Specials" />
                               </div>
                             )}
                          </div>
                        )}

                        {selectedLayer === "CollectionTitle" && (
                          <div className="space-y-4 border-t border-theme/50 pt-4 mt-4">
                             <TextInput label="Collection Title Prefix" value={builderState.CollectionTitle.CollectionTitle} onChange={(v) => updateBuilder("CollectionTitle", "CollectionTitle", v)} placeholder="Collection" />
                          </div>
                        )}
                    </div>
                  )}



                  {selectedLayer?.endsWith(".Resolution") && (
                    <div className="space-y-4">
                      <p className="text-sm text-theme-muted">Toggle resolution badges for 4K / 1080p etc.</p>
                      <Toggle label="Resolution Overlays" checked={builderState[selectedLayer.split('.')[0]].UseResolutionOverlays} onChange={(v) => updateBuilder(selectedLayer.split('.')[0], "UseResolutionOverlays", v)} />
                    </div>
                  )}
                </div>

                {/* Generate Button Fixed at Bottom of Panel */}
                <div className="mt-8 pt-4 border-t border-theme">
                  <button
                    onClick={handleSavePresetClick}
                    className="w-full flex justify-center items-center gap-2 bg-theme-primary text-white px-6 py-3 rounded-lg font-medium shadow-lg hover:bg-theme-primary/90 hover:shadow-theme-primary/30 transition-all disabled:opacity-50"
                  >
                    <Wand2 className="w-5 h-5" />
                    {t("blueprints.builder.savePreset", "Save as Preset")}
                  </button>
                </div>
              </div>
            </div>

          </div>
        )}
      </div>

      {/* Save Preset Modal */}
      {savePresetModalState && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-theme-card border border-theme rounded-xl shadow-2xl w-full max-w-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div className="p-6 border-b border-theme bg-theme-bg/50 flex justify-between items-center">
              <h2 className="text-2xl font-bold text-theme-text flex items-center gap-2">
                {savePresetModalState.isImport ? <Upload className="w-6 h-6 text-theme-primary" /> : <Save className="w-6 h-6 text-theme-primary" />}
                {savePresetModalState.isImport ? "Import & Save Custom Preset" : "Save Custom Preset"}
              </h2>
              <button onClick={() => setSavePresetModalState(null)} className="text-theme-muted hover:text-theme-text"><X className="w-6 h-6" /></button>
            </div>

            <div className="p-6 overflow-y-auto custom-scrollbar flex-grow space-y-6">
              <div className="space-y-4">
                <div className="flex flex-col gap-1">
                  <label className="text-sm font-medium text-theme-muted">Preset Title</label>
                  <input type="text" id="presetTitleInput" placeholder="e.g. Clean Poster Layout" className="bg-theme-bg border border-theme rounded-lg px-4 py-2 text-theme-text focus:border-theme-primary outline-none transition-colors" autoFocus />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-sm font-medium text-theme-muted">Description</label>
                  <textarea id="presetDescInput" placeholder="Describe what this preset does..." className="bg-theme-bg border border-theme rounded-lg px-4 py-2 text-theme-text focus:border-theme-primary outline-none transition-colors resize-none h-24" />
                </div>
              </div>

              <div className="bg-theme-bg/50 rounded-lg border border-theme p-4">
                <h3 className="font-semibold text-theme-text mb-4 border-b border-theme pb-2">Included Settings</h3>
                <ul className="space-y-2 text-xs">
                  {savePresetModalState.updates && Object.entries(savePresetModalState.updates).map(([section, fields]) => (
                    <li key={section} className="flex flex-col border-b border-theme/10 pb-2 last:border-0 last:pb-0">
                      <span className="text-theme-primary font-semibold mb-1">{section}</span>
                      <div className="grid grid-cols-2 gap-x-4 gap-y-1 pl-2 border-l-2 border-theme-primary/30">
                        {Object.entries(fields).map(([key, val]) => (
                          <div key={key} className="flex justify-between items-center gap-2">
                            <span className="text-theme-muted truncate" title={key}>{key}</span>
                            <span className="text-theme-text font-mono bg-theme-bg px-1.5 rounded truncate max-w-[100px]" title={String(val)}>{String(val)}</span>
                          </div>
                        ))}
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            </div>

            <div className="p-6 border-t border-theme bg-theme-bg/50 flex justify-end gap-3">
              <button
                onClick={() => setSavePresetModalState(null)}
                className="px-6 py-2.5 rounded-lg font-medium text-theme-text bg-theme-bg border border-theme hover:bg-theme-hover transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  const title = document.getElementById('presetTitleInput').value;
                  const desc = document.getElementById('presetDescInput').value;
                  if (title) saveCustomPreset(title, desc);
                }}
                className="px-6 py-2.5 rounded-lg font-medium text-white bg-theme-primary hover:bg-theme-primary/90 transition-colors shadow-lg flex items-center gap-2"
              >
                <Save className="w-5 h-5" /> Save Preset
              </button>
            </div>
          </div>
        </div>
      )}

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
