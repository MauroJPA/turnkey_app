# Imagem do servidor gc_turnkey: PocketBase + hooks + migrations + app web.
# Funciona em amd64 e arm64 (o binario certo e descarregado e o SHA-256
# conferido com o publicado na release).
FROM alpine:3.20

ARG TARGETARCH
ARG PB_VERSION=0.40.4

RUN apk add --no-cache ca-certificates tzdata wget unzip qpdf \
 && case "${TARGETARCH:-amd64}" in \
      amd64) A=amd64 ;; \
      arm64) A=arm64 ;; \
      *) echo "arquitetura nao suportada: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && F="pocketbase_${PB_VERSION}_linux_${A}.zip" \
 && B="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}" \
 && wget -q "${B}/${F}" -O "/tmp/${F}" \
 && wget -q "${B}/checksums.txt" -O /tmp/checksums.txt \
 && (cd /tmp && grep " ${F}\$" checksums.txt | sha256sum -c -) \
 && mkdir -p /pb \
 && unzip -q "/tmp/${F}" pocketbase -d /pb \
 && chmod +x /pb/pocketbase \
 && rm -f /tmp/*

COPY hooks /pb/pb_hooks
COPY migrations /pb/pb_migrations
COPY web /pb/pb_public

WORKDIR /pb
ENV GC_TURNKEY_DEV=0 \
    TZ=Europe/Lisbon
EXPOSE 8090

ENTRYPOINT ["/pb/pocketbase"]
CMD ["serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data", \
     "--migrationsDir=/pb/pb_migrations", "--hooksDir=/pb/pb_hooks", \
     "--publicDir=/pb/pb_public"]
