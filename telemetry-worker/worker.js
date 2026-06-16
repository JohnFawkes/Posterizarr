const DEFAULT_PASSWORD = "";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const password = env.DASHBOARD_PASSWORD || DEFAULT_PASSWORD;

    if (url.pathname === "/favicon.ico") {
      return new Response(null, { status: 204 });
    }

    if (request.method === "GET") {
      if (url.searchParams.get("pass") !== password) {
        return new Response("Unauthorized. Please provide the correct ?pass= parameter.", { status: 401 });
      }

      if (!env.TELEMETRY_KV) {
        return new Response("TELEMETRY_KV namespace not bound.", { status: 500 });
      }

      const rawData = [];

      let cursor = null;
      let isComplete = false;

      while (!isComplete) {
        const kvList = await env.TELEMETRY_KV.list({ prefix: "inst:", cursor });

        for (const key of kvList.keys) {
          if (key.metadata) {
            rawData.push({
              version: key.metadata.v || "unknown",
              os: key.metadata.o || "unknown",
              target: key.metadata.t || "unknown",
              country: key.metadata.c || "unknown",
              count: 1 // Since each key is a unique instance
            });
          }
        }

        isComplete = kvList.list_complete;
        cursor = kvList.cursor;
      }

      // Return the HTML/JS Dashboard
      return new Response(renderDashboard(rawData), {
        headers: { "Content-Type": "text/html" }
      });
    }

    // HANDLE INCOMING TELEMETRY REQUEST
    if (request.method === "POST") {
      try {
        const data = await request.json();

        const { InstanceId, os, target, appVersion } = data;
        if (!InstanceId || !appVersion) {
          return new Response("Bad Request", { status: 400 });
        }

        // Sanitize string inputs
        const clean = (val) => String(val || "unknown").replace(/[^a-zA-Z0-9.+-]/g, "");
        const sVersion = clean(appVersion);
        const sOs = clean(os);
        const sTarget = clean(target);
        const sId = clean(InstanceId);
        const sCountry = request.cf && request.cf.country ? String(request.cf.country).replace(/[^a-zA-Z]/g, "") : "unknown";

        if (env.TELEMETRY_KV) {
          await env.TELEMETRY_KV.put(`inst:${sId}`, "", {
            metadata: {
              v: sVersion,
              o: sOs,
              t: sTarget,
              c: sCountry,
              lastSeen: new Date().toISOString()
            }
          });
        }

        return new Response(JSON.stringify({ status: "success" }), {
          status: 200, headers: { "Content-Type": "application/json" }
        });
      } catch (err) {
        return new Response("Bad Request", { status: 400 });
      }
    }

    return new Response("Method Not Allowed", { status: 405 });
  }
};

// HTML & CHART
function renderDashboard(data) {
  return `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Posterizarr Analytics</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f9fafb; color: #1e293b; margin: 40px; }
      .container { max-width: 1000px; margin: 0 auto; }
      h1 { margin-bottom: 24px; font-weight: 600; letter-spacing: -0.02em; color: #0f172a; font-size: 24px; }
      .grid { display: grid; grid-template-columns: 1fr; gap: 16px; margin-bottom: 24px; }
      .card { background: #ffffff; padding: 20px 24px; border-radius: 8px; border: 1px solid #e2e8f0; display: flex; align-items: center; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
      .card-left { flex: 0 0 160px; padding-right: 24px; }
      .card-right { flex: 1; height: 160px; position: relative; min-width: 0; }
      .map-container { height: 350px; }
      h3 { margin: 0 0 8px 0; color: #64748b; font-size: 13px; font-weight: 500; }
      .top-badge { font-size: 28px; font-weight: 600; color: #0f172a; margin: 0; line-height: 1.2; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Posterizarr Unique Installations</h1>

      <div class="grid">
        <div class="card" style="display: block;">
          <h3>Total Unique Instances Tracked</h3>
          <div class="top-badge" id="totalCount">0</div>
        </div>

        <div class="card">
          <div class="card-left">
            <h3>Top Version</h3>
            <div class="top-badge" id="topVersion">-</div>
          </div>
          <div class="card-right">
            <canvas id="chartVersion"></canvas>
          </div>
        </div>

        <div class="card">
          <div class="card-left">
            <h3>Top OS</h3>
            <div class="top-badge" id="topOS">-</div>
          </div>
          <div class="card-right">
            <canvas id="chartOS"></canvas>
          </div>
        </div>

        <div class="card">
          <div class="card-left">
            <h3>Top Target</h3>
            <div class="top-badge" id="topTarget">-</div>
          </div>
          <div class="card-right">
            <canvas id="chartTarget"></canvas>
          </div>
        </div>

        <div class="card">
          <div class="card-left">
            <h3>Top Country</h3>
            <div class="top-badge" id="topCountry">-</div>
          </div>
          <div class="card-right">
            <canvas id="chartCountry"></canvas>
          </div>
        </div>

        <div class="card">
          <div class="card-left" style="align-self: flex-start;">
            <h3>Global Heatmap</h3>
            <div class="top-badge" style="font-size: 20px; color: #64748b; margin-top: 12px;">Interactive<br>Map</div>
          </div>
          <div class="card-right map-container">
            <div id="regions_div" style="width: 100%; height: 100%;"></div>
          </div>
        </div>
      </div>

    <script>
      const rawData = ${JSON.stringify(data)};

      // Aggregate data helpers
      const aggregate = (field) => {
        const counts = {};
        rawData.forEach(d => {
          counts[d[field]] = (counts[d[field]] || 0) + d.count;
        });

        // Sort by count descending
        return Object.fromEntries(
            Object.entries(counts).sort(([,a],[,b]) => b - a)
        );
      };

      const total = rawData.reduce((acc, d) => acc + d.count, 0);
      document.getElementById('totalCount').innerText = total.toLocaleString();

      const buildChart = (ctxId, aggregatedData) => {
        const topKey = Object.keys(aggregatedData)[0] || "-";

        new Chart(document.getElementById(ctxId), {
          type: 'line',
          data: {
            labels: Object.keys(aggregatedData),
            datasets: [{
              data: Object.values(aggregatedData),
              backgroundColor: 'rgba(147, 197, 253, 0.2)',
              borderColor: '#93c5fd',
              borderWidth: 2,
              fill: true,
              tension: 0.1,
              pointRadius: 3,
              pointBackgroundColor: '#3b82f6',
              pointBorderColor: '#ffffff',
              pointBorderWidth: 1
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false }, tooltip: { mode: 'index', intersect: false } },
            scales: {
              y: { beginAtZero: true, grid: { color: '#f1f5f9', drawBorder: false }, border: { display: false }, ticks: { color: '#64748b', maxTicksLimit: 5, padding: 10 } },
              x: { grid: { display: false, drawBorder: false }, border: { display: false }, ticks: { color: '#64748b', padding: 10 } }
            }
          }
        });
        return topKey;
      };

      // Render 4 beautiful Cloudflare-style line charts
      document.getElementById('topVersion').innerText = buildChart('chartVersion', aggregate('version'));
      document.getElementById('topOS').innerText = buildChart('chartOS', aggregate('os'));
      document.getElementById('topTarget').innerText = buildChart('chartTarget', aggregate('target'));
      document.getElementById('topCountry').innerText = buildChart('chartCountry', aggregate('country'));

      // Google GeoChart for Locations
      google.charts.load('current', {
        'packages':['geochart'],
      });
      google.charts.setOnLoadCallback(drawRegionsMap);

      function drawRegionsMap() {
        const countryData = aggregate('country');
        const dataArray = [['Country', 'Installs']];

        for (const [country, count] of Object.entries(countryData)) {
          if (country && country.toLowerCase() !== "unknown") {
            dataArray.push([country, count]);
          }
        }

        const data = google.visualization.arrayToDataTable(dataArray);

        const options = {
          backgroundColor: 'transparent',
          datalessRegionColor: '#f1f5f9',
          defaultColor: '#93c5fd',
          colorAxis: {colors: ['#dbeafe', '#60a5fa', '#2563eb']},
          legend: 'none',
          keepAspectRatio: true
        };

        const chart = new google.visualization.GeoChart(document.getElementById('regions_div'));
        chart.draw(data, options);
      }
    </script>
  </body>
  </html>
  `;
}