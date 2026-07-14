export const getPlexClientIdentifier = () => {
    let clientId = localStorage.getItem("plexClientIdentifier");
    if (!clientId) {
        if (typeof crypto !== 'undefined' && crypto.randomUUID) {
            clientId = crypto.randomUUID();
        } else if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
            // Secure fallback for slightly older browsers
            clientId = ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
                (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
            );
        } else {
            // Ultimate fallback (not recommended but necessary for extremely old/insecure contexts)
            clientId = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                var r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
        }
        localStorage.setItem("plexClientIdentifier", clientId);
    }
    return clientId;
};

let cachedVersion = null;

const getPlexHeaders = async (clientIdentifier) => {
    let os = "Unknown OS";
    if (typeof navigator !== 'undefined' && navigator.userAgent) {
        if (navigator.userAgent.indexOf("Win") !== -1) os = "Windows";
        else if (navigator.userAgent.indexOf("Mac") !== -1) os = "MacOS";
        else if (navigator.userAgent.indexOf("Linux") !== -1) os = "Linux";
        else if (navigator.userAgent.indexOf("Android") !== -1) os = "Android";
        else if (navigator.userAgent.indexOf("like Mac") !== -1) os = "iOS";
    }

    if (!cachedVersion) {
        try {
            const res = await fetch("/api/version");
            if (res.ok) {
                const data = await res.json();
                if (data.local) cachedVersion = data.local;
            }
        } catch (e) {
            console.error("Failed to fetch Posterizarr version for Plex headers", e);
        }
    }

    return {
        "Accept": "application/json",
        "X-Plex-Product": "Posterizarr",
        "X-Plex-Version": cachedVersion || "Unknown",
        "X-Plex-Client-Identifier": clientIdentifier,
        "X-Plex-Device": os,
        "X-Plex-Platform": "Web",
        "X-Plex-Device-Name": "Posterizarr WebUI"
    };
};

export const getPlexPin = async (clientIdentifier) => {
    const headers = await getPlexHeaders(clientIdentifier);
    const response = await fetch("https://plex.tv/api/v2/pins?strong=true", {
        method: "POST",
        headers: headers
    });
    if (!response.ok) throw new Error("Failed to get Plex PIN");
    return await response.json();
};

export const pollPlexToken = async (pinId, clientIdentifier) => {
    const headers = await getPlexHeaders(clientIdentifier);
    const response = await fetch(`https://plex.tv/api/v2/pins/${encodeURIComponent(pinId)}`, {
        headers: headers
    });
    if (!response.ok) throw new Error("Failed to poll Plex PIN");
    return await response.json();
};

export const buildPlexAuthUrl = (clientIdentifier, code) => {
    return `https://app.plex.tv/auth#?clientID=${encodeURIComponent(clientIdentifier)}&code=${encodeURIComponent(code)}&context[device][product]=Posterizarr&context[device][deviceName]=Posterizarr%20WebUI`;
};
