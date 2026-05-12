#!/bin/bash
set -e

if [ -d /keys ]; then
    mkdir -p /home/tester/.ssh
    for f in /keys/*.pub; do
        if [ -f "$f" ]; then
            cat "$f" >> /home/tester/.ssh/authorized_keys
        fi
    done
    for f in /keys/id_*; do
        if [ -f "$f" ] && [[ "$(basename "$f")" != *.pub ]]; then
            cp "$f" /home/tester/.ssh/
            chmod 600 "/home/tester/.ssh/$(basename "$f")"
        fi
    done
    chmod 600 /home/tester/.ssh/authorized_keys
    chown -R tester:tester /home/tester/.ssh
fi

echo "=== hola-connect ==="
echo "  User:     tester / tester123"
echo "  Root:     root / root123"
echo "  SSH port: 22 (host: 2222)"
echo "  Connect:  ssh tester@localhost -p 2222"
echo "===================="

exec "$@"
