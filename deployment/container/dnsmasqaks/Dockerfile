FROM alpine:3.18.0
RUN apk --no-cache add dnsmasq
VOLUME /var/dnsmasq
EXPOSE 53 53/udp
# Start dnsmaq with the following parameters:
ENTRYPOINT ["dnsmasq","-d","-C","/var/dnsmasq/conf/dnsmasq.conf","-H","/var/dnsmasq/hosts"]
