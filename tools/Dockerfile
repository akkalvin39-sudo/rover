FROM ubuntu:22.04

# install basic tools
RUN apt-get update && \
    apt-get install -y wget bzip2 unzip make cppcheck clang-format git && \
    rm -rf /var/lib/apt/lists/*

# create tools directory
RUN mkdir -p /home/ubuntu/dev/tools

WORKDIR /home/ubuntu/dev/tools

# download MSP430 GCC compiler
RUN wget -q https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2/msp430-gcc-9.3.1.11_linux64.tar.bz2 -O /tmp/msp430.tar.bz2 && \
    tar xjf /tmp/msp430.tar.bz2 -C /tmp && \
    mv /tmp/msp430-gcc-*linux64 msp430-gcc && \
    rm /tmp/msp430.tar.bz2

# download support files
RUN wget -q https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2/msp430-gcc-support-files-1.212.zip -O /tmp/support.zip && \
    unzip -q /tmp/support.zip -d /tmp && \
    cp -r /tmp/msp430-gcc-support-files/* /home/ubuntu/dev/tools/msp430-gcc/ && \
    rm -rf /tmp/support.zip /tmp/msp430-gcc-support-files*

# create CI user
RUN useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1001 ubuntu

USER ubuntu
WORKDIR /home/ubuntu