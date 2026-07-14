import React, { useState, useEffect } from "react";
import { Loader2 } from "lucide-react";
import { getPlexClientIdentifier, getPlexPin, pollPlexToken, buildPlexAuthUrl } from "../utils/plexAuth";

export default function PlexOAuthButton({ onTokenReceived, className, disabled }) {
    const [loading, setLoading] = useState(false);
    const [popupWindow, setPopupWindow] = useState(null);

    useEffect(() => {
        return () => {
            if (popupWindow && !popupWindow.closed) {
                popupWindow.close();
            }
        };
    }, [popupWindow]);

    const handlePlexAuth = async () => {
        try {
            setLoading(true);
            const clientId = getPlexClientIdentifier();
            const pinData = await getPlexPin(clientId);
            
            const authUrl = buildPlexAuthUrl(clientId, pinData.code);
            const popup = window.open(authUrl, "PlexAuth", "width=600,height=700");
            setPopupWindow(popup);

            const pollInterval = setInterval(async () => {
                try {
                    const tokenData = await pollPlexToken(pinData.id, clientId);
                    if (tokenData.authToken) {
                        clearInterval(pollInterval);
                        if (popup && !popup.closed) {
                            popup.close();
                        }
                        setPopupWindow(null);
                        setLoading(false);
                        onTokenReceived(tokenData.authToken);
                    } else if (popup && popup.closed) {
                        // User closed popup without signing in
                        clearInterval(pollInterval);
                        setPopupWindow(null);
                        setLoading(false);
                    }
                } catch (err) {
                    console.error("Error polling Plex token:", err);
                    clearInterval(pollInterval);
                    setLoading(false);
                }
            }, 2000);
        } catch (err) {
            console.error("Error initiating Plex OAuth:", err);
            setLoading(false);
        }
    };

    return (
        <button
            onClick={handlePlexAuth}
            disabled={loading || disabled}
            type="button"
            className={`flex items-center justify-center px-4 py-2.5 bg-[#E5A00D]/90 hover:bg-[#E5A00D] text-white font-semibold rounded-lg transition-colors ${(loading || disabled) ? 'opacity-70 cursor-not-allowed' : ''} ${className || ''}`}
            title="Sign in with Plex to get your token automatically"
        >
            {loading ? <Loader2 className="w-5 h-5 mr-2 animate-spin" /> : <img src="/plex.svg" alt="Plex" className="w-5 h-5 mr-2 object-contain" />}
            {loading ? "Waiting for Auth..." : "Sign in with Plex"}
        </button>
    );
}
