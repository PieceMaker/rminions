FROM r-base:latest
MAINTAINER Jonathan Adams <jd.adams16@gmail.com>

RUN apt-get update \
    && apt-get install -y \
        libcurl4-openssl-dev \
        libssl-dev \
        libssh2-1-dev\
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /R
WORKDIR /R
COPY . /R

RUN r -e 'install.packages("devtools")' \
    && r -e 'devtools::install()'

CMD [ "/bin/bash" ]