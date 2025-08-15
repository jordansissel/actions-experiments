ARG IMAGE=ubuntu:24.04
ARG FPM_VERSION=1.16.0

FROM ${IMAGE} AS prepare

WORKDIR /tmp
COPY build.sh /tmp/build.sh
RUN sh /tmp/build.sh refresh-packages "${FPM_VERSION}"

FROM prepare AS build
RUN sh /tmp/build.sh setup-dependencies "${FPM_VERSION}"
RUN sh /tmp/build.sh setup-fpm "${FPM_VERSION}"
RUN sh /tmp/build.sh patch "${FPM_VERSION}"
RUN sh /tmp/build.sh package "${FPM_VERSION}"
RUN sh /tmp/build.sh buildinfo "${FPM_VERSION}"

FROM prepare
COPY --from=build /tmp/target /tmp/target