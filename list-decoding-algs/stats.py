import argparse
import csv
import statistics

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("filename", type=str)
    args = parser.parse_args()

    with open(args.filename) as infile:
        reader = csv.DictReader(infile)

        rows = list(reader)

    for anonymity_epoch in ["4", "60"]:
        ae_rows = list(
            filter(
                lambda row: row["anonymity_epoch"] == anonymity_epoch,
                rows
            )
        )
        info_row = ae_rows[0]
        degree = int(info_row["degree"])
        c = int(info_row["c"])
        f_power = int(info_row["f_power"])
        privacy_seconds = degree * int(anonymity_epoch)

        t_rec = int(info_row["agreement"])
        t_priv = int(info_row["degree"])

        max_stalkers = int(info_row["max_stalkers"])
        max_noise_percent = int(info_row["max_noise_percent"])
        detection_time = int(info_row["detection_time"])

        max_points = int(((detection_time // int(anonymity_epoch)) * (max_stalkers  + (max_noise_percent / 100))))

        print("~"*20)
        print(
            f"AE: {anonymity_epoch}, c = {c}, field size 2^{f_power} private for {privacy_seconds} secs "
            f"({privacy_seconds/60:0.4f} min), t_rec: {t_rec}, t_priv: {t_priv}, max: {max_points}"
        )
        print("~"*20)


        for total_stalkers in [1, 2, 3]:
            setting_1 = (total_stalkers, 50)

            total_points = int(((detection_time // int(anonymity_epoch)) * (total_stalkers  + (max_noise_percent / 100))))

            done_one  = True

            setting_2 = (0, (total_stalkers * 100) + 50)
            for (real_stalkers, real_noise_percent) in [setting_2, setting_1]:
                current_rows = list(filter(
                    lambda row: row["real_stalkers"] == str(real_stalkers) and row["real_noise_percent"] == str(real_noise_percent),
                    ae_rows
                ))

                relevant_rows = list(map(lambda row: float(row["time_to_recover"]), current_rows))
                runtime = statistics.mean(relevant_rows)
                std_dev = statistics.stdev(relevant_rows)
                

                if done_one:
                    relevant_rows =list(map(lambda row: float(row["time_to_detect"]), current_rows))
                    detection_runtime = statistics.mean(relevant_rows)
                    detection_std_dev = statistics.stdev(relevant_rows)
                    print(f"Total Stalkers {total_stalkers}, real stalkers {real_stalkers}, total points: {total_points}, detection runtime {detection_runtime:0.2f} +- {detection_std_dev:0.2f} (averaged over {len(relevant_rows)} iterations)")

                print(f"Total Stalkers {total_stalkers}, real stalkers {real_stalkers}, total points: {total_points}, recovery runtime {runtime:0.2f} +- {std_dev:0.2f} (averaged over {len(relevant_rows)} iterations)")
                
                done_one = True

        print("")