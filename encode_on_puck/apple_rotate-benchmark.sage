
import base64
import json
import time

import tqdm
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.x963kdf import X963KDF
from sage.all import GF, EllipticCurve, Integer


def get_p224():
    # Setup
    p = 0xffffffffffffffffffffffffffffffff000000000000000000000001
    K = GF(p)
    a = K(0xfffffffffffffffffffffffffffffffefffffffffffffffffffffffe)
    b = K(0xb4050a850c04b3abf54132565044b0b7d7bfd8ba270b39432355ffb4)
    E = EllipticCurve(K, (a, b))
    G = E(0xb70e0cbd6bb4bf7f321390b94a03c1d356c21122343280d6115c1d21, 0xbd376388b5f723fb4c22dfe6cd4375a05a07476444d5819985007e34)
    E.set_order(0xffffffffffffffffffffffffffff16a2e0b8f03e13dd29455c5c2a3d * 0x1)

    return (E, G)

def rotate(KDF1, KDF2, SK_i_minus_1, G, d_0):
    SK_i = KDF1.derive(SK_i_minus_1)
    result = KDF2.derive(SK_i)
    u_i = Integer(int.from_bytes(result[:36]))
    v_i = Integer(int.from_bytes(result[36:]))

    d_i = (d_0 * u_i) + v_i
    p_i = Integer(d_i) * G
    return p_i

def run_benchmark(E, G):
    d_0 = GF(E.order()).random_element()
    SK_i_minus_1 = base64.urlsafe_b64decode(Fernet.generate_key())

    KDF1 = X963KDF(
        algorithm=hashes.SHA256(),
        length=32,
        sharedinfo=b"update"
    )
    KDF2 = X963KDF(
        algorithm=hashes.SHA256(),
        length=72,
        sharedinfo=b"diversify"
    )

    start = time.time()
    rotate(KDF1, KDF2, SK_i_minus_1, G, d_0)
    end = time.time()
    return end - start

if __name__ == '__main__':
    # Setup params
    (E, G) = get_p224()

    runtimes = []
    for _ in tqdm.tqdm(range(1000)):
        runtimes.append(run_benchmark(E, G))
    
    with open("apple-rotate.json", "w+") as outfile:
        json.dump(runtimes, outfile)