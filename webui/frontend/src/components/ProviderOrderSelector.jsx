import React, { useState, useEffect } from "react";
import { ChevronDown, GripVertical, Plus, X } from "lucide-react";
import { useTranslation } from "react-i18next";

// ISO 639-1 language codes with common languages
const AVAILABLE_PROVIDERS = [
  { code: "tmdb", name: "TMDB" },
  { code: "tvdb", name: "TVDB" },
  { code: "fanart", name: "Fanart.tv" },
  { code: "plex", name: "Plex" },
];

const ProviderOrderSelector = ({ value = [], onChange, label, helpText }) => {
  const { t } = useTranslation();
  const [selectedProviders, setSelectedProviders] = useState([]);
  const [draggedIndex, setDraggedIndex] = useState(null);
  const [dropdownOpen, setDropdownOpen] = useState(false);

  // Initialize from value prop
  useEffect(() => {
    if (Array.isArray(value) && value.length > 0) {
      setSelectedProviders(value);
    }
  }, [value]);

  // Get available languages (not yet selected)
  const availableProviders = AVAILABLE_PROVIDERS.filter(
    (lang) => !selectedProviders.includes(lang.code)
  );

  const addProvider = (providerCode) => {
    const newProviders = [...selectedProviders, providerCode];
    setSelectedProviders(newProviders);
    onChange(newProviders);
    setDropdownOpen(false);
  };

  const removeProvider = (providerCode) => {
    const newProviders = selectedProviders.filter((code) => code !== providerCode);
    setSelectedProviders(newProviders);
    onChange(newProviders);
  };

  const handleDragStart = (index) => {
    setDraggedIndex(index);
  };

  const handleDragOver = (e, index) => {
    e.preventDefault();
    if (draggedIndex === null || draggedIndex === index) return;

    const newProviders = [...selectedProviders];
    const draggedItem = newProviders[draggedIndex];
    newProviders.splice(draggedIndex, 1);
    newProviders.splice(index, 0, draggedItem);

    setSelectedProviders(newProviders);
    setDraggedIndex(index);
  };

  const handleDragEnd = () => {
    if (draggedIndex !== null) {
      onChange(selectedProviders);
    }
    setDraggedIndex(null);
  };

  const moveUp = (index) => {
    if (index === 0) return;
    const newProviders = [...selectedProviders];
    [newProviders[index - 1], newProviders[index]] = [
      newProviders[index],
      newProviders[index - 1],
    ];
    setSelectedProviders(newProviders);
    onChange(newProviders);
  };

  const moveDown = (index) => {
    if (index === selectedProviders.length - 1) return;
    const newProviders = [...selectedProviders];
    [newProviders[index], newProviders[index + 1]] = [
      newProviders[index + 1],
      newProviders[index],
    ];
    setSelectedProviders(newProviders);
    onChange(newProviders);
  };

  const getProviderName = (code) => {
    const lang = AVAILABLE_PROVIDERS.find((l) => l.code === code);
    return lang ? lang.name : code.toUpperCase();
  };

  return (
    <div className="space-y-3">
      {label && (
        <label className="block text-sm font-medium text-theme-text">
          {label}
        </label>
      )}

      {/* Selected Languages - Draggable List */}
      <div className="space-y-2">
        {selectedProviders.length === 0 ? (
          <div className="px-4 py-8 bg-theme-bg/50 border-2 border-dashed border-theme rounded-lg text-center">
            <p className="text-theme-muted text-sm">
              Select providers to determine the search priority.
            </p>
          </div>
        ) : (
          selectedProviders.map((providerCode, index) => (
            <div
              key={providerCode}
              draggable
              onDragStart={() => handleDragStart(index)}
              onDragOver={(e) => handleDragOver(e, index)}
              onDragEnd={handleDragEnd}
              className={`flex items-center gap-3 px-4 py-3 bg-theme-bg border border-theme rounded-lg hover:border-theme-primary/50 transition-all cursor-move ${
                draggedIndex === index ? "opacity-50" : ""
              }`}
            >
              {/* Drag Handle */}
              <GripVertical className="w-5 h-5 text-theme-muted flex-shrink-0" />

              {/* Priority Badge */}
              <div className="flex items-center justify-center w-8 h-8 bg-theme-primary/20 text-theme-primary rounded-full font-bold text-sm flex-shrink-0">
                {index + 1}
              </div>

              {/* Language Info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-sm text-theme-primary font-semibold">
                    {providerCode}
                  </span>
                  <span className="text-sm text-theme-muted">•</span>
                  <span className="text-sm text-theme-text truncate">
                    {getProviderName(providerCode)}
                  </span>
                </div>
              </div>

              {/* Arrow Buttons */}
              <div className="flex gap-1 flex-shrink-0">
                <button
                  onClick={() => moveUp(index)}
                  disabled={index === 0}
                  className={`p-1.5 rounded transition-all ${
                    index === 0
                      ? "text-theme-muted/30 cursor-not-allowed"
                      : "text-theme-muted hover:text-theme-primary hover:bg-theme-primary/10"
                  }`}
                  title={t("onboarding.providerOrderSelector.moveUp")}
                >
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M5 15l7-7 7 7"
                    />
                  </svg>
                </button>
                <button
                  onClick={() => moveDown(index)}
                  disabled={index === selectedProviders.length - 1}
                  className={`p-1.5 rounded transition-all ${
                    index === selectedProviders.length - 1
                      ? "text-theme-muted/30 cursor-not-allowed"
                      : "text-theme-muted hover:text-theme-primary hover:bg-theme-primary/10"
                  }`}
                  title={t("onboarding.providerOrderSelector.moveDown")}
                >
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                </button>
              </div>

              {/* Remove Button */}
              <button
                onClick={() => removeProvider(providerCode)}
                className="p-1.5 text-red-500 hover:bg-red-500/10 rounded transition-all flex-shrink-0"
                title={t("onboarding.providerOrderSelector.removeProvider")}
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          ))
        )}
      </div>

      {/* Add Language Dropdown */}
      {availableProviders.length > 0 && (
        <div className="relative">
          <button
            onClick={() => setDropdownOpen(!dropdownOpen)}
            className="w-full flex items-center justify-between gap-2 px-4 py-3 bg-theme-bg hover:bg-theme-hover border border-theme hover:border-theme-primary/50 rounded-lg text-theme-text text-sm font-medium transition-all shadow-sm"
          >
            <div className="flex items-center gap-2">
              <Plus className="w-4 h-4" />
              <span className="text-sm">
                {t("onboarding.providerOrderSelector.addProvider")}
              </span>
            </div>
            <ChevronDown
              className={`w-4 h-4 transition-transform ${
                dropdownOpen ? "rotate-180" : ""
              }`}
            />
          </button>

          {/* Dropdown Menu */}
          {dropdownOpen && (
            <>
              {/* Backdrop */}
              <div
                className="fixed inset-0 z-10"
                onClick={() => setDropdownOpen(false)}
              />

              {/* Dropdown Content */}
              <div
                className="absolute z-20 w-full mt-2 bg-theme-card border border-theme-primary rounded-lg shadow-xl max-h-64 overflow-y-auto"
                style={{ scrollbarWidth: "thin" }}
              >
                {availableProviders.map((lang) => (
                  <button
                    key={lang.code}
                    onClick={() => addProvider(lang.code)}
                    className="w-full flex items-center gap-3 px-4 py-3 hover:bg-theme-hover transition-all text-left border-b border-theme last:border-b-0"
                  >
                    <span className="font-mono text-sm text-theme-primary font-semibold w-8">
                      {lang.code}
                    </span>
                    <span className="text-sm text-theme-muted">•</span>
                    <span className="text-sm text-theme-text hover:text-theme-primary">
                      {lang.name}
                    </span>
                  </button>
                ))}
              </div>
            </>
          )}
        </div>
      )}

      {/* Help Text */}
      {helpText && <p className="text-xs text-theme-muted">{helpText}</p>}

      {/* Order Summary */}
      {selectedProviders.length > 0 && (
        <div className="px-4 py-3 bg-theme-bg/50 border border-theme rounded-lg">
          <p className="text-xs text-theme-muted mb-1">
            {t("onboarding.providerOrderSelector.currentOrder")}
          </p>
          <p className="text-sm font-mono text-theme-text">
            {selectedProviders.join(", ")}
          </p>
        </div>
      )}
    </div>
  );
};

export default ProviderOrderSelector;



