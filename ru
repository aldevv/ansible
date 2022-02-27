#!/bin/bash

if [ -n "$1" ]; then
    docker run -it -v "$PWD:/home/kanon" --rm boot bash
else
    docker run -it -v "$PWD:/home/kanon" --rm boot ansible-playbook local.yml --ask-vault-pass
fi
