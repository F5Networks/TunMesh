FROM public.ecr.aws/docker/library/debian:bookworm

RUN apt-get update
RUN apt-get install -y bind9

# Nuke the Debian boilerplate as it's *heavily* opinionated in a non-standard way
RUN rm -r /etc/bind

RUN mkdir /run/named && \
    chown bind:bind /run/named && \
    chmod 750 /run/named

COPY build_files/ /

USER bind
CMD ["/usr/sbin/named", "-c", "/etc/bind/named.conf", "-f", "-L", "/dev/stdout", "-4"]
