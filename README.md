# cli-openweatherapi

---

###Dependencies:

        jq

install using something like:

        sudo apt install jq

###Configuration:

        add **.api_keys.sh** file to your $HOME directory

This file needs to export an ENV called OWM_API_KEY, as its exported by the script this ENV should be visible only when the script is running. You can export LAT and LON variable this way too for convinience.
