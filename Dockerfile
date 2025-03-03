#
# Gem compiling build container
#
FROM public.ecr.aws/docker/library/ruby:3.4-slim AS gem-compiler

RUN apt-get update && \
    apt-get install -y ca-certificates

RUN apt-get install -y build-essential
RUN apt-get install -y git

COPY build_files/app/Gemfile build_files/app/Gemfile.lock /app/

WORKDIR /app

RUN gem install bundler
RUN bundle install

#
# Container build copying in compliled artifacts from build image: Keep the container slim by not including build deps
#
FROM public.ecr.aws/docker/library/ruby:3.4-slim

RUN apt-get update && \
    apt-get install -y ca-certificates

RUN groupadd -g 100010 tunmesh && \
    useradd -m -u 100010 -g 100010 tunmesh

COPY --from=gem-compiler /usr/local/bundle /usr/local/bundle

COPY build_files/app/Gemfile build_files/app/Gemfile.lock /app/
WORKDIR /app
RUN bundle install

COPY build_files/ /
CMD ["bundle", "exec", "./bin/tun_mesh"]

ARG build_repo_sha
ARG build_version
RUN echo "${build_version} ${build_repo_sha} Build Date: $(date)" > /app/build_info.txt
