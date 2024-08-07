FROM ubuntu:jammy AS base
WORKDIR /usr/local/bin
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common curl git build-essential unzip && \
    apt-add-repository -y ppa:ansible/ansible && \
    apt-get update && \
    apt-get install -y curl sudo git ansible build-essential python3-pip && \
    apt-get clean autoclean && \
    apt-get autoremove --yes

FROM base AS kanon
ENV USER=kanon
RUN addgroup --gid 1000 ${USER} \
    && adduser --gecos ${USER} --uid 1000 --gid 1000 --disabled-password ${USER} \
    && adduser ${USER} sudo \
        && echo "${USER}:pass" | chpasswd

USER kanon
RUN mkdir /home/${USER}/ansible \
  && python3 -m pip install github3.py
WORKDIR /home/${USER}/ansible
COPY . .

FROM kanon AS final
ARG TAGS
ENV TAGS="${TAGS:--t 'dotfiles,neovim,zsh,zsh_plugins' -K}"

CMD ["sh", "-c", "ansible-playbook $TAGS local.yml"]

