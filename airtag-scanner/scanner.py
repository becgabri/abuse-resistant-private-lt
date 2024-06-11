#!/usr/bin/env python3

import argparse
import asyncio
import binascii
from datetime import datetime
import logging
import logging.handlers
import os
import pathlib
import sys
import time


from bleak import BleakScanner
from construct import Array, Byte, Const, Struct
from construct.core import ConstError

findmy_format = Struct(
    "type_length" / Const(b"\x12\x19"),
    "battery" / Byte,
    "pub_key_bytes_6_to_27" / Array(22, Byte),
    "pub_key_bits_0_to_1" / Byte,
    "hint" / Byte,
)


def get_public_key(mac_addr, pub_key_bytes_6_to_27, pub_key_bits_0_to_1):
    pub_key_bytes_1_to_5 = binascii.unhexlify(mac_addr[2:].replace(":", ""))

    addr_byte_0 = mac_addr[0:2]
    addr_byte_0_int = int.from_bytes(binascii.unhexlify(addr_byte_0), "big")
    pub_key_byte_0_int = (pub_key_bits_0_to_1 << 6) | (addr_byte_0_int & 63)

    public_key = pub_key_byte_0_int.to_bytes(1, "big") + pub_key_bytes_1_to_5

    for i in pub_key_bytes_6_to_27:
        public_key += i.to_bytes(1, "big")

    return public_key


def device_found(device, ad_data):
    man_data = ad_data.manufacturer_data
    if 0x004C in man_data:
        try:
            findmy = findmy_format.parse(man_data[0x004C])
        except ConstError:
            pass
        else:
            row = {
                "rssi": ad_data.rssi,
                "public_key": get_public_key(
                    device.address,
                    findmy.pub_key_bytes_6_to_27,
                    findmy.pub_key_bits_0_to_1,
                ).hex(),
                "battery": findmy.battery.to_bytes(1, "big").hex(),
                "hint": findmy.hint.to_bytes(1, "big").hex(),
                "raw_mac": device.address,
                "raw_packet": man_data[0x004C].hex(),
                "timestamp": time.time(),
            }
            logging.critical(
                f"{row['timestamp']},{row['rssi']},{row['public_key']},{row['battery']},{row['hint']},{row['raw_mac']},{row['raw_packet']}"
            )


async def run_scanner():
    scanner = BleakScanner(device_found)
    stop_event = asyncio.Event()
    await scanner.start()
    await stop_event.wait()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="AirTag BLE Scanner",
        description="Logs AirTag BLE advertisements to a file",
    )
    parser.add_argument("parent_dir", help="The directory to log collected data to")
    args = parser.parse_args()

    parent_dir = pathlib.Path(args.parent_dir)
    target_dir = datetime.now().strftime("%Y-%m-%d")
    os.makedirs(parent_dir / target_dir, exist_ok=True)

    log_handler = logging.handlers.TimedRotatingFileHandler(
        parent_dir / target_dir / "ble.csv", when="M", interval=30
    )
    logger = logging.getLogger()
    logger.addHandler(log_handler)
    logger.addHandler(logging.StreamHandler(sys.stdout))
    logger.setLevel(logging.CRITICAL)
    asyncio.run(run_scanner())
