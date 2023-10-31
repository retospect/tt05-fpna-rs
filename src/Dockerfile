FROM ubuntu
MAINTAINER retospect
ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt update
RUN apt -y install openssh-client python3 python3-pip iverilog verilator git gtkwave
RUN pip install cocotb pytest

