ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS runtime
RUN apt-get -o Acquire::Retries=3 update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /licenses/runtime-doc /licenses/common /usr/share/doc/oceanbase-minio \
    && cp -a /usr/share/doc/. /licenses/runtime-doc/ \
    && cp -a /usr/share/common-licenses/. /licenses/common/ \
    && dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\t${source:Package}\t${source:Version}\n' \
       > /usr/share/doc/oceanbase-minio/runtime-packages.txt
ARG DISTRIBUTION_SOURCE
ARG DISTRIBUTION_REVISION
LABEL org.opencontainers.image.source="${DISTRIBUTION_SOURCE}" \
      org.opencontainers.image.revision="${DISTRIBUTION_REVISION}" \
      org.opencontainers.image.vendor="OceanBase" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later"
ENV MC_CONFIG_DIR=/tmp/.mc
COPY docs/ /usr/share/doc/oceanbase-minio/
COPY licenses/ /licenses/distribution/

FROM runtime AS minio
ARG MINIO_COMMIT
ARG MINIO_VERSION
LABEL io.oceanbase.upstream.revision="${MINIO_COMMIT}" \
      org.opencontainers.image.version="${MINIO_VERSION}-test" \
      io.oceanbase.source.patch="none" \
      org.opencontainers.image.description="Unmodified MinIO community source; independent test build, not an official MinIO image or AIStor."
COPY bin/minio bin/mc /usr/bin/
COPY src/minio/LICENSE src/minio/CREDITS /licenses/minio/
COPY src/mc/LICENSE src/mc/CREDITS /licenses/mc/
COPY src/minio/dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/bin/minio /usr/bin/mc /usr/bin/docker-entrypoint.sh \
    && mkdir -p /data && chmod 0777 /data
EXPOSE 9000 9001
VOLUME ["/data"]
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]

FROM runtime AS mc
ARG MC_COMMIT
ARG MC_VERSION
LABEL io.oceanbase.upstream.revision="${MC_COMMIT}" \
      org.opencontainers.image.version="${MC_VERSION}-test" \
      org.opencontainers.image.description="Unmodified MinIO mc community source; independent OceanBase test build, not an official MinIO image."
COPY bin/mc /usr/bin/mc
COPY bin/deployment-guard bin/known-object-get.sh /usr/local/bin/
COPY src/mc/LICENSE src/mc/CREDITS /licenses/mc/
ENTRYPOINT ["/usr/bin/mc"]
