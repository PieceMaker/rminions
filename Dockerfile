FROM r-base:latest
MAINTAINER Jonathan Adams <jd.adams16@gmail.com>

ENV REDIS "localhost"
ENV QUEUE "jobsQueue"

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
COPY ./runMinion.sh /R

RUN r -e 'install.packages("devtools")' \
    && r -e 'devtools::install("/R/rminions")' \
    && chmod +x /R/runMinion.sh \
    && rm -rf /R/rminions

CMD [ "/R/runMinion.sh" ]