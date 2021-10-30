# "Fibaro Home Center 3" to "Home Assistant" integration

## How to use
1. Upload **hc3_to_mqtt_bridge.fqa** to your Fibaro Home Center 3
<img src="https://user-images.githubusercontent.com/1070777/129612383-ae2d0190-b616-45f9-91de-b0cbbfedf79a.png" width="40%" height="40%">
2. Configure your MQTT client connection
<ul>
  <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
  <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" - user credentials to access your MQTT broker (optional)</li>
</ul>
     <img src="https://user-images.githubusercontent.com/1070777/139558861-a4a68363-8f5c-4387-a5b8-c8a32275818b.png" width="70%" height="70%">

## Device support
   * Sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic temperature/humidity/brightness/etc sensors
   * Switches - Fibaro Relay Switch, Fibaro Dimmer
   * Thermostats - with a limited model support, but I can get it implemented if you send me device configuration, or the sample device ideally 
   * Shutters - Fibaro Shutter
   * Energy and power meters
   * RGBW
   * Remote Controllers, where each key is binded to automation triggers visible in Home Assistant GUI

## Your donations are welcome!
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=7FXBMQKCWESLN).
\
\
I can add new device support by buying new hardware for testing and allocating more time to programming during weekends.
\
\
Note: I'm using my mother's PayPal because (a) I'd like to support my parents ;-) (b) I'm located in Ukraine and technically not able to get direct donations, and my mother is located Germany where PayPal payments work like a charm
