FROM nginx:stable-alpine@sha256:61f816887864af764259e28edb5331584ae2e42de57b3cb1e4f134d757559951

RUN addgroup -g 1000 abc \
 && adduser -u 1000 -G abc -D -H abc \
 && chown -R abc:abc /var/cache/nginx /var/log/nginx /tmp /etc/nginx

COPY rootfs /

USER abc

CMD ["nginx", "-g", "daemon off;"]
