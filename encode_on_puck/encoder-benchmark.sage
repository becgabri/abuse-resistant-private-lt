from sage.all import GF, PolynomialRing

import json
from random import randrange

import time
import tqdm

def gen_id(c, field_size):
    chunked_id = [randrange(0, field_size) for _ in range(c)]
    return chunked_id

def random_polynomial(pR, degree, constant_term):
    p = pR.random_element(degree=degree)
    return p - p[0] + constant_term

def rotate(pR, c, degree, chunked_id):
    polys = []
    for i in range(c):
        polys.append(random_polynomial(pR, degree, chunked_id[i]))

    
    return polys

def broadcast(polys, field):
    x = field.random_element()
    while x == 0:
        x = field.random_element()

    return (x,  [p(x) for p in polys])

def benchmark_broadcast(pR, c, degree, field_size, field):
    chunked_id = gen_id(c, field_size)
    polys= rotate(pR, c, degree, chunked_id)
    start = time.time()
    broadcast(polys, field)
    end = time.time()
    return end - start


def benchmark_rotate(pR, c, field_size, degree):
    chunked_id = gen_id(c, field_size)
    start = time.time()
    rotate(pR, c, degree, chunked_id)
    end = time.time()
    return end - start

if __name__ == '__main__':

    # 4 sec ae
    f_power = 22
    field_size = (2 ** f_power).previous_prime()
    field = GF(field_size)
    pR = PolynomialRing(field, "z")
    c = 10
    degree = 591

    # 60 sec ae
    # f_power = 24
    # field_size = (2 ** f_power).previous_prime()
    # field = GF(field_size)
    # pR = PolynomialRing(field, "z")
    # c = 9
    # degree = 41

    

    iterations = 1000

    # Benchmarking Rotate
    runtimes = []
    for _ in tqdm.tqdm(range(iterations)):
        runtimes.append(benchmark_rotate(pR, c, field_size, degree))

    with open("laptop-final-4sec-GenPolynomials.json", "w+") as outfile:
        json.dump(runtimes, outfile)

    # Benchmarking broadcast
    runtimes = []
    for _ in tqdm.tqdm(range(iterations)):
        runtimes.append(benchmark_broadcast(pR, c, degree, field_size, field))

    # print(runtimes)
    with open("laptop-final-4sec-GenSecretShare.json", "w+") as outfile:
        json.dump(runtimes, outfile)