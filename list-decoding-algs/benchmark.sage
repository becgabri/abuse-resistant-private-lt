#!/usr/bin/env sage
import argparse
import json
import logging
import multiprocessing as mp
import queue
import time
from enum import Enum

from sage.all import GF, Integer, PolynomialRing, ceil
# from tqdm import tqdm

import instance_generation
from ch_decoder import CHDecoder

def tqdm_wrapper(use_tqdm, iterator):
    if use_tqdm:
        from tqdm import tqdm
        return tqdm(iterator)
    return iterator

class Algorithm(Enum):
    GS = "GS"
    CH = "CH"


class InstanceType(Enum):
    adversarial = "adversarial"
    simulated = "simulated"


class DecodeTime:
    def __init__(self, timed_out, time_to_detect=None, time_to_recover=None):
        self.timed_out = timed_out
        # if not self.timed_out and time_to_detect is None or time_to_recover is None:
        #     raise ValueError("Cannot not time out and have a time that is not None")
        self.time_to_detect = time_to_detect
        self.time_to_recover = time_to_recover


class Benchmark:
    def header():
        return (
            "algorithm,detection_time,f_power,c,degree,anonymity_epoch,max_stalkers,"
            "real_stalkers,max_noise_percent,real_noise_percent,n,deletion_percent,"
            "agreement,timeout,theoretically_possible,multiplicity,timed_out,"
            "time_to_detect,time_to_recover,stalker_counts,stalkers_recovered"
        )

    def __init__(
        self,
        detection_time,
        c,
        anonymity_epoch,
        f_power,
        max_stalkers,
        real_stalkers,
        max_noise_percent,
        real_noise_percent,
        n,
        agreement,
        timeout,
        degree,
        decode_time,
        stalkers_recovered,
        stalker_counts,
        deletion_percent=5,
        theoretically_possible=True,
    ):
        self.detection_time = detection_time
        self.c = c
        self.anonymity_epoch = anonymity_epoch
        self.f_power = f_power
        self.max_stalkers = max_stalkers
        self.real_stalkers = real_stalkers
        self.n = n
        self.max_noise_percent = max_noise_percent
        self.real_noise_percent = real_noise_percent
        self.agreement = agreement
        self.timeout = timeout
        self.degree = degree
        self.theoretically_possible = theoretically_possible
        self.deletion_percent = deletion_percent
        self.decode_time = decode_time
        self.stalkers_recovered = stalkers_recovered
        self.stalker_counts = stalker_counts

    def to_row(self):
        if not self.theoretically_possible:
            # Config was impossible so no decode happened
            final_values = f"{None},{None},{None},{None},{None}"
        elif self.decode_time.timed_out:
            final_values = f"{True},{None},{None},{None},{None}"
        else:
            final_values = (
                f"{False},{self.decode_time.time_to_detect},"
                f"{self.decode_time.time_to_recover},"
                f'"{json.dumps(self.stalker_counts)}",{self.stalkers_recovered}'
            )

        return (
            f"CH,{self.detection_time},{self.f_power},{self.c},{self.degree},"
            f"{self.anonymity_epoch},{self.max_stalkers},{self.real_stalkers},"
            f"{self.max_noise_percent},{self.real_noise_percent},{self.n},"
            f"{self.deletion_percent},{self.agreement},{self.timeout},"
            f"{self.theoretically_possible},1,"
        ) + final_values


def dedup_codeword(codeword):
    seen_xs = set()
    new_codeword = []
    for symbol in codeword:
        if symbol[0] not in seen_xs:
            new_codeword.append(symbol)
        seen_xs.add(symbol[0])
    return new_codeword


def wrapper(q, decoder, codeword):
    # Dedup codeword
    new_codeword = dedup_codeword(codeword)
    result = decoder.list_decode(new_codeword)
    q.put(result)
    q.close()


def benchmark_decoder(decoder, codeword):
    start_time = time.time()
    new_codeword = dedup_codeword(codeword)
    result = decoder.list_decode(new_codeword)
    end_time = time.time()

    return (DecodeTime(False, result.time_to_detect, end_time - start_time), result)


def get_max_degree(pR, c, n, agreement):
    ell = 1
    while True:
        try:
            CHDecoder(
                pR=pR,
                c=c,
                n=n,
                ell=ell + 1,
                agreement=agreement,
                multiplicity=1,
                shift=1,
            )
        except ValueError:
            return ell

        ell += 1


def benchmark_params(
    logger,
    max_stalkers,
    real_stalkers,
    max_noise_percent,
    real_noise_percent,
    anonymity_epoch,
    detection_time,
    deletion_percent,
    delta,
    previous_windows,
    iterations,
    timeout,
    f_power,
    c,
    std_devs,
    instance_type=InstanceType.adversarial,
    agreement_override=None,
    degree=None,
    use_tqdm=True
):

    field_size = Integer(2 ** f_power).previous_prime()
    field = GF(field_size)
    pR = PolynomialRing(field, "z")

    points_per_stalker = detection_time // anonymity_epoch

    # total_expected_deletions = expected_deletions.expected_deletions(
    #     delta=delta,
    #     anonymity_epoch=anonymity_epoch,
    #     detection_time=detection_time,
    #     deletion_percent=deletion_percent,
    #     field_size=field_size,
    #     num_stalkers=max_stalkers,
    #     noise_percent=max_noise_percent,
    #     previous_windows=previous_windows,
    #     deletion_std_devs=std_devs,
    # )

    max_noise_rate = max_noise_percent / 100
    real_noise_rate = real_noise_percent / 100

    max_noise_points = ceil(max_noise_rate * points_per_stalker)
    real_noise_points = ceil(real_noise_rate * points_per_stalker)

    n = (max_stalkers * points_per_stalker) + max_noise_points

    if agreement_override is not None:
        worst_case_agreement = agreement_override
    else:
        worst_case_agreement = points_per_stalker - total_expected_deletions

    if degree is not None:
        ell = degree
    else:
        ell = get_max_degree(pR, c, n, worst_case_agreement)

    # Test the next iteration
    decoder = CHDecoder(
        pR=pR,
        c=c,
        n=n,
        ell=ell,
        agreement=worst_case_agreement,
        multiplicity=1,
        shift=1,
    )

    for i in tqdm_wrapper(use_tqdm, range(iterations)):

        if not use_tqdm:
            print(f"{i}/{iterations}")

        if instance_type == InstanceType.adversarial:
            evals = ([points_per_stalker] * real_stalkers) + [real_noise_points]
            _, codeword = instance_generation.gen_adversarial_instance(
                field=field, pR=pR, ell=ell, c=c, evals=evals
            )
        elif instance_type == InstanceType.simulated:
            codeword = instance_generation.gen_simulated_instance(
                field=field,
                pR=pR,
                ell=ell,
                c=c,
                num_stalkers=real_stalkers,
                anonymity_epoch=anonymity_epoch,
                delta=delta,
                detection_time=detection_time,
                deletion_percent=0,
                num_noise_points=real_noise_points,
                previous_windows=previous_windows,
            )

        stalker_counts = []
        new_codeword = dedup_codeword(codeword)
        for stalker in range(real_stalkers):
            stalker_points = list((filter(lambda sym: sym[2] == stalker, new_codeword)))
            stalker_counts.append(len(stalker_points))

        codeword = list(map(lambda pt: pt[:2], codeword))

        runtime, result = benchmark_decoder(decoder, codeword)

        if not runtime.timed_out:
            stalkers_recovered = len(result.solns)
        else:
            stalkers_recovered = None

        benchmark = Benchmark(
            detection_time=detection_time,
            c=c,
            anonymity_epoch=anonymity_epoch,
            f_power=f_power,
            max_stalkers=max_stalkers,
            real_stalkers=real_stalkers,
            max_noise_percent=max_noise_percent,
            real_noise_percent=real_noise_percent,
            agreement=worst_case_agreement,
            timeout=timeout,
            degree=ell,
            decode_time=runtime,
            stalker_counts=stalker_counts,
            stalkers_recovered=stalkers_recovered,
            n=len(codeword),
        )

        logger.critical(benchmark.to_row())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--filename",
        type=str,
        help="The name of the file to log results to",
        default="benchmarks.csv",
    )
    parser.add_argument(
        "--iterations",
        type=int,
        help="the number of iterations per benchmark",
        default=1,
    )
    parser.add_argument(
        "--use_tqdm",
        action="store_true",
    )
    args = parser.parse_args()

    log_handler = logging.FileHandler(args.filename, mode="w+")
    logger = logging.getLogger()
    logger.addHandler(log_handler)
    logger.setLevel(logging.CRITICAL)

    logger.critical(Benchmark.header())

    max_stalkers = 3
    max_noise_percent = 50

    for (ae, fp, c, std_devs, agreement_override, degree) in [
        (4, 22, 10, 0, 825, 591),
        (60, 24, 9, 0, 59, 41),
    ]:
        for total_stalkers in [1, 2, 3]:

            setting_1 = (total_stalkers, 50)
            setting_2 = (0, (total_stalkers * 100) + 50)

            for real_stalkers, real_noise_percent in [setting_1, setting_2]:
                print(
                    f"{ae=}, {max_stalkers=}, {real_stalkers=}, {real_noise_percent=}"
                )
                benchmark_params(
                    logger=logger,
                    max_stalkers=max_stalkers,
                    real_stalkers=real_stalkers,
                    max_noise_percent=max_noise_percent,
                    real_noise_percent=real_noise_percent,
                    anonymity_epoch=ae,
                    detection_time=60 * 60,
                    deletion_percent=5,
                    delta=4,
                    previous_windows=23,
                    iterations=args.iterations,
                    timeout=-1,
                    f_power=fp,
                    c=c,
                    std_devs=std_devs,
                    instance_type=InstanceType.adversarial,
                    agreement_override=agreement_override,
                    degree=degree,
                    use_tqdm=args.use_tqdm,
                )
