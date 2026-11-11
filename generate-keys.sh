#!/bin/bash
mkdir -p keys
ssh-keygen -t ed25519 -f keys/id_ed25519 -N "" -C "tunnel-connect-key"
echo "Keys generated in ./keys/"
