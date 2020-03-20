#!/bin/bash

pip install cryptography --user > /dev/null
FERNETKEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
echo $FERNETKEY
