import argparse
import csv
from datetime import datetime
import sys


def sliding_time_window(rows, window_length):
    window_start_index = 0
    while window_start_index < len(rows):
        start_time = float(rows[window_start_index][0])
        window_end_index = window_start_index
        window = []
        while (
            window_end_index < len(rows)
            and (float(rows[window_end_index][0]) - start_time) <= window_length
        ):
            window.append(rows[window_end_index])
            window_end_index += 1
        window_start_index += 1
        yield window


def is_airtag(battery):
    battery_byte = bin(int(battery, 16))[2:].zfill(8)
    return battery_byte[2:4] == "01"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="AirTag stats reporter",
        description="Displays stats about an AirTag advertisement collection session",
    )

    parser.add_argument(
        "datafile", type=str, help="The aggregate file with the ble/location data"
    )

    args = parser.parse_args()

    statuses = set()

    with open(args.datafile) as infile:
        reader = csv.reader(infile)
        rows = list(reader)

    timestamps = list(map(lambda r: int(r[0].split(".")[0]), rows))
    start_time = min(timestamps)
    end_time = max(timestamps)

    rows = list(filter(lambda r: is_airtag(r[3]), rows))

    macs = set(list(map(lambda r: r[5], rows)))

    print(
        "START:",
        datetime.utcfromtimestamp(start_time).strftime("%Y-%m-%d %H:%M:%S"),
        "UTC",
    )
    print(
        "END:  ",
        datetime.utcfromtimestamp(end_time).strftime("%Y-%m-%d %H:%M:%S"),
        "UTC",
    )
    print("Total Broadcasts:", len(rows))
    print("Total Devices:", len(macs))
    print(f"Devices / Two Seconds: {len(macs) / ((end_time - start_time) / 2):.5f}")

    least_devices_in_window = sys.maxsize
    most_devices_in_window = 0

    for window in sliding_time_window(rows, 5):
        num_macs = len(set(list(map(lambda r: r[5], window))))

        if num_macs > most_devices_in_window:
            most_devices_in_window = num_macs
        if num_macs < least_devices_in_window:
            least_devices_in_window = num_macs

    max_avg_devices = 0
    window_size = 60 * 5
    for window in sliding_time_window(rows, window_size):
        avg_devices = (2 * len(window)) / window_size

        if avg_devices > max_avg_devices:
            max_avg_devices = avg_devices

    num_repeats = 0
    seen_packets = set()
    for row in rows:
        packet = row[6]
        if packet in seen_packets:
            num_repeats += 1
        else:
            seen_packets.add(packet)

    # Longest-lasting neighbor tag
    neighbor_times = []
    for packet in seen_packets:
        times = list(
            map(lambda row: float(row[0]), filter(lambda row: row[6] == packet, rows))
        )
        tag_start_time = min(times)
        tag_end_time = max(times)
        neighbor_times.append(tag_end_time - tag_start_time)

    print(f"Most devices seen in a 5 second window:  {most_devices_in_window}")
    print(f"Least devices seen in a 5 second window: {least_devices_in_window}")
    print(
        f"Average Airtags in Proximity per Instant: {(2 * len(rows)) / (end_time - start_time):.5f}"
    )
    print(f"Max avg devices {window_size} secs: {max_avg_devices:.5f}")
    print(f"Number of repeated broadcasts: {num_repeats}")
    print(f"Longest Lasting Neighbor: {max(neighbor_times)/60:.2f}")
