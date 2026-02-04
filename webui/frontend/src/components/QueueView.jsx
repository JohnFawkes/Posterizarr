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
                showToast("Queue execution started", "success");
                fetchQueue();
            } else {
                const data = await response.json();
                showToast(data.detail || "Failed to start queue", "error");
            }
        } catch (error) {
            showToast("Error starting queue", "error");
        } finally {
            setProcessing(false);
        }
    };

    const handleClearQueue = async () => {
        if (!window.confirm("Are you sure you want to clear the entire queue?")) return;

        try {
            const response = await fetch("/api/queue/clear", { method: "POST" });
            if (response.ok) {
                showToast("Queue cleared", "success");
                fetchQueue();
            } else {
                showToast("Failed to clear queue", "error");
            }
        } catch (error) {
            showToast("Error clearing queue", "error");
        }
    };

    const handleDeleteItem = async (id) => {
        try {
            const response = await fetch(`/api/queue/${id}`, { method: "DELETE" });
            if (response.ok) {
                showToast("Item removed from queue", "success");
                setItems(items.filter(item => item.id !== id));
            } else {
                showToast("Failed to remove item", "error");
            }
        } catch (error) {
            showToast("Error removing item", "error");
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
                            Asset Queue
                        </h1>
                        <p className="text-theme-muted mt-1">Manage pending asset replacements</p>
                    </div>
                </div>

                <div className="flex gap-3">
                    <button
                        onClick={fetchQueue}
                        className="p-2 rounded-lg bg-theme-card border border-theme hover:bg-theme-hover transition-colors"
                        title="Refresh"
                    >
                        <RefreshCw className="w-5 h-5 text-theme-muted" />
                    </button>

                    <button
                        onClick={handleClearQueue}
                        disabled={items.length === 0}
                        className="flex items-center px-4 py-2 rounded-lg bg-red-500/10 text-red-500 hover:bg-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                        <Trash2 className="w-4 h-4 mr-2" />
                        Clear Queue
                    </button>

                    <button
                        onClick={handleRunQueue}
                        disabled={processing || items.length === 0 || items.every(i => i.status === 'completed')}
                        className="flex items-center px-6 py-2 rounded-lg bg-theme-primary text-white hover:bg-theme-primary/90 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-theme-primary/20 transition-all hover:scale-105 active:scale-95"
                    >
                        {processing ? <RefreshCw className="w-4 h-4 mr-2 animate-spin" /> : <Play className="w-4 h-4 mr-2" />}
                        {processing ? "Starting..." : "Run Queue"}
                    </button>
                </div>
            </div>

            <div className="bg-theme-card rounded-2xl border border-theme shadow-xl overflow-hidden">
                {loading ? (
                    <div className="p-12 text-center text-theme-muted">
                        <RefreshCw className="w-8 h-8 animate-spin mx-auto mb-4 opacity-50" />
                        <p>Loading queue...</p>
                    </div>
                ) : items.length === 0 ? (
                    <div className="p-16 text-center text-theme-muted">
                        <div className="w-16 h-16 bg-theme-hover rounded-full flex items-center justify-center mx-auto mb-4 opacity-50">
                            <List className="w-8 h-8" />
                        </div>
                        <p className="text-lg font-medium">Queue is empty</p>
                        <p className="text-sm mt-2 opacity-70">Add items from the Manual or Replace modes</p>
                    </div>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full text-left">
                            <thead>
                                <tr className="bg-theme-hover/30 border-b border-theme/50">
                                    <th className="px-6 py-4 font-semibold text-theme-muted text-sm">Status</th>
                                    <th className="px-6 py-4 font-semibold text-theme-muted text-sm">Type</th>
                                    <th className="px-6 py-4 font-semibold text-theme-muted text-sm">Asset Path</th>
                                    <th className="px-6 py-4 font-semibold text-theme-muted text-sm">Details</th>
                                    <th className="px-6 py-4 font-semibold text-theme-muted text-sm text-right">Actions</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-theme/30">
                                {items.map((item) => (
                                    <tr key={item.id} className="group hover:bg-theme-hover/20 transition-colors">
                                        <td className="px-6 py-4">
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
                                        <td className="px-6 py-4">
                                            <div className="flex items-center gap-2 text-sm">
                                                {item.source_type === 'url' ? <LinkIcon className="w-4 h-4 text-blue-400" /> : <FileImage className="w-4 h-4 text-purple-400" />}
                                                <span className="capitalize">{item.source_type}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className="font-mono text-xs bg-black/20 px-2 py-1 rounded text-theme-text opacity-90 block max-w-[300px] truncate" title={item.asset_path}>
                                                {item.asset_path}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-sm text-theme-muted">
                                            <div className="flex flex-col gap-1">
                                                {item.overlay_params?.title_text && (
                                                    <span className="text-theme-text opacity-90">{item.overlay_params.title_text}</span>
                                                )}
                                                <div className="flex gap-2 text-xs opacity-70">
                                                    {item.overlay_params?.process_with_overlays && (
                                                        <span className="bg-theme-primary/20 text-theme-primary px-1.5 py-0.5 rounded">Overlays</span>
                                                    )}
                                                    <span>{new Date(item.created_at).toLocaleString()}</span>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-right">
                                            <button
                                                onClick={() => handleDeleteItem(item.id)}
                                                className="p-2 text-theme-muted hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-colors opacity-0 group-hover:opacity-100"
                                                title="Remove from queue"
                                            >
                                                <Trash2 className="w-4 h-4" />
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>
        </div>
    );
};

export default QueueView;
