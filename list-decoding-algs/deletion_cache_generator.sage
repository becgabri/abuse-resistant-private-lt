from sage.all import *

import json

def get_min_deletions_for_ninety_percent_of_cases(pdp, pps):
    total = 0
    min_deletions = 0
    while total < 0.995:
        # print(min_deletions, total)
        total += binomial(pps, min_deletions) * (pdp ** min_deletions) * ((1 - pdp) ** (pps - min_deletions))
        min_deletions += 1

    return min_deletions - 1


if __name__ == '__main__':
    previous_windows = 23
    num_stalkers = 3
    noise_rate = 0.5

    min_win = 2


    data = {}
    for ae in [2, 4, 60, 900]:
        ae_data = {}

        pps = 60 * 60 / ae
        if ae == 2:
            bpp = 1
        else:
            bpp = ae / 4


        print(f"ae: {ae}, pps: {pps}, bpp: {bpp}")

        channel_pdp = (0.05) ** bpp
        ae_data['channel'] = float(get_min_deletions_for_ninety_percent_of_cases(channel_pdp, pps))

        collision_data = {}
        for fp in range(8, 33):
            field_size = Integer(2 ** fp).previous_prime()

            point_survival_prob = (
                ((field_size - 1) / field_size)
                ** (((previous_windows + num_stalkers + noise_rate) * pps) - 1)
            )

            pdp = 1 - point_survival_prob


            collision_data[int(fp)] = float(get_min_deletions_for_ninety_percent_of_cases(pdp, pps))

        ae_data['collisions'] = collision_data
        data[int(ae)] = ae_data

    with open('cache-4.json', 'w+') as outfile:
        json.dump(data, outfile, indent=2)

