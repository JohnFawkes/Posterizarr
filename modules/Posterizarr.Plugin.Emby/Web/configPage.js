define(['loading', 'emby-input', 'emby-button', 'emby-checkbox'], function (loading) {
    'use strict';

    var pluginId = "e62d8560-6123-4567-89ab-cdef12345678";

    function loadConfig(view) {
        loading.show();

        ApiClient.getPluginConfiguration(pluginId).then(function (config) {
            view.querySelector('#txtAssetPath').value = config.AssetFolderPath || '';
            view.querySelector('#chkDebugMode').checked = config.EnableDebugMode || false;

            var chkUpdatePoster = view.querySelector('#chkUpdatePoster');
            var chkUpdateSeason = view.querySelector('#chkUpdateSeason');
            var chkUpdateTitlecard = view.querySelector('#chkUpdateTitlecard');
            var chkUpdateBackdrop = view.querySelector('#chkUpdateBackdrop');
            var chkUpdateThumbnail = view.querySelector('#chkUpdateThumbnail');

            if (chkUpdatePoster) chkUpdatePoster.checked = config.UpdatePoster !== false;
            if (chkUpdateSeason) chkUpdateSeason.checked = config.UpdateSeason !== false;
            if (chkUpdateTitlecard) chkUpdateTitlecard.checked = config.UpdateTitlecard !== false;
            if (chkUpdateBackdrop) chkUpdateBackdrop.checked = config.UpdateBackdrop !== false;
            if (chkUpdateThumbnail) chkUpdateThumbnail.checked = config.UpdateThumbnail || false;

            var chkRealtime = view.querySelector('#chkEnableRealtimeSync');
            if (chkRealtime) chkRealtime.checked = config.EnableRealtimeSync || false;
            var txtUrl = view.querySelector('#txtPosterizarrApiUrl');
            if (txtUrl) txtUrl.value = config.PosterizarrApiUrl || '';
            var txtKey = view.querySelector('#txtPosterizarrApiKey');
            if (txtKey) txtKey.value = config.PosterizarrApiKey || '';

            loading.hide();
        }).catch(function (err) {
            console.error('[Posterizarr] Error loading configuration:', err);
            loading.hide();
        });
    }

    function saveConfig(view) {
        loading.show();

        ApiClient.getPluginConfiguration(pluginId).then(function (config) {
            config.AssetFolderPath = view.querySelector('#txtAssetPath').value;
            config.EnableDebugMode = view.querySelector('#chkDebugMode').checked;

            var chkUpdatePoster = view.querySelector('#chkUpdatePoster');
            var chkUpdateSeason = view.querySelector('#chkUpdateSeason');
            var chkUpdateTitlecard = view.querySelector('#chkUpdateTitlecard');
            var chkUpdateBackdrop = view.querySelector('#chkUpdateBackdrop');
            var chkUpdateThumbnail = view.querySelector('#chkUpdateThumbnail');

            if (chkUpdatePoster) config.UpdatePoster = chkUpdatePoster.checked;
            if (chkUpdateSeason) config.UpdateSeason = chkUpdateSeason.checked;
            if (chkUpdateTitlecard) config.UpdateTitlecard = chkUpdateTitlecard.checked;
            if (chkUpdateBackdrop) config.UpdateBackdrop = chkUpdateBackdrop.checked;
            if (chkUpdateThumbnail) config.UpdateThumbnail = chkUpdateThumbnail.checked;

            var chkRealtime = view.querySelector('#chkEnableRealtimeSync');
            config.EnableRealtimeSync = chkRealtime ? chkRealtime.checked : false;
            var txtUrl = view.querySelector('#txtPosterizarrApiUrl');
            config.PosterizarrApiUrl = txtUrl ? (txtUrl.value || '').trim() : '';
            var txtKey = view.querySelector('#txtPosterizarrApiKey');
            config.PosterizarrApiKey = txtKey ? (txtKey.value || '').trim() : '';

            ApiClient.updatePluginConfiguration(pluginId, config).then(function (result) {
                Dashboard.processPluginConfigurationUpdateResult(result);
                loading.hide();
            }).catch(function (err) {
                console.error('[Posterizarr] Error saving configuration:', err);
                loading.hide();
            });
        });
    }

    return function (view) {
        view.addEventListener('viewshow', function () {
            loadConfig(view);
        });

        var btnTest = view.querySelector('#btnTestPosterizarr');
        var resultDiv = view.querySelector('#testConnectionResult');
        if (btnTest) {
            btnTest.addEventListener('click', function (e) {
                e.preventDefault();
                var rawUrl = (view.querySelector('#txtPosterizarrApiUrl').value || '').trim();
                var apiKey = (view.querySelector('#txtPosterizarrApiKey').value || '').trim();

                if (!rawUrl) {
                    if (resultDiv) {
                        resultDiv.textContent = 'Please enter a Posterizarr URL first.';
                        resultDiv.style.color = '#e5a00d';
                    }
                    return;
                }

                if (resultDiv) {
                    resultDiv.textContent = 'Testing connection to Posterizarr...';
                    resultDiv.style.color = '#aaa';
                }

                var probeUrl = rawUrl.replace(/\/+$/, '') + '/ws/events';
                var headers = {};
                if (apiKey) {
                    headers['X-API-Key'] = apiKey;
                }

                fetch(probeUrl, { method: 'GET', headers: headers })
                    .then(function (res) {
                        if (!resultDiv) return;
                        if (res.ok || res.status === 200) {
                            resultDiv.textContent = 'Connected! Posterizarr WebSocket event stream is active.';
                            resultDiv.style.color = '#52b788';
                        } else if (res.status === 404) {
                            resultDiv.textContent = 'Posterizarr is reachable, but /ws/events was not found (HTTP 404). Posterizarr may need to be updated to the latest dev build with WebSocket support.';
                            resultDiv.style.color = '#e5a00d';
                        } else if (res.status === 401 || res.status === 403) {
                            resultDiv.textContent = 'Authentication failed (HTTP ' + res.status + '). Please verify your API Key.';
                            resultDiv.style.color = '#e63946';
                        } else {
                            resultDiv.textContent = 'Posterizarr returned HTTP status ' + res.status;
                            resultDiv.style.color = '#e5a00d';
                        }
                    })
                    .catch(function (err) {
                        if (!resultDiv) return;
                        resultDiv.textContent = 'Cannot reach Posterizarr at ' + rawUrl + '. Ensure Posterizarr is running, port 8000 is open, and network is reachable.';
                        resultDiv.style.color = '#e63946';
                    });
            });
        }

        view.querySelector('#PosterizarrConfigForm').addEventListener('submit', function (e) {
            e.preventDefault();
            saveConfig(view);
            return false;
        });
    };
});
