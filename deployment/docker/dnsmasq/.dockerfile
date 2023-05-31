FROM alpine:latest
RUN apk --no-cache add dnsmasq
VOLUME /var/dnsmasq
EXPOSE 53 53/udp
ENTRYPOINT ["dnsmasq","-d","-C","/var/dnsmasq/conf/dnsmasq.conf","-H","/var/dnsmasq/hosts"]