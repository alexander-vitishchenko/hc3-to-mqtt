# hc3-to-mqtt
Fibaro HC3 and MQTT integration:
   * Device types - sensors (e.g. motion, door/window), multilevel sensors (e.g. temperature, brightness), switches, light bulbs, dimmers, shutter
   * Bi-directional integration allowing HC3 to publish Z-Wave device state changes to MQTT, and accepting commands from other MQTT clients
   * Integration with Home Assistant with autodiscovery support
   * Integration with Node-RED trough MQTT in/out nodes


How to use:
1. Download hc3_mqtt_bridge.fqa
2. Import Quick Application to your Fibaro HC3
3. Setup variables for ther Quick Application
   * mqttUrl - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.100:1883"
   * hc3Auth - login and password for pulling events from Fibaro HC3. Must be encoded with Base64, e.g. "admin:password" -> "YWRtaW46cGFzc3dvcmQ="
4. If you only want to integrate with Home Assistant then you are done :) If need more flexibility and integrate with NodeRed
   * suggest to install MQTT Explorer for being able to see the topic/message structure
   * send command messages from Node Red to Fibaro HC3 with topic "homeassistant/<device_type_in_Home_Assistant_terminology>/<device_id_as_shown_at_Fibaro_HC3>/commands/<command>", where <command> depends on a device type
      * setValue
      * setBrightness 
      * setPosition
      * setThermostatMode
      * setHeatingThermostatSetpoint

P.S. Some things are still under development, like full support for thermostats, fan, keyfob, seismometer and accelerometer. Continue testing for fixing possible defects
