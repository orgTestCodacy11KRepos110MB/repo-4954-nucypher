import msgpack
from random import SystemRandom
from py_ecc.secp256k1 import N, privtopub, ecdsa_raw_sign, ecdsa_raw_recover
from nkms.crypto import default_algorithm, pre_from_algorithm


class EncryptingKeypair(object):
    def __init__(self, privkey_bytes=None):
        self.pre = pre_from_algorithm(default_algorithm)

        if not privkey_bytes:
            self.priv_key = self.pre.gen_priv(dtype='bytes')
        else:
            self.priv_key = privkey_bytes
        self.pub_key = self.pre.priv2pub(self.priv_key)

    def encrypt(self, data, pubkey=None):
        """
        Encrypts the data provided.

        :param bytes data: The data to encrypt
        :param bytes pubkey: Pubkey to encrypt for

        :rtype: bytes
        :return: Encrypted ciphertext
        """
        if not pubkey:
            pubkey = self.pub_key
        return self.pre.encrypt(pubkey, data)

    def decrypt(self, enc_data):
        """
        Decrypts the data provided

        :param bytes enc_data: Decrypts the data provided

        :rtype: bytes
        :return: Decrypted plaintext
        """
        return self.pre.decrypt(self.priv_key, enc_data)

    def rekey(self, pubkey):
        """
        Generates a re-encryption key for the specified pubkey.

        :param bytes pubkey: The public key of the recipient

        :rtype: bytes
        :return: Re-encryption key for the specified pubkey
        """
        return self.pre.rekey(self.priv_key, pubkey)



class SigningKeypair(object):
    def __init__(self, privkey_bytes=None):
        self.secure_rand = SystemRandom()
        if privkey_bytes:
            self.priv_key = privkey_bytes
        else:
            # Key generation is random([1, N - 1])
            priv_number = self.secure_rand.randrange(1, N)
            self.priv_key = priv_number.to_bytes(32, byteorder='big')
        # Get the public component
        self.pub_key = privtopub(self.priv_key)

    def _vrs_msgpack_dump(self, v, r, s):
        v_bytes = v.to_bytes(1, byteorder='big')
        r_bytes = r.to_bytes(32, byteorder='big')
        s_bytes = s.to_bytes(32, byteorder='big')
        return msgpack.dumps((v_bytes, r_bytes, s_bytes))

    def _vrs_msgpack_load(self, msgpack_vrs):
        sig = msgpack.loads(msgpack_vrs)
        v = int.from_bytes(sig[0], byteorder='big')
        r = int.from_bytes(sig[1], byteorder='big')
        s = int.from_bytes(sig[2], byteorder='big')
        return (v, r, s)

    def sign(self, msghash):
        """
        Signs a hashed message and returns a msgpack'ed v, r, and s.

        :param bytes msghash: Hash of the message

        :rtype: Bytestring
        :return: Msgpacked bytestring of v, r, and s (the signature)
        """
        v, r, s = ecdsa_raw_sign(msghash, self.priv_key)
        return self._vrs_msgpack_dump(v, r, s)

    def verify(self, msghash, signature, pubkey=None):
        """
        Takes a msgpacked signature and verifies the message.

        :param bytes msghash: The hashed message to verify
        :param bytes signature: The msgpacked signature (v, r, and s)
        :param bytes pubkey: Pubkey to validate signature for
                             Default is the keypair's pub_key.

        :rtype: Boolean
        :return: Is the signature valid or not?
        """
        if not pubkey:
            pubkey = self.pub_key
        sig = self._vrs_msgpack_load(signature)
        # Generate the public key from the signature and validate
        # TODO: Look into fixed processing time functions for comparison
        verify_sig = ecdsa_raw_recover(msghash, sig)
        return verify_sig == pubkey