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

export const getPlexPin = async (clientIdentifier) => {
    const response = await fetch("https://plex.tv/api/v2/pins?strong=true", {
        method: "POST",
        headers: {
            "Accept": "application/json",
            "X-Plex-Product": "Posterizarr",
            "X-Plex-Client-Identifier": clientIdentifier
        }
    });
    if (!response.ok) throw new Error("Failed to get Plex PIN");
    return await response.json();
};

export const pollPlexToken = async (pinId, clientIdentifier) => {
    const response = await fetch(`https://plex.tv/api/v2/pins/${encodeURIComponent(pinId)}`, {
        headers: {
            "Accept": "application/json",
            "X-Plex-Client-Identifier": clientIdentifier
        }
    });
    if (!response.ok) throw new Error("Failed to poll Plex PIN");
    return await response.json();
};

export const buildPlexAuthUrl = (clientIdentifier, code) => {
    return `https://app.plex.tv/auth#?clientID=${encodeURIComponent(clientIdentifier)}&code=${encodeURIComponent(code)}&context[device][product]=Posterizarr`;
};
