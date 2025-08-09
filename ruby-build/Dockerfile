ARG UBUNTU_VERSION=25.04

FROM ubuntu:${UBUNTU_VERSION}

ARG RUBY_BUILD_VERSION=20250724

RUN apt-get update -y

RUN apt-get install -y curl

WORKDIR /tmp

RUN curl -Lo ruby-build-v${RUBY_BUILD_VERSION}.tar.gz https://github.com/rbenv/ruby-build/archive/refs/tags/v${RUBY_BUILD_VERSION}.tar.gz
RUN tar -zxf ruby-build-v${RUBY_BUILD_VERSION}.tar.gz
RUN PREFIX=/usr/local sh -x ./ruby-build-${RUBY_BUILD_VERSION}/install.sh

RUN rm /tmp/ruby-build-v${RUBY_BUILD_VERSION}.tar.gz
RUN rm -r /tmp/ruby-build-${RUBY_BUILD_VERSION}/

# ruby-build dependencies, according to the ruby-build docs:
# citation: https://github.com/rbenv/ruby-build/wiki#ubuntudebianmint
RUN apt-get install -y build-essential autoconf libssl-dev libyaml-dev zlib1g-dev libffi-dev libgmp-dev rustc

ARG RUBY_VERSION=3.4.5

RUN ruby-build ${RUBY_VERSION} /opt/ruby/${RUBY_VERSION}
#COPY prepare.sh /tmp/prepare.sh
#RUN sh prepare.sh ${RUBY_VERSION}
