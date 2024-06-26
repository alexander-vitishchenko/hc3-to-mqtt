# "Fibaro Home Center 3" to "Home Assistant" integration
Manage your Fibaro HC3, HCL and Yubii Home devices from Home Assistant.

Note on alternative Fibaro to Home Assistant connector: consider <a href="https://www.home-assistant.io/integrations/fibaro/">https://www.home-assistant.io/integrations/fibaro/</a> that doesn't require MQTT and thus might be simpler to configure, assuming it supports device types you need.

## How to use
<ol>
    <li>
        Make sure you have MQTT broker installed, e.g. <a href="https://github.com/home-assistant/addons/blob/master/mosquitto/DOCS.md">Mosquitto within your Home Assistance instance</a>. 
        <br><br>
    </li>
    <li>
        Make sure you have "MQTT" integration added and configured your Home Assistant instance, as <a href="https://www.home-assistant.io/integrations/mqtt">described here</a>. 
        <br><br>
    </li>
    <li>
        Upload the latest <a href="https://github.com/alexander-vitishchenko/hc3-to-mqtt/releases/latest/download/hc3_to_mqtt_bridge-1.0.235.fqa">Fibaro QuickApp from GitHub</a> to your Fibaro Home Center 3 instance:
        <ul>
            <li>Open the Configuration Interface</li>
            <li>Go to Settings > Devices</li>
            <li>Click  +</li>
            <li>Choose Other Device</li>
            <li>Choose Upload File</li>
            <li>Choose file from your computer with .fqa</li>
        </ul>
        <br>
        <img src="https://user-images.githubusercontent.com/1070777/129612383-ae2d0190-b616-45f9-91de-b0cbbfedf79a.png" width="30%" height="30%">
        <br><br>
    </li>
    <li>
        Configure your Fibaro QuickApp:<br>
        <ul>
            <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. "mqtt://192.168.1.10:1883"</li>
            <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" (optional) - user credentials for MQTT authentication</li>
            <li> "<b>deviceFilter</b>" (optional) - apply your filters for Fibaro HC3 device autodiscovery in case you need to limit the number of devices to be bridged with Home Assistant. <br>
            <details>
               <summary>Click here to see example</summary>
               <code>{"filter":"baseType", "value":["com.fibaro.actor"]}, {"filter":"deviceID", "value":[41,42]}, { MORE FILTERS MAY GO HERE }</code>.<br> Fibaro Filter API description and more examples could be found at https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"
               <br><br>Use "deviceFilter", "deviceFilter2", "deviceFilter3" ... "deviceFilterX" to overcome Fibaro QuickApp variable length limitation. Use "," (commas) after each filter criterion as it is not added added automatically
            </details>
            </li>
        <br>
        <img src="https://user-images.githubusercontent.com/1070777/139558918-f38ff0f7-3753-40e2-a611-6b99b94498d5.png" width="45%" height="45%">
        <br>
    </li>
</ol>

## Your donations are welcome!
[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=QA88EYA93QQ3W).

## Already supported device types:
   * Z-Wave hardware, and experimental Zigbee & Nice devices support
   * Sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic sensors to measure temperature, humidity, brightness and so on
   * Energy and power meters
   * Charge level sensors for battery-powered devices
   * Lights - binary, dimmers and RGBW (no RGB for now)
   * Switches - binary and sound
   * Remote Controllers, where each key is binded to automation triggers visible in Home Assistant GUI
   * Thermostats (limited support for a few known vendors) 
<br>
<b>Do you questions about using the QuickApp, or ideas to discuss? Use <a href="https://github.com/alexander-vitishchenko/hc3-to-mqtt/discussions">Discussions module</a></b>
<br>
<br>
<details>
  <summary><b>Want to propose a new device support? Click here</b></summary>
  <br>
  <ul>
      <li>Open Fibaro Home Center 3 in a web-browser
          <ul>
            <li>Home Screen > Swagger (left-bottom panel) > devices > by id > export JSON file</li>
            <li>Home Screen > Device viewer
                <ul>
                    <li>Default tab > make screenshot #1</li>
                    <li>Advanced tab > make screenshot #2</li>
                    <li>Preview tab > make screenshot #3</li>
                </ul>
            </li>
          </ul>
      </li>
      <li>Prepare a few sentence description and examples how you want to use Fibaro device from Home Assistant UI</li>
      <li>Submit the use-case descripton, JSON file(s) and screenshots, along with the device importance description <a href="https://github.com/alexander-vitishchenko/hc3-to-mqtt/issues/new?assignees=&labels=&template=feature_request.md&title=">here</a></li>
  </ul>

</details>






















