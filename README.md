# hc3-to-mqtt
Bi-directional integration for Fibaro HC3 devices &lt;-> MQTT.

Features:
   * Device types support for binary sensors (e.g. motion, door/window), multilevel sensors (e.g. temperature, brightness), switches, light bulbs, dimmers
   * integration with Home Assistant with autodiscovery support
   * integration with Node-RED trough MQTT in/out nodes

How to use:
1. Download hc3_mqtt_bridge.fqa and install to your Fibaro HC3 as a quick application
2. Setup parameters 


P.S. some things are still under development:
   * Device types - thermostat, fan, keyfob, seismometer, accelerometer 
   * Code refactoring/scalability improvements for being able to add new features simpler
   * More testing for fix possible bugs and stability improvements
