#!/usr/bin/env sage
import argparse
import math

from sage.all import ceil, Integer, factor
from tqdm import tqdm

import json


class SchemeParams:
    def __init__(self, anonymity_epoch, f_power, ell, c, agreement):
        self.anonymity_epoch = anonymity_epoch
        self.f_power = f_power
        self.ell = ell
        self.c = c
        self.privacy_seconds = self.anonymity_epoch * self.ell
        self.agreement = agreement


def factors(num):
    def factors_rec(current, remaining_factors):
        if len(remaining_factors) == 0:
            return [current]
        else:
            result = []
            (prime_fac, max_power) = remaining_factors[0]
            for partial in [
                current * (prime_fac ** power) for power in range(max_power + 1)
            ]:
                result += factors_rec(partial, remaining_factors[1:])
            return result

    return sorted(factors_rec(1, list(factor(num))))


def bad_bound(agreement, n, c, ell):
    return agreement < (1.0 / (c + 1)) * (c * (ell + 1) + n)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-ab",
        "--available-bits",
        help="How many bits a broadcast can fit in",
        type=int,
        default=246,
    )
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
    parser.add_argument(
        "--all-aes",
        help="Try all possible anonymity epochs to find the best",
        action="store_true",
    )
    parser.add_argument(
        "--std-devs",
        help=(
            "The number of standard deviations in the channel deletions to be robust "
            "against"
        ),
        default=0,
        type=int,
    )

    args = parser.parse_args()

    if args.all_aes:
        anonymity_epochs = factors(args.dt)
    else:
        anonymity_epochs = [args.ae]

    best = None

    for anonymity_epoch in anonymity_epochs:
        points_per_stalker = args.dt // anonymity_epoch
        noise_rate = args.v / 100
        noise_points = math.ceil(noise_rate * points_per_stalker)
        n = (args.x * points_per_stalker) + noise_points
        for f_power in tqdm(range(8, 32)):
            max_c = math.floor((args.available_bits / f_power) - 1)
            field_size = Integer(2 ** f_power).previous_prime()

            with open('deletions-cache.json') as infile:
                deletions_cache = json.load(infile)
            

            ed = ceil(deletions_cache[str(anonymity_epoch)]['channel'] + deletions_cache[str(anonymity_epoch)]['collisions'][str(f_power)])


            agreement = points_per_stalker - ed

            ell = 1
            while not bad_bound(agreement=agreement, n=n, c=max_c, ell=ell):
                ell += 1
            ell -= 1

            current_params = SchemeParams(
                anonymity_epoch=anonymity_epoch,
                f_power=f_power,
                ell=ell,
                c=max_c,
                agreement=agreement,
            )

            if (
                best is None
                or (current_params.privacy_seconds > best.privacy_seconds)
                or (
                    current_params.privacy_seconds == best.privacy_seconds
                    and current_params.c < best.c
                )
            ):
                best = SchemeParams(
                    anonymity_epoch=anonymity_epoch,
                    f_power=f_power,
                    ell=ell,
                    c=max_c,
                    agreement=agreement,
                )

    print(
        f"Best configuration: Anonymity Epoch: {best.anonymity_epoch} "
        f"field size 2^{best.f_power}, c = {best.c}. Admits a degree of {best.ell} "
        f"for {float(best.privacy_seconds / 60):.2f} minutes of privacy "
        f"based on agreement {best.agreement}."
    )
