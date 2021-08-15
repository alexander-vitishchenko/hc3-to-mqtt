# "Fibaro Home Center 3" to "Home Assistant" integration
QuickApp for Fibaro HC3 and MQTT integration:
   * Device types - sensors (e.g. motion, door/window), multilevel sensors (e.g. temperature, brightness), switches, light bulbs, dimmers, shutter
   * Bi-directional integration allowing HC3 to publish Z-Wave device state changes to MQTT, and accepting commands from other MQTT clients
   * Integration with Home Assistant with autodiscovery support
   * Integration with Node-RED trough MQTT in/out nodes

## How to use:
1. Download hc3_mqtt_bridge.fqa
2. Import Quick Application to your Fibaro HC3
3. Setup variables for the Quick Application
   * **mqttUrl** - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"
   * **hc3Username** and **hc3Password** - user credentials to access event stream from your Fibaro Home Center 3 (mandatory)
   * **mqttUsername** and **mqttPassword** - user credentials to access your MQTT broker (optional)

## Your donations are welcome!
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=7FXBMQKCWESLN).
\
\
I can buy new hardware and spend more time for adding new devices support.
\
Worth mentioning - I'm using my mother's PayPal because (a) I'd like to support my parents ;-) (b) I'm located in Ukraine and technically not able to get direct donations, and my mother is located Germany where PayPal payments work like a charm
