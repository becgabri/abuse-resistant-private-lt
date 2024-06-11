ln -s $(pwd)/scanner.py /usr/local/bin/scanner
ln -s $(pwd)/tracker.py /usr/local/bin/tracker
mkdir -p  ~/airtag-scanner-data
mkdir -p ~/airtag-scanner-data/ble
mkdir -p ~/airtag-scanner-data/loc
mkdir -p ~/.config/systemd/user/
ln -s $(pwd)/scanner.service ~/.config/systemd/user/scanner.service
ln -s $(pwd)/tracker.service ~/.config/systemd/user/tracker.service
systemctl --user daemon-reload
systemctl --user enable scanner
systemctl --user enable tracker
