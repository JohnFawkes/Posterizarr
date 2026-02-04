import React, { useState, useEffect } from "react";
import {
    Play,
    Trash2,
    RefreshCw,
    AlertCircle,
    CheckCircle2,
    Clock,
    FileImage,
    Link as LinkIcon,
    List
} from "lucide-react";
import { useTranslation } from "react-i18next";
import { useToast } from "../context/ToastContext";

const QueueView = () => {
    const { t } = useTranslation();
    const { showToast } = useToast();
    const [items, setItems] = useState([]);
    const [loading, setLoading] = useState(true);
    const [processing, setProcessing] = useState(false);
    const [showHelp, setShowHelp] = useState(true); // Default to showing help

    const fetchQueue = async () => {
        try {
            const response = await fetch("/api/queue");
            if (response.ok) {
                const data = await response.json();
                setItems(data);
            }
        } catch (error) {
            console.error("Failed to fetch queue:", error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchQueue();
        const interval = setInterval(fetchQueue, 5000);
        return () => clearInterval(interval);
    }, []);

    const handleRunQueue = async () => {
        setProcessing(true);
        try {
            const response = await fetch("/api/queue/run", { method: "POST" });
            if (response.ok) {
                showToast(t("queue.executionStarted"), "success");
                fetchQueue();
            } else {
                const data = await response.json();
                showToast(data.detail || t("queue.startFailed"), "error");
            }
        } catch (error) {
            showToast(t("queue.errorStarting"), "error");
        } finally {
            setProcessing(false);
        }
    };

    const handleClearQueue = async () => {
        if (!window.confirm(t("queue.confirmClear"))) return;

        try {
            const response = await fetch("/api/queue/clear", { method: "POST" });
            if (response.ok) {
                showToast(t("queue.cleared"), "success");
                fetchQueue();
            } else {
                showToast(t("queue.clearFailed"), "error");
            }
        } catch (error) {
            showToast(t("queue.errorClearing"), "error");
        }
    };

    const handleDeleteItem = async (id) => {
        try {
            const response = await fetch(`/api/queue/${id}`, { method: "DELETE" });
            if (response.ok) {
                showToast(t("queue.itemRemoved"), "success");
                setItems(items.filter(item => item.id !== id));
            } else {
                showToast(t("queue.removeFailed"), "error");
            }
        } catch (error) {
            showToast(t("queue.errorRemoving"), "error");
        }
    };

    const getStatusIcon = (status) => {
        switch (status) {
            case "completed": return <CheckCircle2 className="w-5 h-5 text-green-500" />;
            case "processing": return <RefreshCw className="w-5 h-5 text-blue-500 animate-spin" />;
            case "failed": return <AlertCircle className="w-5 h-5 text-red-500" />;
            default: return <Clock className="w-5 h-5 text-theme-muted" />;
        }
    };

    return (
        <div className="container mx-auto p-6 max-w-7xl animate-in fade-in duration-500">
            <div className="flex justify-between items-center mb-8">
                <div className="flex items-center gap-3">
                    <div className="p-3 bg-theme-primary/10 rounded-xl">
                        <List className="w-8 h-8 text-theme-primary" />
                    </div>
                    <div>
                        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-theme-primary via-purple-500 to-pink-500">
                            {t("queue.title")}
                        </h1>
                        <p className="text-theme-muted mt-1">{t("queue.description")}</p>
                    </div>
                </div>

                <div className="flex gap-3">
                    <button
                        onClick={fetchQueue}
                        className="p-2 rounded-lg bg-theme-card border border-theme hover:bg-theme-hover transition-colors"
                        title={t("queue.refresh")}
                    >
                        <RefreshCw className="w-5 h-5 text-theme-muted" />
                    </button>

                    <button
                        onClick={handleClearQueue}
                        disabled={items.length === 0}
                        className="flex items-center px-4 py-2 rounded-lg bg-red-500/10 text-red-500 hover:bg-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                        <Trash2 className="w-4 h-4 mr-2" />
                        {t("queue.clearQueue")}
                    </button>

                    <button
                        onClick={handleRunQueue}
                        disabled={processing || items.length === 0 || items.every(i => i.status === 'completed')}
                        className="flex items-center px-6 py-2 rounded-lg bg-theme-primary text-white hover:bg-theme-primary/90 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-theme-primary/20 transition-all hover:scale-105 active:scale-95"
                    >
                        {processing ? <RefreshCw className="w-4 h-4 mr-2 animate-spin" /> : <Play className="w-4 h-4 mr-2" />}
                        {processing ? t("queue.running") : t("queue.runQueue")}
                    </button>
                </div>
            </div>

            {/* How-To / Help Section */}
            {showHelp && (
                <div className="mb-8 p-6 bg-theme-hover/30 rounded-2xl border border-theme/50 relative">
                    <button
                        onClick={() => setShowHelp(false)}
                        className="absolute top-4 right-4 text-theme-muted hover:text-theme-text transition-colors"
                    >
                        ×
                    </button>
                    <h3 className="font-semibold text-lg mb-4 flex items-center gap-2">
                        <AlertCircle className="w-5 h-5 text-theme-primary" />
                        {t("queue.howTo.title")}
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                        <div className="flex flex-col gap-2">
                            <span className="text-xs font-bold text-theme-muted uppercase tracking-wider">Step 1</span>
                            <p className="text-sm opacity-90">{t("queue.howTo.step1")}</p>
                        </div>
                        <div className="flex flex-col gap-2">
                            <span className="text-xs font-bold text-theme-muted uppercase tracking-wider">Step 2</span>
                            <p className="text-sm opacity-90">{t("queue.howTo.step2")}</p>
                        </div>
                        <div className="flex flex-col gap-2">
                            <span className="text-xs font-bold text-theme-muted uppercase tracking-wider">Step 3</span>
                            <p className="text-sm opacity-90">{t("queue.howTo.step3")}</p>
                        </div>
                        <div className="flex flex-col gap-2">
                            <span className="text-xs font-bold text-theme-muted uppercase tracking-wider">Step 4</span>
                            <p className="text-sm opacity-90">{t("queue.howTo.step4")}</p>
                        </div>
                    </div>
                </div>
            )}

            <div className="bg-theme-card rounded-2xl border border-theme shadow-xl overflow-hidden">
                {loading ? (
                    <div className="p-12 text-center text-theme-muted">
                        <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-4 opacity-50" />
                        <p>{t("queue.loading")}</p>
                    </div>
                ) : items.length === 0 ? (
                    <div className="p-16 text-center text-theme-muted">
                        <div className="w-16 h-16 bg-theme-hover rounded-full flex items-center justify-center mx-auto mb-4 opacity-50">
                            <List className="w-8 h-8" />
                        </div>
                        <p className="text-lg font-medium">{t("queue.emptyTitle")}</p>
                        <p className="text-sm mt-2 opacity-70 max-w-md mx-auto">
                            {t("queue.emptyDescription")}
                        </p>
                    </div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-left">
                            <thead>
                                <tr className="bg-theme-hover/30 border-b border-theme/50">
                                    <th className="px-4 py-4 font-semibold text-theme-muted text-sm w-[120px]">{t("queue.status")}</th>
                                    <th className="px-4 py-4 font-semibold text-theme-muted text-sm w-[100px]">{t("queue.type")}</th>
                                    <th className="px-4 py-4 font-semibold text-theme-muted text-sm w-[140px]">{t("queue.assetType")}</th>
                                    <th className="px-4 py-4 font-semibold text-theme-muted text-sm">{t("queue.assetPath")}</th>
                                    <th className="px-4 py-4 font-semibold text-theme-muted text-sm">{t("queue.details")}</th>
                                    <th className="px-4 py-4 font-semibold text-theme-muted text-sm text-right w-[80px]">{t("queue.actions")}</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-theme/30">
                                {items.map((item) => {
                                    const assetType = item.overlay_params?.asset_type?.toLowerCase() ||
                                        (item.overlay_params?.season_number ? "season" :
                                            (item.overlay_params?.episode_number ? "titlecard" : "poster"));

                                    const getAssetTypeStyles = (type) => {
                                        switch (type) {
                                            case 'titlecard': return "bg-purple-500/10 text-purple-400 border-purple-500/20";
                                            case 'season': return "bg-green-500/10 text-green-400 border-green-500/20";
                                            case 'background': return "bg-orange-500/10 text-orange-400 border-orange-500/20";
                                            default: return "bg-blue-500/10 text-blue-400 border-blue-500/20";
                                        }
                                    };

                                    return (
                                        <tr key={item.id} className="group hover:bg-theme-hover/20 transition-colors">
                                            <td className="px-4 py-4">
                                                <div className="flex items-center gap-2">
                                                    {getStatusIcon(item.status)}
                                                    <span className="capitalize text-sm font-medium opacity-80">{item.status}</span>
                                                </div>
                                                {item.error_message && (
                                                    <p className="text-xs text-red-400 mt-1 max-w-[200px] truncate" title={item.error_message}>
                                                        {item.error_message}
                                                    </p>
                                                )}
                                            </td>
                                            <td className="px-4 py-4">
                                                <div className="flex items-center gap-2 text-sm">
                                                    {item.source_type === 'url' ? <LinkIcon className="w-4 h-4 text-theme-muted opacity-70" /> : <FileImage className="w-4 h-4 text-theme-muted opacity-70" />}
                                                    <span className="capitalize text-theme-muted opacity-70">{item.source_type}</span>
                                                </div>
                                            </td>
                                            <td className="px-4 py-4">
                                                <span className={`text-xs px-2.5 py-1 rounded-full border font-medium capitalize flex w-fit items-center gap-1.5 ${getAssetTypeStyles(assetType)}`}>
                                                    <span className="w-1.5 h-1.5 rounded-full bg-current opacity-60"></span>
                                                    {assetType === 'titlecard' ? 'Title Card' : assetType}
                                                </span>
                                            </td>
                                            <td className="px-4 py-4">
                                                <span className="font-mono text-xs bg-black/20 px-2 py-1 rounded text-theme-text opacity-90 block max-w-[300px] truncate" title={item.asset_path}>
                                                    {item.asset_path}
                                                </span>
                                            </td>
                                            <td className="px-4 py-4 text-sm text-theme-muted">
                                                <div className="flex flex-col gap-1">
                                                    {item.overlay_params?.title_text && (
                                                        <span className="text-theme-text opacity-90 font-medium">{item.overlay_params.title_text}</span>
                                                    )}
                                                    <div className="flex gap-2 text-xs opacity-70">
                                                        {item.overlay_params?.process_with_overlays && (
                                                            <span className="bg-theme-primary/10 text-theme-primary px-1.5 py-0.5 rounded border border-theme-primary/10">{t("queue.overlays")}</span>
                                                        )}
                                                        <span>{new Date(item.created_at).toLocaleString()}</span>
                                                    </div>
                                                </div>
                                            </td>
                                            <td className="px-4 py-4 text-right">
                                                <button
                                                    onClick={() => handleDeleteItem(item.id)}
                                                    className="p-2 text-theme-muted hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors opacity-0 group-hover:opacity-100"
                                                    title={t("queue.removeFromQueue")}
                                                >
                                                    <Trash2 className="w-4 h-4" />
                                                </button>
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>
        </div>
    );
};

export default QueueView;
