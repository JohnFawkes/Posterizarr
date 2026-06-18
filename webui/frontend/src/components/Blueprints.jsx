import React, { useState, useEffect, useRef } from "react";
import { Loader2, Palette, Image, Layers, CheckCircle2, AlertCircle, Type, Square, Languages, Sparkles, Download, Upload } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useToast } from "../context/ToastContext";

const API_URL = "/api";

const BLUEPRINTS = [
  {
    id: "clearlogo-instead-of-text",
    title: "Logo (Clearlogo)",
    description: "Replaces standard text with the movie/show clearlogo.",
    icon: Image,
    images: ["/blueprint-previews/clearlogo-instead-of-text_poster.png", "/blueprint-previews/clearlogo-instead-of-text_background.png"],
    updates: {
      flat: {
        UseLogo: "true",
        UseBGLogo: "true",
        UseClearlogo: "true",
        UseClearart: "false",
        ConvertLogoColor: "false",
        PosterAddText: "true",
        BackgroundAddText: "true"
      },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "true", UseClearart: "false", ConvertLogoColor: "false" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "clearart-instead-of-text",
    title: "Logo (Clearart)",
    description: "Replaces standard text with the movie/show clearart.",
    icon: Image,
    images: ["/blueprint-previews/clearart-instead-of-text_poster.png", "/blueprint-previews/clearart-instead-of-text_background.png"],
    updates: {
      flat: {
        UseLogo: "true",
        UseBGLogo: "true",
        UseClearlogo: "false",
        UseClearart: "true",
        ConvertLogoColor: "false",
        PosterAddText: "true",
        BackgroundAddText: "true"
      },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "false", UseClearart: "true", ConvertLogoColor: "false" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "flat-clearlogo-instead-of-text",
    title: "Flat White Logo (Clearlogo)",
    description: "Replaces standard text with a clearlogo converted to a flat white color for better contrast.",
    icon: Image,
    images: ["/blueprint-previews/flat-clearlogo-instead-of-text_poster.png", "/blueprint-previews/flat-clearlogo-instead-of-text_background.png"],
    updates: {
      flat: {
        UseLogo: "true",
        UseBGLogo: "true",
        UseClearlogo: "true",
        UseClearart: "false",
        ConvertLogoColor: "true",
        LogoFlatColor: "white",
        PosterAddText: "true",
        BackgroundAddText: "true"
      },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "true", UseClearart: "false", ConvertLogoColor: "true", LogoFlatColor: "white" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "flat-clearart-instead-of-text",
    title: "Flat White Logo (Clearart)",
    description: "Replaces standard text with a clearart converted to a flat white color for better contrast.",
    icon: Image,
    images: ["/blueprint-previews/flat-clearart-instead-of-text_poster.png", "/blueprint-previews/flat-clearart-instead-of-text_background.png"],
    updates: {
      flat: {
        UseLogo: "true",
        UseBGLogo: "true",
        UseClearlogo: "false",
        UseClearart: "true",
        ConvertLogoColor: "true",
        LogoFlatColor: "white",
        PosterAddText: "true",
        BackgroundAddText: "true"
      },
      nested: {
        PrerequisitePart: { UseLogo: "true", UseBGLogo: "true", UseClearlogo: "false", UseClearart: "true", ConvertLogoColor: "true", LogoFlatColor: "white" },
        PosterOverlayPart: { AddText: "true" },
        BackgroundOverlayPart: { AddText: "true" }
      }
    }
  },
  {
    id: "show-title-on-season",
    title: "Show Title on Season",
    description: "Adds the show title (or logo if logo settings are enabled) to season posters alongside the season text.",
    icon: Type,
    images: ["/blueprint-previews/show-title-on-season.png"],
    updates: {
      flat: {
        ShowTitleAddShowTitletoSeason: "true"
      },
      nested: {
        ShowTitleOnSeasonPosterPart: { AddShowTitletoSeason: "true" }
      }
    }
  },
  {
    id: "minimalist-posters",
    title: "Minimalist Posters",
    description: "Disables image processing entirely. Only the raw poster gets downloaded and moved to the asset directory.",
    icon: Palette,
    images: ["/blueprint-previews/minimalist-posters_en.png", "/blueprint-previews/minimalist-posters_textless.png", "/blueprint-previews/minimalist-posters_textless_background.png"],
    updates: {
      flat: {
        ImageProcessing: "false"
      },
      nested: {
        OverlayPart: { ImageProcessing: "false" }
      }
    }
  },
  {
    id: "full-overlays",
    title: "Enable All Overlays",
    description: "Enables borders, text, and overlays across all standard posters, season posters, backgrounds, and title cards.",
    icon: Layers,
    images: ["/blueprint-previews/full-overlays.png", "/blueprint-previews/full-overlays_background-small.png"],
    updates: {
      flat: {
        PosterAddBorder: "true",
        PosterAddText: "true",
        PosterAddOverlay: "true",
        SeasonPosterAddBorder: "true",
        SeasonPosterAddText: "true",
        SeasonPosterAddOverlay: "true",
        BackgroundAddBorder: "true",
        BackgroundAddText: "true",
        BackgroundAddOverlay: "true",
        TitleCardAddOverlay: "true",
        TitleCardAddBorder: "true",
        TitleCardTitleAddEPTitleText: "true",
        TitleCardEPAddEPText: "true"
      },
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
    id: "only-borders",
    title: "Only Borders",
    description: "Disables text and overlays, rendering only borders across all posters and cards.",
    icon: Square,
    images: ["/blueprint-previews/only-borders.png", "/blueprint-previews/only-borders_background.png"],
    updates: {
      flat: {
        PosterAddBorder: "true", PosterAddText: "false", PosterAddOverlay: "false",
        SeasonPosterAddBorder: "true", SeasonPosterAddText: "false", SeasonPosterAddOverlay: "false", ShowTitleAddShowTitletoSeason: "false",
        BackgroundAddBorder: "true", BackgroundAddText: "false", BackgroundAddOverlay: "false",
        TitleCardAddBorder: "true", TitleCardAddOverlay: "false", TitleCardTitleAddEPTitleText: "false", TitleCardEPAddEPText: "false"
      },
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
    title: "Only Text",
    description: "Disables borders and overlays, rendering only text (or logos) across all posters and cards.",
    icon: Type,
    images: ["/blueprint-previews/only-text.png", "/blueprint-previews/only-text_background.png"],
    updates: {
      flat: {
        PosterAddBorder: "false", PosterAddText: "true", PosterAddOverlay: "false",
        SeasonPosterAddBorder: "false", SeasonPosterAddText: "true", SeasonPosterAddOverlay: "false", ShowTitleAddShowTitletoSeason: "true",
        BackgroundAddBorder: "false", BackgroundAddText: "true", BackgroundAddOverlay: "false",
        TitleCardAddBorder: "false", TitleCardAddOverlay: "false", TitleCardTitleAddEPTitleText: "true", TitleCardEPAddEPText: "true"
      },
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
    title: "Only Overlays",
    description: "Disables text and borders, rendering only resolution/rating overlays across all posters and cards.",
    icon: Layers,
    images: ["/blueprint-previews/only-overlays.png", "/blueprint-previews/only-overlays_background.png"],
    updates: {
      flat: {
        PosterAddBorder: "false", PosterAddText: "false", PosterAddOverlay: "true",
        SeasonPosterAddBorder: "false", SeasonPosterAddText: "false", SeasonPosterAddOverlay: "true", ShowTitleAddShowTitletoSeason: "false",
        BackgroundAddBorder: "false", BackgroundAddText: "false", BackgroundAddOverlay: "true",
        TitleCardAddBorder: "false", TitleCardAddOverlay: "true", TitleCardTitleAddEPTitleText: "false", TitleCardEPAddEPText: "false"
      },
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
    title: "Textless Posters Only",
    description: "Configures language orders to 'xx' to ensure only textless artwork is downloaded. Skips artwork with text.",
    icon: Languages,
    images: ["/blueprint-previews/minimalist-posters_textless.png", "/blueprint-previews/minimalist-posters_textless_background.png"],
    updates: {
      flat: {
        PreferredLanguageOrder: ["xx"],
        PreferredSeasonLanguageOrder: ["xx"],
        PreferredBackgroundLanguageOrder: ["xx"],
        PreferredTCLanguageOrder: ["xx"]
      },
      nested: {
        ApiPart: {
          PreferredLanguageOrder: ["xx"],
          PreferredSeasonLanguageOrder: ["xx"],
          PreferredBackgroundLanguageOrder: ["xx"],
          PreferredTCLanguageOrder: ["xx"]
        }
      }
    }
  }
];

export default function Blueprints() {
  const { t } = useTranslation();
  const { showSuccess, showError } = useToast();
  const fileInputRef = useRef(null);

  const [config, setConfig] = useState(null);
  const [usingFlatStructure, setUsingFlatStructure] = useState(false);
  const [loading, setLoading] = useState(true);
  const [applyingId, setApplyingId] = useState(null);
  const [error, setError] = useState(null);

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
        showSuccess(`Blueprint "${blueprint.title}" applied successfully!`);
      } else {
        showError("Failed to apply blueprint configuration");
      }
    } catch (err) {
      showError(`Error applying blueprint: ${err.message}`);
    } finally {
      setApplyingId(null);
    }
  };

  const [isImporting, setIsImporting] = useState(false);

  const handleExportBlueprint = () => {
    // We now just trigger a download directly from the backend which handles scrubbing the grouped config.
    const downloadAnchorNode = document.createElement('a');
    downloadAnchorNode.setAttribute("href", `${API_URL}/config/export`);
    downloadAnchorNode.setAttribute("download", "custom_blueprint.json");
    document.body.appendChild(downloadAnchorNode);
    downloadAnchorNode.click();
    downloadAnchorNode.remove();
  };

  const handleImportClick = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleFileChange = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    setIsImporting(true);
    
    try {
      const text = await file.text();
      const importedConfig = JSON.parse(text);

      // The backend handles backup, deep merging the grouped config, and saving it
      const response = await fetch(`${API_URL}/config/import`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: text,
      });

      const data = await response.json();
      if (data.success) {
        showSuccess("Custom blueprint imported successfully and a backup was created!");
        fetchConfig(); // Reload the UI config state from the newly saved config
      } else {
        showError("Failed to apply imported configuration: " + data.message);
      }
    } catch (err) {
      showError(`Error importing blueprint: ${err.message}`);
    } finally {
      setIsImporting(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = ""; // Reset input
      }
    }
  };

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
        <button
          onClick={fetchConfig}
          className="px-6 py-2.5 bg-red-600 hover:bg-red-700 rounded-lg font-medium transition-all shadow-lg"
        >
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-theme-card border border-theme rounded-xl p-6 shadow-sm">
        <div className="mb-6 pb-4 border-b border-theme flex flex-col md:flex-row md:items-start justify-between gap-4">
          <div>
            <h2 className="text-2xl font-bold text-theme-text flex items-center gap-3">
              <Layers className="w-7 h-7 text-theme-primary" />
              Config Blueprints
            </h2>
            <p className="text-theme-muted mt-2">
              Quickly apply pre-defined configurations to achieve specific visual styles. Applying a blueprint will instantly update your settings.
            </p>
          </div>
          <div className="flex gap-3 shrink-0">
            <button
              onClick={handleExportBlueprint}
              className="flex items-center gap-2 px-4 py-2 bg-theme-bg/50 border border-theme hover:border-theme-primary/50 text-theme-text rounded-lg transition-all"
              title="Export Current Config as Blueprint"
            >
              <Download className="w-4 h-4 text-theme-primary" />
              <span>Export</span>
            </button>
            <input 
              type="file" 
              accept=".json" 
              ref={fileInputRef} 
              onChange={handleFileChange} 
              className="hidden" 
            />
            <button
              onClick={handleImportClick}
              disabled={isImporting}
              className="flex items-center gap-2 px-4 py-2 bg-theme-primary/10 hover:bg-theme-primary/20 border border-theme-primary/30 text-theme-primary rounded-lg transition-all disabled:opacity-50"
              title="Import Custom Blueprint"
            >
              {isImporting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Upload className="w-4 h-4" />}
              <span>{isImporting ? "Importing..." : "Import"}</span>
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {BLUEPRINTS.map((blueprint) => {
            const Icon = blueprint.icon;
            const isApplying = applyingId === blueprint.id;

            return (
              <div
                key={blueprint.id}
                className="bg-theme-bg/50 border border-theme rounded-xl p-5 hover:border-theme-primary/50 transition-all flex flex-col h-full group shadow-md hover:shadow-lg"
              >
                <div className="flex items-start gap-4 mb-4">
                  <div className="p-3 bg-theme-primary/10 rounded-xl text-theme-primary group-hover:scale-110 transition-transform">
                    <Icon className="w-6 h-6" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-theme-text">{blueprint.title}</h3>
                  </div>
                </div>

                {blueprint.images && blueprint.images.length > 0 && (
                  <div className="flex gap-2 mb-4 overflow-x-auto pb-2 custom-scrollbar items-center">
                    {blueprint.images.map((img, idx) => (
                      <img key={idx} src={img} alt={`${blueprint.title} preview ${idx + 1}`} className="h-32 object-contain rounded-md bg-black/20 shrink-0 border border-theme/50 shadow-sm" />
                    ))}
                  </div>
                )}

                <p className="text-sm text-theme-muted flex-grow mb-6">
                  {blueprint.description}
                </p>

                <button
                  onClick={() => handleApplyBlueprint(blueprint)}
                  disabled={applyingId !== null}
                  className="w-full flex items-center justify-center gap-2 py-2.5 bg-theme-primary/10 hover:bg-theme-primary/20 text-theme-primary border border-theme-primary/30 rounded-lg font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isApplying ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    <CheckCircle2 className="w-5 h-5" />
                  )}
                  <span>{isApplying ? "Applying..." : "Apply Blueprint"}</span>
                </button>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
