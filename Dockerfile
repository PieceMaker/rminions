FROM r-base:latest
MAINTAINER Jonathan Adams <jd.adams16@gmail.com>

ENV REDIS "localhost"
ENV QUEUE "jobsQueue"
ENV PORT 6379
ENV USEJSON "false"

RUN apt-get update \
    && apt-get install -y \
        libcurl4-openssl-dev \
        libssl-dev \
        libssh2-1-dev\
        libxml2-dev \
        libgit2-dev \
        libhiredis-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /R/rminions
COPY . /R/rminions

RUN r -e 'install.packages("devtools")' \
    && r -e 'devtools::install("/R/rminions")' \
    && rm -rf /R/rminions

COPY ./runMinion.sh /R
RUN chmod +x /R/runMinion.sh

CMD [ "/R/runMinion.sh" ]