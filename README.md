# "Fibaro Home Center 3" to "Home Assistant" integration

## How to use:
1. Download hc3_mqtt_bridge.fqa
2. Import Quick Application to your Fibaro HC3
3. Setup variables for the Quick Application
   * **mqttUrl** - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"
   * **hc3Username** and **hc3Password** - user credentials to access event stream from your Fibaro Home Center 3 (mandatory)
   * **mqttUsername** and **mqttPassword** - user credentials to access your MQTT broker (optional)

Device support:
   * sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic temperature/humidity/brightness/etc sensors
   * switches - Fibaro Relay Switch, Fibaro Dimmer
   * thermostat - Connect Home CH-2xx (not recommended for purchase) 
   * shutters - Fibaro Shutter

## Your donations are welcome!
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=7FXBMQKCWESLN).
\
\
I can buy new hardware and spend more time for adding new devices support.
\
Worth mentioning - I'm using my mother's PayPal because (a) I'd like to support my parents ;-) (b) I'm located in Ukraine and technically not able to get direct donations, and my mother is located Germany where PayPal payments work like a charm
