pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The weather where the connection says you are, from wttr.in (`?format=j1`). `refresh()` fetches
// it when the last one is over half an hour old, so opening the calendar now and then keeps it
// current without polling.
Singleton {
    id: root

    property bool available: false
    property bool failed: false
    property real updated: 0
    property int temperature: 0
    property int feelsLike: 0
    property int high: 0
    property int low: 0
    // wttr.in's (WorldWeatherOnline's) condition code
    property int code: 0
    property string description
    property string area
    // Minutes into the day
    property int sunrise: 6 * 60
    property int sunset: 20 * 60

    readonly property string icon: {
        const now = new Date();
        const minute = now.getHours() * 60 + now.getMinutes();
        const night = minute < sunrise || minute >= sunset;
        if (code === 113)
            return night ? "clear_night" : "sunny";
        if (code === 116)
            return night ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 119 || code === 122)
            return "cloud";
        if ([143, 248, 260].includes(code))
            return "foggy";
        if ([200, 386, 389, 392, 395].includes(code))
            return "thunderstorm";
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(code))
            return "weather_snowy";
        return "rainy";
    }

    function refresh() {
        if (fetcher.running || Date.now() - updated < 30 * 60 * 1000)
            return;
        fetcher.running = true;
    }

    // "07:13 PM"
    function minutesOf(time: string): int {
        const match = time.match(/^(\d+):(\d+) (AM|PM)$/);
        if (!match)
            return 0;
        return (Number(match[1]) % 12 + (match[3] === "PM" ? 12 : 0)) * 60 + Number(match[2]);
    }

    function parse(text: string) {
        try {
            const data = JSON.parse(text);
            const now = data.current_condition[0];
            const today = data.weather[0];
            temperature = Number(now.temp_C);
            feelsLike = Number(now.FeelsLikeC);
            code = Number(now.weatherCode);
            description = now.weatherDesc[0].value.trim();
            high = Number(today.maxtempC);
            low = Number(today.mintempC);
            sunrise = minutesOf(today.astronomy[0].sunrise);
            sunset = minutesOf(today.astronomy[0].sunset);
            area = data.nearest_area?.[0]?.areaName?.[0]?.value ?? "";
            available = true;
            failed = false;
            updated = Date.now();
        } catch (e) {
            failed = true;
        }
    }

    Process {
        id: fetcher

        command: ["curl", "-sf", "--max-time", "10", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.failed = true;
        }
    }
}
