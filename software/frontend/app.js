const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
const wsUrl = `${wsProtocol}//${window.location.host}/ws`;
const apiUrl = `${window.location.protocol}//${window.location.host}/api/relays`;

let ws;

// DOM Elements
const connStatus = document.getElementById('conn-status');
const connText = document.getElementById('conn-text');
const valWater = document.getElementById('val-water');
const progWater = document.getElementById('prog-water');
const valBattery = document.getElementById('val-battery');
const progBattery = document.getElementById('prog-battery');
const valTemp = document.getElementById('val-temp');

const relayToggles = {
    water_pump: document.getElementById('relay-water_pump'),
    exterior_lights: document.getElementById('relay-exterior_lights'),
    fridge: document.getElementById('relay-fridge')
};

function connectWebSocket() {
    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
        connStatus.className = 'dot connected';
        connText.textContent = 'Connected';
    };

    ws.onclose = () => {
        connStatus.className = 'dot disconnected';
        connText.textContent = 'Disconnected. Retrying...';
        setTimeout(connectWebSocket, 3000);
    };

    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        updateUI(data);
    };
}

function updateUI(state) {
    // Update Sensors
    valWater.textContent = `${state.water_level}%`;
    progWater.style.width = `${state.water_level}%`;

    const batteryFormatted = state.battery_voltage.toFixed(1);
    valBattery.textContent = `${batteryFormatted}V`;
    // Approximate percentage based on 10V (0%) to 14V (100%)
    const battPercent = Math.max(0, Math.min(100, ((state.battery_voltage - 10) / 4) * 100));
    progBattery.style.width = `${battPercent}%`;

    valTemp.textContent = `${state.temperature}°C`;

    // Update Relays safely without triggering events
    for (const [key, element] of Object.entries(relayToggles)) {
        if (state.relays[key] !== undefined && element.checked !== state.relays[key]) {
            element.checked = state.relays[key];
        }
    }
}

// Add event listeners for toggles
for (const [key, element] of Object.entries(relayToggles)) {
    element.addEventListener('change', async (e) => {
        const state = e.target.checked;
        try {
            const response = await fetch(`${apiUrl}/${key}?state=${state}`, {
                method: 'POST'
            });
            if (!response.ok) {
                // Revert on error
                e.target.checked = !state;
                console.error("Failed to toggle relay");
            }
        } catch (err) {
            e.target.checked = !state;
            console.error("Network error toggling relay", err);
        }
    });
}

// Start connection
connectWebSocket();
