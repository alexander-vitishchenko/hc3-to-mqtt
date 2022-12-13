# "Fibaro Home Center 3" to "Home Assistant" integration

## ❗ Warning
I had to move out of Kyiv to Berlin because of Russian's war against Ukraine => feature requests take more time because need to accommodate at new place.

## How to use
<ol>
<li>Download the latest <a href="https://github.com/alexander-vitishchenko/hc3-to-mqtt/releases/latest/download/hc3_to_mqtt_bridge-1.0.185.fqa">QuickApp</a>, and then upload it your Fibaro Home Center 3 instance
<br><br>
<img src="https://user-images.githubusercontent.com/1070777/129612383-ae2d0190-b616-45f9-91de-b0cbbfedf79a.png" width="30%" height="30%">
<br><br>
</li>
<li>Configure your MQTT client connection
<br>
<ul>
  <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
  <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" (optional) - user credentials for MQTT authentication</li>
  <li> "<b>deviceFilter</b>" (optional) - apply your filters for Fibaro HC3 device autodiscovery in case you need to limit the number of devices to be bridged with Home Assistant. Example <code>{"filter":"baseType", "value":["com.fibaro.actor"]}, {"filter":"deviceID", "value":[41,42]}, { MORE FILTERS MAY GO HERE }</code>. See available filter types at Fibaro API docs  https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"</li>
<br>
<img src="https://user-images.githubusercontent.com/1070777/139558918-f38ff0f7-3753-40e2-a611-6b99b94498d5.png" width="45%" height="45%">
<br>
</li>
</ul>
</ol>

<!--
## Device support
   * Sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic temperature/humidity/brightness/etc sensors
   * Switches - Fibaro Relay Switch, Fibaro Dimmer
   * Thermostats - with a limited model support, but I can get it implemented if you send me device configuration, or the sample device ideally 
   * Shutters - Fibaro Shutter
   * Energy and power meters
   * RGBW
   * Remote Controllers, where each key is binded to automation triggers visible in Home Assistant GUI
-->

## Your donations are welcome!
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=7FXBMQKCWESLN).
\
\
I can add new device support by buying new hardware for testing and allocating more time to programming during weekends.
\
\
Note: I'm using my mother's PayPal (Tatjana H.) to support both project and my parents :-)




