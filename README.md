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
   * **hc3Username** and **hc3Password** - user credentials to access event stream from your Fibaro Home Center 3 (mandatory)
   * **mqttUsername** and **mqttPassword** - user credentials to access your MQTT broker (optional)

4. If you only want to integrate with Home Assistant then you are done :) If need more flexibility and integrate with NodeRed
   * suggest to install MQTT Explorer for being able to see the topic/message structure
   * send command messages from Node Red to Fibaro HC3 with topic "homeassistant/<device_type>/<device_id_as_shown_at_Fibaro_HC3>/set/<property>", where <property> could be
      * state
      * value 
      * thermostatMode
      * and so on


Advanced "variables" for the bridge:
   * **mqttClientId** to setup custom client id, or using **"HC3-" .. plugin.mainDeviceId** by default
   * **mqttKeepAlive** to setup custom MQTT Keep Alive Period
   * **hc3Auth** and **mqttAuth** - contains your user credentials to access you Fibaro HC3 API and MQTT, same way as [HTTP Basic Authentication](https://en.wikipedia.org/wiki/Basic_access_authentication) encodes user credentials => you take your username, then append it with ":" character, then append with password, and then encode the resulting String with [Base64](https://www.base64encode.org/). For example if your username is "admin" and password is "password", then you hc3Auth variable should be "YWRtaW46cGFzc3dvcmQ=" ("admin:password" in decoded form)
