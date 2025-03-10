#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root"
	exit
fi

apt install -y ansible

sudo -u "$SUDO_USER" ansible-playbook -K local.yml -t install --skip-tags build
