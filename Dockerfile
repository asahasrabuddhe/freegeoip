FROM golang:1.13-alpine AS builder

WORKDIR /go/src/freegeoip

COPY . .

RUN CGO_ENABLED=0 go build -o /go/bin/freegeoip cmd/freegeoip/main.go

FROM alpine:3.10

RUN apk add --no-cache git libcap shadow \
	&& addgroup -g 1000 -S freegeoip \
	&& adduser -u 1000 -S freegeoip -G freegeoip

COPY cmd/freegeoip/public /var/www

COPY --from=builder --chown=freegeoip:freegeoip /go/bin/freegeoip /usr/bin/freegeoip

USER freegeoip

ENTRYPOINT ["/usr/bin/freegeoip", "-use-x-forwarded-for"]

EXPOSE 8080

ENV QUOTA_MAX=0

# CMD instructions:
# Add  "-use-x-forwarded-for"      if your server is behind a reverse proxy
# Add  "-public", "/var/www"       to enable the web front-end
# Add  "-internal-server", "8888"  to enable the pprof+metrics server
#
# Example:
# CMD ["-use-x-forwarded-for", "-public", "/var/www", "-internal-server", "8888"]
