import argparse
import csv
import math
import random


def ints(start=0):
    current = start
    while True:
        current += 1
        yield current


def is_airtag(battery):
    battery_byte = bin(int(battery, 16))[2:].zfill(8)
    return battery_byte[2:4] == "01"


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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("filename", type=str)
    parser.add_argument("--anonymity-epoch", "-ae", type=int, default=4)
    parser.add_argument("--prefiltering-minimum", "-pm", type=int, default=0)
    args = parser.parse_args()

    with open(args.filename) as infile:
        reader = csv.reader(infile)
        rows = list(reader)

    timestamps = list(map(lambda r: int(r[0].split(".")[0]), rows))
    start_time = min(timestamps)
    end_time = max(timestamps)
    duration = (int(end_time) - int(start_time)) / (60 * 60)
    print("DURATION", duration)

    rows = list(filter(lambda r: is_airtag(r[3]), rows))


    for window in sliding_time_window(rows, 60):
        # print(rows[0][5])
        count = len(list(filter(lambda x: x[5] == 'D7:34:BC:47:8B:0C', window)))
        if count > 1:
            print(count, window[0][0])

    assert False

    noise_points = []

    mac_info = {}
    id_generator = ints()
    for row in rows:
        mac = row[5]
        timestamp = float(row[0])

        if mac not in mac_info:
            mac_info[mac] = {
                # "ae_start": timestamp - (random.random() * args.anonymity_epoch),
                "ae_start": timestamp - (args.anonymity_epoch / 2),
                "id": id_generator.__next__(),
            }
            if mac_info[mac]["id"] == 44:
                print(mac)

        ae_start = mac_info[mac]["ae_start"]
        mac_id = mac_info[mac]["id"]

        noise_points.append(
            f"{mac_id}.{math.floor((timestamp - ae_start)/args.anonymity_epoch)}"
        )

    print(noise_points)

    print("Anonymity Epoch:", args.anonymity_epoch)
    print("Prefiltering minimum:", args.prefiltering_minimum)
    print("\n", "~"*10, "\n")
    print("Unique noise points:", len(set(noise_points)))
    print(f"Unique noise points per hour: {len(set(noise_points)) / duration:0.4f}")

    print("\n", "~"*10, "\n")

    prefiltered = list(
        filter(
            lambda pt: noise_points.count(pt) > args.prefiltering_minimum,
            set(noise_points),
        )
    )
    print("Post prefiltering unique noise points:", len(prefiltered))
    print(
        f"Post prefiltering unique points per hour: {len(prefiltered) / duration:0.4f}"
    )
