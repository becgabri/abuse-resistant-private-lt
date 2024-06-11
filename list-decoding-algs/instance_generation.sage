import random

from sage.all import GF, PolynomialRing, shuffle

def random_non_zero_element(field):
    elt = field.random_element()
    while elt == 0:
        elt = field.random_element()
    return elt


def gen_unique_elements(field, n):
    evaluation_points = []
    for i in range(n):
        elt = field.random_element()
        while elt in evaluation_points:
            elt = field.random_element()
        evaluation_points.append(elt)
    return evaluation_points


def random_polynomial(pR, degree):
    z = pR.gens()[0]
    return pR.random_element(degree=degree - 1) + z ^ degree


def gen_adversarial_instance(field, pR, ell=6, c=3, evals=[12, 12, 1]):
    m = len(evals) - 1  # number of polynomial sets
    n = sum(evals)
    f_list = [[random_polynomial(pR, ell) for i in range(c)] for j in range(m)]
    eval_points = gen_unique_elements(field, n)
    codeword = []
    i = 0
    for k in range(m):
        for j in range(evals[k]):
            codeword.append(
                [eval_points[i], list(fi(eval_points[i]) for fi in f_list[k]), k]
            )
            i += 1
    for j in range(evals[-1]):
        codeword.append(
            [eval_points[i], list(field.random_element() for fi in range(c)), -1]
        )
        i += 1
    return f_list, codeword


def gen_noise_points(field, c, n):
    return [
        [field.random_element(), [field.random_element() for _ in range(c)], -1]
        for _ in range(n)
    ]


def gen_simulated_instance(
    field,
    pR,
    ell,
    c=1,
    num_stalkers=3,
    anonymity_epoch=4,
    delta=4,
    detection_time=3600,
    deletion_percent=5,
    num_noise_points=0,
    previous_windows=23,
):
    if anonymity_epoch % delta != 0:
        raise ValueError(
            f"delta ({delta}) must divide the anonymity epoch ({anonymity_epoch})."
        )
    if detection_time % anonymity_epoch != 0:
        raise ValueError(
            f"anonymity_epoch ({anonymity_epoch}) must divide detection time "
            f"({detection_time})."
        )
    broadcasts_per_anonymity_epoch = anonymity_epoch // delta
    num_anonymity_epochs = detection_time // anonymity_epoch

    used_eval_points = set()
    for _ in range(previous_windows * num_anonymity_epochs):
        used_eval_points.add(random_non_zero_element(field))

    stalker_broadcasts = []
    for stalker in range(num_stalkers):
        # Create a polynomial for the stalker
        stalker_polys = [random_polynomial(pR, ell) for _ in range(c)]
        for _ in range(num_anonymity_epochs):
            # Generate the evaluation point for this anonymity epoch
            eval_point = random_non_zero_element(field)

            if eval_point not in used_eval_points:
                broadcast = [
                    eval_point,
                    [poly(eval_point) for poly in stalker_polys],
                    stalker,
                ]
            else:
                broadcast = [eval_point, [field.random_element() for _ in range(c)], -1]
            used_eval_points.add(eval_point)

            for _ in range(broadcasts_per_anonymity_epoch):
                # Simulate the channel dropping a percentage of broadcasts by only
                # appending the broadcast with a 1 - deletion_percent chance
                if random.randint(1, 100) > deletion_percent:
                    stalker_broadcasts.append(broadcast)

    noise_points = gen_noise_points(field, c, num_noise_points)

    all_broadcasts = stalker_broadcasts + noise_points
    shuffle(all_broadcasts)

    return all_broadcasts


if __name__ == "__main__":
    field = GF((2 ** 20).previous_prime())
    pR = PolynomialRing(field, "z")
    iterations = 100
    num_stalkers = 1

    point_counts = []
    for _ in range(iterations):
        codeword = gen_simulated_instance(
            field=field,
            pR=pR,
            ell=1, # doesn't matter for simulation
            c=1, # doesn't matter for simulation
            num_stalkers=num_stalkers,
            anonymity_epoch=4,
            delta=4,
            detection_time=3600,
            deletion_percent=5,
            num_noise_points=0,
            previous_windows=23
        )

        seen_xs = set()
        new_codeword = []
        for symbol in codeword:
            if symbol[0] not in seen_xs:
                new_codeword.append(symbol)
            seen_xs.add(symbol[0])

        for stalker in range(num_stalkers):
            point_counts.append(len(list(filter(lambda pt: pt[2] == stalker, new_codeword))))
    
    print(sum(point_counts)/len(point_counts))
        
