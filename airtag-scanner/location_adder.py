import argparse
import csv

parser = argparse.ArgumentParser(
    prog="LocationAdder",
    description="Adds location data to BLE capture csv",
)

parser.add_argument("capture_file", help="csv containing BLE data")
parser.add_argument("location_file", help="csv containing location data")
parser.add_argument("output", help="file to write output to")
args = parser.parse_args()


with open(args.capture_file) as capture_file, open(
    args.location_file
) as location_file, open(args.output, "w+") as outfile:
    capture_reader = csv.reader(capture_file)
    location_reader = csv.reader(location_file)
    writer = csv.writer(outfile)

    prev_timestamp = -1
    prev_loc_row = None

    current_timestamp = -1
    current_loc_row = None

    for row in capture_reader:
        capture_timestamp = float(row[0])
        while capture_timestamp > prev_timestamp:
            loc_row = location_reader.__next__()
            if loc_row[2] == "NO_FIX":
                continue

            prev_timestamp = current_timestamp
            prev_loc_row = current_loc_row

            current_timestamp = float(loc_row[0])
            current_loc_row = loc_row

        if abs(capture_timestamp - current_timestamp) < abs(
            capture_timestamp - prev_timestamp
        ):
            # The timestamp of the row is closer to current than to prev
            row += current_loc_row
        else:
            row += prev_loc_row

        writer.writerow(row)
