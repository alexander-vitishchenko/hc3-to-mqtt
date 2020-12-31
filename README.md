# hc3-to-mqtt
Fibaro HC3 and MQTT integration:
   * Device types - sensors (e.g. motion, door/window), multilevel sensors (e.g. temperature, brightness), switches, light bulbs, dimmers
   * Bi-directional integration allowing HC3 to publish Z-Wave device state changes to MQTT, and accepting commands from other MQTT clients
   * Integration with Home Assistant with autodiscovery support
   * Integration with Node-RED trough MQTT in/out nodes


How to use:
1. Download hc3_mqtt_bridge.fqa
2. Import Quick Application to your Fibaro HC3
3. Setup variables for ther Quick Application
   * mqttUrl - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.100:1883"
   * hc3Auth - login and password for pulling events from Fibaro HC3. Must be encoded with Base64, e.g. "admin:password" -> "YWRtaW46cGFzc3dvcmQ="


P.S. some things are still under development:
   * Device types - thermostat, fan, keyfob, seismometer, accelerometer 
   * Code refactoring/scalability improvements for being able to add new features simpler
   * More testing for fix possible bugs and stability improvements
