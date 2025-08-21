FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash-completion \
        bison \
        bc \
        build-essential \
        cmake \
        curl \
        dstat \
        flex \
        gdb \
        git \
        libc6-dbg \
        libicu-dev \
        libreadline-dev \
        locales \
        pkg-config \
        tmux \
        valgrind \
        vim \
        wget \
        zlib1g \
        zlib1g-dev && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN adduser --disabled-password --gecos "" qihan && \
    echo 'qihan:123456' | chpasswd && \
    usermod -aG sudo qihan

RUN printf '\n# enable bash completion if available\nif [ -f /etc/bash_completion ] && ! shopt -oq posix; then\n  . /etc/bash_completion\nfi\n' >> /etc/bash.bashrc

USER qihan

CMD ["/bin/bash"]
