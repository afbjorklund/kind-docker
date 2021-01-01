FROM scratch
ADD kind-linux-amd64 /usr/local/bin/kind
ADD docker-linux-amd64 /usr/bin/docker
CMD ["/usr/local/bin/kind"]
