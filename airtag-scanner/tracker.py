#!/usr/bin/env python3

import argparse
from datetime import datetime
import gps
import logging.handlers
import os
import pathlib
import sys
import time

"""
Based on the example file here: https://gpsd.gitlab.io/gpsd/gpsd-client-example-code.html
"""

parser = argparse.ArgumentParser(
    prog="GPS Logger", description="Logs GPS location to a csv file"
)
parser.add_argument("parent_dir", help="The directory to log collected data to")
args = parser.parse_args()

parent_dir = pathlib.Path(args.parent_dir)
target_dir = datetime.now().strftime("%Y-%m-%d")
os.makedirs(parent_dir / target_dir, exist_ok=True)

session = gps.gps(mode=gps.WATCH_ENABLE)

log_handler = logging.handlers.TimedRotatingFileHandler(
    parent_dir / target_dir / "loc.csv",
    when="M",
    interval=30,
)
logger = logging.getLogger()
logger.addHandler(log_handler)
logger.addHandler(logging.StreamHandler(sys.stdout))
logger.setLevel(logging.CRITICAL)

try:
    while 0 == session.read():
        if not (gps.MODE_SET & session.valid):
            # not useful, probably not a TPV message
            continue
        row = {
            "mode": ("Invalid", "NO_FIX", "2D", "3D")[session.fix.mode],
            "gpsTime": session.fix.time if (gps.TIME_SET & session.valid) else "n/a",
            "lat": session.fix.latitude,
            "lon": session.fix.longitude,
            "latlonValid": gps.isfinite(session.fix.latitude)
            & gps.isfinite(session.fix.longitude),
            "timestamp": time.time(),
        }

        logging.critical(
            f"{row['timestamp']},{row['gpsTime']},{row['mode']},{row['latlonValid']},{row['lat']},{row['lon']}"
        )
        time.sleep(1)


except KeyboardInterrupt:
    # got a ^C.  Say bye, bye
    print("")

# Got ^C, or fell out of the loop.  Cleanup, and leave.
session.close()
exit(0)
