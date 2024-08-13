from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes
import base64
from os import urandom

with open("public.pem", "rb") as key_file:
    public_key = serialization.load_pem_public_key(
        key_file.read(),
        backend=default_backend()
    )

with open("/home/feliks/.config/rclone/rclone.conf", "rb") as conf_file:
    conf_data = conf_file.read()

# Generate a random symmetric key
symmetric_key = urandom(32)  # AES-256 key

print(symmetric_key)

# Encrypt the symmetric key using the public key
encrypted_key = public_key.encrypt(
    symmetric_key,
    padding.OAEP(
        mgf=padding.MGF1(algorithm=hashes.SHA256()),
        algorithm=hashes.SHA256(),
        label=None
    )
)

print(encrypted_key)


# Encrypt the data using AES
cipher = Cipher(algorithms.AES(symmetric_key), modes.CFB8(urandom(16)))
encryptor = cipher.encryptor()
ciphertext = encryptor.update(conf_data) + encryptor.finalize()

# Encode the encrypted key and ciphertext to base64 to make it easy to handle
encoded_key = base64.b64encode(encrypted_key).decode('utf-8')
encoded_data = base64.b64encode(ciphertext).decode('utf-8')

print(f"Encrypted Key: {encoded_key}")
print(f"Encrypted Data: {encoded_data}")