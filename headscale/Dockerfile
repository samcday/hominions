FROM headscale/headscale:0.16 as headscale
FROM litestream/litestream:0.3 as litestream

FROM alpine:20220715
COPY --from=headscale /bin/headscale /bin/headscale
COPY --from=litestream /usr/local/bin/litestream /bin/litestream
COPY config.yaml /etc/headscale/config.yaml
COPY litestream.yml /etc/litestream.yml
COPY acls.yaml /opt/acls.yaml
CMD ["/bin/litestream", "replicate", "--exec", "/bin/headscale serve"]
