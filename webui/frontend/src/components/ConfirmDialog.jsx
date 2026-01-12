import React, { useState } from "react";
import { AlertCircle } from "lucide-react";
import { useTranslation } from "react-i18next";

const ConfirmDialog = ({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  itemName,
  confirmText,
  cancelText,
  type = "danger",
}) => {
  const { t } = useTranslation();
  const [dontShowAgain, setDontShowAgain] = useState(false);

  if (!isOpen) return null;

  const handleConfirm = () => {
    // Pass the checkbox value back to the parent function
    onConfirm(dontShowAgain);
    onClose();
  };

  const buttonColors = {
    danger: "bg-red-500 hover:bg-red-600",
    warning: "bg-yellow-500 hover:bg-yellow-600",
    info: "bg-blue-500 hover:bg-blue-600",
  };

  return (
    <div
      className="fixed inset-0 bg-black/80 flex items-center justify-center z-[60] p-4 animate-fadeIn"
      onClick={onClose}
    >
      <div
        className="bg-theme-card border border-theme rounded-lg max-w-md w-full p-6 animate-scaleIn"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start gap-4 mb-4">
          <div
            className={`w-12 h-12 ${
              type === "danger" ? "bg-red-500/10" : "bg-blue-500/10"
            } rounded-full flex items-center justify-center flex-shrink-0`}
          >
            <AlertCircle
              className={`w-6 h-6 ${
                type === "danger" ? "text-red-500" : "text-blue-500"
              }`}
            />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-theme-text mb-2">
              {title || t("confirmDialog.title")}
            </h3>
            {message && (
              <p className="text-theme-muted text-sm mb-1">{message}</p>
            )}

            {/* New Checkbox UI */}
            <label className="flex items-center gap-2 mt-4 cursor-pointer group">
              <input
                type="checkbox"
                checked={dontShowAgain}
                onChange={(e) => setDontShowAgain(e.target.checked)}
                className="w-4 h-4 rounded border-theme bg-theme-bg text-theme-primary focus:ring-theme-primary"
              />
              <span className="text-sm text-theme-muted group-hover:text-theme-text transition-colors">
                {t("assetReplacer.dontShowAgain") || "Do not show this message again"}
              </span>
            </label>
          </div>
        </div>

        <div className="flex gap-3 justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-theme-hover hover:bg-theme-dark text-theme-text rounded-lg transition-colors"
          >
            {cancelText || t("confirmDialog.cancel")}
          </button>
          <button
            onClick={handleConfirm}
            className={`px-4 py-2 ${buttonColors[type] || buttonColors.danger} text-white rounded-lg transition-colors`}
          >
            {confirmText || t("confirmDialog.confirm")}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmDialog;