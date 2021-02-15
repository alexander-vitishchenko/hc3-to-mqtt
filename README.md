# hc3-to-mqtt
Fibaro HC3 and MQTT integration:
   * Device types - sensors (e.g. motion, door/window), multilevel sensors (e.g. temperature, brightness), switches, light bulbs, dimmers, shutter
   * Bi-directional integration allowing HC3 to publish Z-Wave device state changes to MQTT, and accepting commands from other MQTT clients
   * Integration with Home Assistant with autodiscovery support
   * Integration with Node-RED trough MQTT in/out nodes


How to use:
1. Download hc3_mqtt_bridge.fqa
2. Import Quick Application to your Fibaro HC3
3. Setup variables for the Quick Application
   * **mqttUrl** - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"
   * **hc3Auth** - contains user credentials to access you Fibaro HC3 API, same way as [HTTP Basic Authentication](https://en.wikipedia.org/wiki/Basic_access_authentication) encodes user credentials => you take your username, then append it with ":" character, then append with password, and then encode the resulting String with [Base64](https://www.base64encode.org/). For example if your username is "admin" and password is "password", then you hc3Auth variable should be "YWRtaW46cGFzc3dvcmQ=" ("admin:password" in decoded form)
   * MQTT broker user credentials could be passed in 2 ways
       * **mqttUsername** and **mqttPassword** as plain text
       * **mqttAuth** to pass user credentials in Base64 form (like hc3Auth above)
   * **mqttClientId** to setup custom client id, or using **"HC3-" .. plugin.mainDeviceId** by default
   * **mqttKeepAlive** to setup custom MQTT Keep Alive Period
![image](https://user-images.githubusercontent.com/1070777/107926657-a6cdce00-6f7e-11eb-917c-a66f2cc40e1b.png)

4. If you only want to integrate with Home Assistant then you are done :) If need more flexibility and integrate with NodeRed
   * suggest to install MQTT Explorer for being able to see the topic/message structure
   * send command messages from Node Red to Fibaro HC3 with topic "homeassistant/<device_type_in_Home_Assistant_terminology>/<device_id_as_shown_at_Fibaro_HC3>/commands/<command>", where <command> depends on a device type
      * setValue
      * setBrightness 
      * setPosition
      * setThermostatMode
      * setHeatingThermostatSetpoint

P.S. Some things are still under development, like full support for thermostats, fan, keyfob, seismometer and accelerometer. Continue testing for fixing possible defects
