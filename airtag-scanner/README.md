# AirTag BLE Advertisement Collector

This repo contains a collection of python scripts to collect and log AirTag BLE advertisements, while also tracking current location using GPS.

In order to be robust to random failures, such as the Pi losing power, data is logged to rotating .csv files.
The files rotate over every thirty minutes.

## Usage

1. Install gps requirements: `sudo apt-get install gpsd gpsd-clients`
1. Install requirements: `pip install -r requirements.txt`
1. Run the setup script `sudo ./setup.sh`
1. Restart the Pi, or run `systemctl --user start scanner`, `systemctl --user start tracker`
1. Collect data
1. Terminate both programs: `systemctl --user stop scanner`, `systemctl --user stop tracker`
1. Optional, disable the scanner and tracker services: `systemctl --user disable scanner`, `systemctl --user disable tracker`
1. Move to the folder where the data was collected: `cd ~/airtag-scanner-data`
1. Create an aggregate file for GPS data: `cat ./loc/* | sort > loc_agg.csv`
1. Create an aggregate file for BLE data: `cat ./ble/* | sort > cap_agg.csv`
1. Add the location data to the BLE capture file: `python location_adder.py cap_agg.csv log_agg.csv final.csv`
1. Done! `final.csv` contains all the AirTag advertisements seen, along with GPS data representing the location they were detected.  
