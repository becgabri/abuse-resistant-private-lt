import argparse
import csv
import statistics
from collections import defaultdict

import matplotlib.pyplot as plt
import numpy as np

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("filename", type=str)
    args = parser.parse_args()

    benchmarks = defaultdict(lambda: defaultdict(list))
    with open(args.filename) as infile:
        reader = csv.DictReader(infile)

        data = defaultdict(lambda: defaultdict(list))

        for row in reader:
            ae = row["anonymity_epoch"]
            real_stalkers = row["real_stalkers"]

            benchmarks[int(ae)][int(real_stalkers)].append(float(row["decode_time"]))

    real_stalker_counts = (0, 1, 2, 3)
    ae_means = {}
    for ae in [4, 60, 900]:
        ae_means[ae] = [
            (statistics.mean(benchmarks[ae][rs]), statistics.stdev(benchmarks[ae][rs]))
            for rs in real_stalker_counts
        ]

    x = np.arange(len(real_stalker_counts))
    width = 0.25
    multiplier = 0

    fix, ax = plt.subplots(layout="constrained")

    for ae, stats in ae_means.items():

        runtimes = list(map(lambda s: s[0], stats))
        stddevs = list(map(lambda s: s[1], stats))
        offset = width * multiplier
        rects = ax.bar(x + offset, runtimes, width, label=f"{ae} sec")
        ax.bar_label(rects, padding=3)
        plt.errorbar(
            x + offset,
            runtimes,
            stddevs,
            color="black",
            capsize=3,
            markersize=3,
            linestyle="None",
        )

        multiplier += 1

    ax.set_ylabel("Runtime (sec)")
    ax.set_xlabel("Number of stalkers")
    ax.set_title("Average Decoder Runtime by Anonymity Epoch (1000 Iterations)")
    ax.set_xticks(x + width, real_stalker_counts)
    ax.legend(loc="upper left", ncols=3)

    plt.show()
