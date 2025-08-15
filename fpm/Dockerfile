ARG IMAGE=ubuntu:24.04
ARG FPM_VERSION=1.16.0

FROM ${IMAGE}

WORKDIR /tmp
COPY build.sh /tmp/build.sh
RUN sh /tmp/build.sh setup-dependencies "${FPM_VERSION}"
RUN sh /tmp/build.sh setup-fpm "${FPM_VERSION}"
RUN sh /tmp/build.sh patch "${FPM_VERSION}"
RUN sh /tmp/build.sh package "${FPM_VERSION}"
RUN sh /tmp/build.sh osinfo "${FPM_VERSION}"