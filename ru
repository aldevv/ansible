#!/bin/bash

if [ -n "$1" ]; then
    docker run -it -v "$PWD:/home/kanon/ansible" --rm boot ansible-playbook -t dotfiles-full -K --ask-vault-pass local.yml
else
    docker run -it -v "$PWD:/home/kanon/ansible" --rm boot bash
fi
