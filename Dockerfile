# Multistage docker file for problemtools
#
# Expected to be built with a build context which is the root of a checkout of problemtools
# Overview of steps:
#
# We have 4 targets which are only used locally in the build process, and are not
# uploaded to a repository.
#  - `runreqs`: Base image containing just the things needed to run problemtools
#  - `build`: Base image which builds a deb, contained in /deb/kattis-problemtools*.deb
#  - `icpclangs`: Base image containing what is needed to run problemtools, plus the "ICPC languages"
#  - `fulllangs`: Base image containing what is needed to run problemtools, plus all supported languages
# 
# We have 3 targets which are meant for end users:
#  - `minimal`: Image with problemtools installed, but no languages.
#  - `icpc`: Image with problemtools plus the "ICPC languages" installed.
#  - `full`: Image with problemtools and all languages
# 
# We have 1 image which is used in our CI (to speed up things - it takes a few
# minutes to apt-get install all languages and runtime requirements):
#  - `githubci`: Image with all languages and everything needed to build a deb and run problemtools
# 
# Build dependencies:
# ```
#      runreqs   -> icpclangs -> fullangs -> githubci
#      /     \          |           |
#  build    minimal    icpc        full
# ```

FROM ubuntu:24.04 AS runreqs

LABEL org.opencontainers.image.authors="contact@kattis.com"
ENV DEBIAN_FRONTEND=noninteractive

# Packages required to build and run problemtools
# For libgmp, we technically just need libgmpxx4ldbl here, but for readability
# (and since we need libgmp-dev in other images), we take libgmp-dev here
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
        dvisvgm \
        ghostscript \
        libgmp-dev \
        pandoc \
        python3 \
        python3-venv \
        texlive-fonts-recommended \
        texlive-lang-cyrillic \
        texlive-latex-extra \
        texlive-plain-generic \
        tidy


# ----------------------------------------------------------------------
# Docker image with the debian file (and a full source directory) in /deb
FROM runreqs AS build
ARG GITTAG=master

# Packages required to build and run problemtools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
        automake \
        build-essential \
        debhelper \
        dh-virtualenv \
        dpkg-dev \
        g++ \
        git \
        make \
        libboost-regex-dev
ENV SETUPTOOLS_SCM_PRETEND_VERSION_FOR_PROBLEMTOOLS=$GITTAG
RUN git config --global --add safe.directory /git/problemtools/.git
RUN --mount=type=bind,target=/git/problemtools \
    git clone --recurse-submodules /git/problemtools /deb/problemtools
RUN make -C /deb/problemtools builddeb



# ------------------------------------------------------------------------------
# Docker image with all packages needed to run a problemtools .deb, plus
# language support for the "ICPC languages" (C, C++, Java, Kotlin, and Python 3)

FROM runreqs AS icpclangs

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
        gcc \
        g++ \
        kotlin \
        openjdk-21-jdk \
        openjdk-21-jre \
        pypy3

# ----------------------------------------------------------------------
# Docker image with all packages needed to run a problemtools .deb, plus
# language support for all supported languages

FROM icpclangs AS fulllangs

# All languages, plus curl which we need to fetch pypy2
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
        curl \
        fp-compiler \
        gfortran \
        gnucobol \
        gccgo \
        ghc \
        gnustep-devel gnustep gnustep-make gnustep-common gobjc \
        lua5.4 \
        mono-complete \
        nodejs \
        ocaml-nox \
        php-cli \
        rustc \
        sbcl \
        scala \
        swi-prolog

# pypy2 is no longer packaged for Ubuntu, so download tarball (and check a sha256)
RUN curl -LO https://downloads.python.org/pypy/pypy2.7-v7.3.16-linux64.tar.bz2 \
    && echo '04b2fceb712d6f811274825b8a471ee392d3d1b53afc83eb3f42439ce00d8e07  pypy2.7-v7.3.16-linux64.tar.bz2' | sha256sum --check \
    && tar -xf pypy2.7-v7.3.16-linux64.tar.bz2 \
    && mv pypy2.7-v7.3.16-linux64 /opt/pypy \
    && ln -s /opt/pypy/bin/pypy /usr/bin/pypy \
    && rm pypy2.7-v7.3.16-linux64.tar.bz2


# ---------------------------------------------------------------
# Docker image with all deb packages needed for our github actions
#  - Building a problemtools deb
#  - Running verifyproblem on all examples

FROM fulllangs AS githubci

# Packages required to build and run problemtools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
        automake \
        build-essential \
        debhelper \
        dh-virtualenv \
        dpkg-dev \
        git \
        make \
        libboost-regex-dev


# -----------------------------------------------------
# Docker image with problemtools and no extra languages
FROM runreqs AS minimal
RUN --mount=type=bind,from=build,source=/deb,target=/deb \
    dpkg -i /deb/kattis-problemtools*.deb

# ----------------------------------------------------------------
# Basic problemtools docker image, containing problemtools and the
# "ICPC languages" (C, C++, Java, Kotlin, and Python 3)

FROM icpclangs AS icpc
RUN --mount=type=bind,from=build,source=/deb,target=/deb \
    dpkg -i /deb/kattis-problemtools*.deb

# ----------------------------------------------------------------
# Full problemtools docker image, containing problemtools and all
# supported programming languages.

FROM fulllangs AS full
RUN --mount=type=bind,from=build,source=/deb,target=/deb \
    dpkg -i /deb/kattis-problemtools*.deb

