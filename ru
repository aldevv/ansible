#!/bin/bash

if [ -n "$1" ]; then
    docker run -it -v "$PWD:/home/kanon/ansible" --rm boot $1
else
    docker run -it -v "$PWD:/home/kanon/ansible" --rm boot ansible-playbook local.yml --ask-vault-pass
fi
