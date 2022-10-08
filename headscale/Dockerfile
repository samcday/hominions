FROM headscale/headscale:0.16 as headscale

FROM alpine:20220715
COPY --from=headscale /bin/headscale /bin/headscale
COPY config.yaml /etc/headscale/config.yaml
CMD ["/bin/headscale", "serve"]
