# "Fibaro Home Center 3" to "Home Assistant" integration

## ❗ Warning
I had to move out of Kyiv to Berlin because of Russian's war against Ukraine => feature requests take more time because need to accommodate at new place.

## ❗ For those who used QuickApp prior to 1.0.191 version
Your Home Assistant dashboards and automations need to be reconfigured with new enity ids. This is a one-time effort that introduces a relatively \"small\" inconvenience for the greater good (a) introduce long-term stability so Home Assistant entity duplicates will not happen in certain scenarios (b) entity id namespaces are now syncronized between Fibaro and Home Assistant ecosystems.

## How to use
<ol>
    <li>
        Make sure you have MQTT broker installed, e.g. <a href="https://www.home-assistant.io/integrations/mqtt/">Mosquitto within your Home Assistance instance</a>.
        <br><br>
    </li>
    <li>
        Upload the latest <a href="https://github.com/alexander-vitishchenko/hc3-to-mqtt/releases/latest/download/hc3_to_mqtt_bridge-1.0.194.fqa">Fibaro QuickApp from GitHub</a> to your Fibaro Home Center 3 instance:
        <ul>
            <li>Open the Configuration Interface</li>
            <li>Go to Settings > Devices</li>
            <li>Click  +</li>
            <li>Choose Other Device</li>
            <li>Choose Upload File</li>
            <li>Choose file from your computer with .fqa</li>
        </ul>
        <br>
        <img src="https://user-images.githubusercontent.com/1070777/129612383-ae2d0190-b616-45f9-91de-b0cbbfedf79a.png" width="30%" height="30%">
        <br><br>
    </li>
    <li>
        Configure your Fibaro QuickApp:<br>
        <ul>
            <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
            <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" (optional) - user credentials for MQTT authentication</li>
            <li> "<b>deviceFilter</b>" (optional) - apply your filters for Fibaro HC3 device autodiscovery in case you need to limit the number of devices to be bridged with Home Assistant. Example <code>{"filter":"baseType", "value":["com.fibaro.actor"]}, {"filter":"deviceID", "value":[41,42]}, { MORE FILTERS MAY GO HERE }</code>. See available filter types at Fibaro API docs  https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"</li>
        <br>
        <img src="https://user-images.githubusercontent.com/1070777/139558918-f38ff0f7-3753-40e2-a611-6b99b94498d5.png" width="45%" height="45%">
        <br>
    </li>
</ol>

## Your donations are welcome!
I can add new device support by buying new hardware for testing and allocating more time to programming during weekends.
\
\
Note: I'm using my mother's PayPal (Tatjana H.) to support both project and my parents :-)
\
\
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=7FXBMQKCWESLN).

## Already supported device types:
   * Sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic sensors to measure temperature, humidity, brightness and so on
   * Energy and power meters
   * Charge level sensors for battery-powered devices
   * Lights - binary, dimmers and RGBW (no RGB for now)
   * Switches
   * Remote Controllers, where each key is binded to automation triggers visible in Home Assistant GUI
   * Thermostats (limited support for a few known vendors) 


