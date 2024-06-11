import argparse
import random
import statistics


from sage.all import GF, ceil, floor
from tqdm import tqdm


def run_experiment(
    previous_windows, stalkers, noise_percent, ppspw, f_power, deletion_percentage, bpp
):
    field = GF((2 ** f_power).previous_prime())

    total_other_points = ceil(
        ppspw * (previous_windows + stalkers + (noise_percent / 100))
    )

    channel_deletions = 0

    other_points = set()
    for _ in range(0, total_other_points):
        other_points.add(field.random_element())

    
    my_points = set()
    for _ in range(0, ppspw):
        added_point = False
        broadcast = field.random_element()
        for _ in range(0, bpp):
            if random.random() > (deletion_percentage / 100):
                my_points.add(broadcast)
                added_point = True
                break
        if not added_point:
            channel_deletions += 1

    

    my_surviving_points = my_points - other_points
    collision_deletions = len(my_points) - len(my_surviving_points)


    return len(my_surviving_points), channel_deletions, collision_deletions


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("--anonymity_epoch", "-ae", type=int, default=4)
    parser.add_argument("--stalkers", "-s", type=int, default=3)
    parser.add_argument("--noise_percent", "-np", type=int, default=50)
    parser.add_argument("--detection_window", "-dw", type=int, default=60 * 60)
    parser.add_argument("--f_power", "-fp", type=int, default=20)
    parser.add_argument("--previous_windows", "-pw", type=int, default=23)
    parser.add_argument("--min_survivors", "-ms", type=int, default=0)
    parser.add_argument("--iterations", "-i", type=int, default=1)
    parser.add_argument("--deletion_percentage", "-dp", type=int, default=5)

    args = parser.parse_args()

    ppspw = (
        args.detection_window / args.anonymity_epoch
    )  # "Points per stalker per window"

    bpp = floor(args.anonymity_epoch / 4)  # "Broadcasts per point"

    survivors = []
    channel_deletion_counts = []
    collision_deletion_counts = []
    for _ in tqdm(range(args.iterations)):
        num_survivors, chan_dels, col_dels = run_experiment(
                args.previous_windows,
                args.stalkers,
                args.noise_percent,
                ppspw,
                args.f_power,
                args.deletion_percentage,
                bpp,
            )
        survivors.append(num_survivors)
        channel_deletion_counts.append(chan_dels)
        collision_deletion_counts.append(col_dels)

        

    print("Mean", statistics.mean(survivors))
    print("Standard Dev", statistics.stdev(survivors))
    print(
        "Percentage over min",
        len(list(filter(lambda x: x >= args.min_survivors, survivors)))
        / len(survivors),
    )

    print("~~~")

    # print(channel_deletion_counts)
    # print(collision_deletion_counts)

    channel_deletion_counts = [int(x) for x in channel_deletion_counts]

    summy = sum(channel_deletion_counts)
    # print(summy)
    avg = summy / len(channel_deletion_counts)
    # print(avg)


    mchds = statistics.mean(channel_deletion_counts)
    stchds = statistics.stdev(channel_deletion_counts)

    mclds = statistics.mean(collision_deletion_counts)
    stclds = statistics.stdev(collision_deletion_counts)

    print("Mean channel dels:", mchds)
    print("Stddev channel dels:", statistics.stdev(channel_deletion_counts))
    print("Mean collision dels:", statistics.mean(collision_deletion_counts))
    print("Std dev collision dels:", statistics.stdev(collision_deletion_counts))

    print("~~~~")

    print("Three sigma channel deletions:", ceil(statistics.mean(channel_deletion_counts) + (3 * statistics.stdev(channel_deletion_counts))))
    print("Three sigma collision deletions:", ceil(statistics.mean(collision_deletion_counts) + (3 * statistics.stdev(collision_deletion_counts))))

    print("Three sigma total:", ceil(mclds + mchds + (3 * stclds) + (3 * stchds)))