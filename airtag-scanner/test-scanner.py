import binascii
import unittest

import scanner


class TestScanner(unittest.TestCase):
    def test_get_public_key(self):
        mac = "CF:00:00:00:00:FF"
        pub_key_bytes_6_to_27 = ([0] * 20) + ([255] * 2)

        pub_key_bits_0_to_1 = 1

        pubkey = binascii.unhexlify("4F" + ("00" * 4) + "FF" + "00" * 20 + "FF" * 2)

        result = scanner.get_public_key(mac, pub_key_bytes_6_to_27, pub_key_bits_0_to_1)

        assert result == pubkey
