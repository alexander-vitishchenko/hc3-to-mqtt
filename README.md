# "Fibaro Home Center 3" to "Home Assistant" integration

## How to use
1. Upload **hc3_to_mqtt_bridge.fqa** to your Fibaro Home Center 3
<img src="https://user-images.githubusercontent.com/1070777/129612383-ae2d0190-b616-45f9-91de-b0cbbfedf79a.png" width="40%" height="40%">
2. Setup your environment variables
<ul>
  <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
  <li> "<b>hc3Username</b>" and "<b>hc3Password</b>" - user credentials to access event stream from your Fibaro Home Center 3 (mandatory)</li>
  <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" - user credentials to access your MQTT broker (optional)</li>
</ul>
     <img src="https://user-images.githubusercontent.com/1070777/129613646-5c762c8e-e39e-4173-8741-723abe4337e2.png" width="70%" height="70%">

## Device support
   * sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic temperature/humidity/brightness/etc sensors
   * switches - Fibaro Relay Switch, Fibaro Dimmer
   * thermostat - Connect Home CH-2xx (not recommended for purchase) 
   * shutters - Fibaro Shutter

## Your donations are welcome!
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=7FXBMQKCWESLN).
\
\
I can add new device support by buying new hardware for testing and allocating more time to programming during weekends.
\
\
Note: I'm using my mother's PayPal because (a) I'd like to support my parents ;-) (b) I'm located in Ukraine and technically not able to get direct donations, and my mother is located Germany where PayPal payments work like a charm
