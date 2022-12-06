# "Fibaro Home Center 3" to "Home Assistant" integration

## ❗ Warning
I had to move out of Kyiv to Berlin because of Russian's war against Ukraine => feature requests take more time because need to accommodate at new place.

## How to use
1. Upload **hc3_to_mqtt_bridge.fqa** to your Fibaro Home Center 3
<img src="https://user-images.githubusercontent.com/1070777/129612383-ae2d0190-b616-45f9-91de-b0cbbfedf79a.png" width="30%" height="30%">
2. Configure your MQTT client connection
<img src="https://user-images.githubusercontent.com/1070777/139558918-f38ff0f7-3753-40e2-a611-6b99b94498d5.png" width="45%" height="45%">
<ul>
  <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
  <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" (optional) - user credentials to access your MQTT broker</li>
  <li> "<b>deviceFilter</b>" (optional) - apply your filters for Fibaro HC3 device autodiscovery in case you need to limit the number of devices to be bridged with Home Assistant. Example <code>{"filter":"baseType", "value":["com.fibaro.actor"]}, {"filter":"deviceID", "value":[41,42]}, { MORE FILTERS MAY GO HERE }</code>. See available filter types at Fibaro API docs  https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"</li>
</ul>

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
Note: I'm using my mother's PayPal because (a) I'd like to support my parents ;-) (b) I'm located in Ukraine and technically not able to get direct donations, and my mother is located Germany where PayPal payments work like a charm

