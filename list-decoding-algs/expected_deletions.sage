import argparse
import math

from sage.all import binomial, ceil, Integer, sqrt


def expected_channel_deletions(
    points_per_stalker, anonymity_epoch, deletion_percent, delta
):
    deletion_probability = deletion_percent / 100

    point_deletion_probability = deletion_probability ** (anonymity_epoch / delta)

    deletions_from_channel = point_deletion_probability * points_per_stalker


    variance = 0
    for x in range(points_per_stalker + 1):
        variance += (
            ((x - deletions_from_channel)**2) *
            (
                binomial(points_per_stalker, x) * 
                ((point_deletion_probability) ** x) *
                ((1 - point_deletion_probability) ** (points_per_stalker - 1))
            )
        )



    return deletions_from_channel, variance


def expected_collision_deletions(
    points_per_stalker, field_size, previous_windows, num_stalkers, noise_percent
):

    noise_rate = noise_percent / 100
    expected_collision_survivors = points_per_stalker * (
        ((field_size - 1) / field_size)
        ** (((previous_windows + num_stalkers + noise_rate) * points_per_stalker) - 1)
    )
    expected_deletions_from_collisions = (
        points_per_stalker - expected_collision_survivors
    )
    return expected_deletions_from_collisions


def expected_deletions(
    delta=2,
    anonymity_epoch=4,
    detection_time=3600,
    deletion_percent=5,
    field_size=4294967291,
    num_stalkers=3,
    noise_percent=50,
    previous_windows=23,
    deletion_std_devs = 0
):

    points_per_stalker = detection_time // anonymity_epoch

    channel_dels, channel_del_variance = expected_channel_deletions(
        points_per_stalker, anonymity_epoch, deletion_percent, delta
    )

    channel_del_std_dev = sqrt(channel_del_variance)
    channel_dels += (channel_del_std_dev * deletion_std_devs)

    collision_dels = expected_collision_deletions(
        points_per_stalker, field_size, previous_windows, num_stalkers, noise_percent
    )

    total_expected_deletions = ceil(channel_dels + collision_dels)
    return total_expected_deletions


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-ae", help="Anonymity epoch in seconds", type=int, default=4)
    parser.add_argument(
        "-dt", help="Detection time in seconds", type=int, default=60 * 60
    )
    parser.add_argument(
        "-dp", help="Deletion percentage in channel", type=int, default=5
    )
    parser.add_argument("--delta", help="Time between broadcasts", default=4, type=int)
    parser.add_argument(
        "-fp",
        help="The power of two that determines the field size",
        default=32,
        type=int,
    )
    parser.add_argument(
        "-pw", help="The number of previous windows to consider", type=int, default=23
    )
    parser.add_argument("-x", help="The number of stalkers", type=int, default=3)
    parser.add_argument("-v", help="The noise percent", type=int, default=50)

    args = parser.parse_args()

    print(
        f"Stats for anonymity epoch {args.ae}, detection time {args.dt}, "
        f"deletion percentage {args.dp}, delta {args.delta}, field size 2^{args.fp}, "
        f"number of stalkers {args.x}, noise rate {args.v}, "
        f"after {args.pw} previous windows."
    )
    print("~" * 10)

    points_per_stalker = args.dt // args.ae

    channel_dels, variance = expected_channel_deletions(
        points_per_stalker, args.ae, args.dp, args.delta
    )

    print("Expected deletions from the channel:", channel_dels)
    print(f"Std dev deletions from channel: {float(sqrt(variance)):0.5f}")

    field_size = Integer(2 ** args.fp).previous_prime()
    collision_dels = expected_collision_deletions(
        points_per_stalker, field_size, args.pw, args.x, args.v
    )
    print("Expected deletions from collisions: {:.5f}".format(float(collision_dels)))

    total_expected_deletions = math.ceil(channel_dels + collision_dels)

    print("Total expected deletions:", total_expected_deletions)
    print("")
    print(
        f"After {points_per_stalker} points broadcast "
        f"{points_per_stalker - total_expected_deletions} are expected to survive"
    )
