# The same resulting image is used by Operator and Compose.
FROM quay.io/oceanbase/oceanbase-helper:2.4.0@sha256:df32d0d10ea3c16b941fcf15dbbf1e9de85205505a9077b5b882a7f9809c91ac AS helper
FROM scratch AS obshell-amd64
ADD --checksum=sha256:6f864be226bfd77ade853dd98b9848761d3e82f2fff277f273f54efaabfb781f https://mirrors.oceanbase.com/community/stable/el/7/x86_64/obshell-4.5.1.3-12026111915.el7.x86_64.rpm /obshell.rpm

FROM scratch AS obshell-arm64
ADD --checksum=sha256:3e4614bec54241c4218ebd321997f9fee42f9978a004e276b1383db4def2a38c https://mirrors.oceanbase.com/community/stable/el/7/aarch64/obshell-4.5.1.3-12026111915.el7.aarch64.rpm /obshell.rpm

FROM obshell-${TARGETARCH} AS obshell-rpm

FROM alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/alinux3@sha256:e5791e41fc76bcd6de81842fd808f07a12913869315f150c7b07f9ed28cef9e7
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=bind,source=oceanseek/install-runtime.sh,target=/tmp/install-runtime.sh \
    bash /tmp/install-runtime.sh
COPY --from=helper /home/admin/oceanbase/bin/oceanbase-helper /home/admin/oceanbase/bin/oceanbase-helper
COPY oceanseek/helper/LICENSE /usr/share/licenses/oceanbase-helper/LICENSE
ARG VERSION
ARG RPM_VERSION=${VERSION}.el7
RUN --mount=type=bind,source=oceanseek/rpms,target=/tmp/rpms \
    --mount=type=bind,source=oceanseek/verify-rpms.py,target=/tmp/verify-rpms.py \
    --mount=type=bind,source=oceanseek/install-product-rpms.sh,target=/tmp/install-product-rpms.sh \
    set -eu; \
    bash /tmp/install-product-rpms.sh oceanseek oceanseek-libs; \
    test "$(rpm -q --qf '%{VERSION}-%{RELEASE}' oceanseek)" = "${RPM_VERSION}"; \
    test "$(rpm -q --qf '%{VERSION}-%{RELEASE}' oceanseek-libs)" = "${RPM_VERSION}"; \
    test -x /home/admin/oceanbase/bin/observer; \
    test -x /home/admin/oceanbase/bin/oceanbase-helper; \
    command -v tar; \
    command -v pgrep; \
    command -v ps; \
    yum clean all
# The public RPM owns the same executable path as the bundled OceanSeek copy.
RUN --mount=type=bind,from=obshell-rpm,source=/obshell.rpm,target=/tmp/obshell.rpm \
    rpm -U --replacefiles /tmp/obshell.rpm \
    && test "$(/home/admin/oceanbase/bin/obshell version)" = "4.5.1.3-12026111915"
# Pin the final image timezone after RPM installation for both deployers.
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# Observer checks the owner of its local etc directory against the startup UID.
# Keep it consistent with this image's explicit root runtime for both deployers.
RUN chown 0:0 /home/admin/oceanbase/etc \
    && test "$(stat -c %u /home/admin/oceanbase/etc)" = "$(id -u)"
ENV LD_LIBRARY_PATH=/home/admin/oceanbase/lib
RUN dependencies="$(ldd /home/admin/oceanbase/bin/observer)" \
    && printf '%s\n' "${dependencies}" \
    && [[ "${dependencies}" != *"not found"* ]] \
    && version_output="$(/home/admin/oceanbase/bin/observer -V 2>&1)" \
    && revision="${RPM_VERSION#*-}" \
    && grep -F "REVISION: ${revision%%.*}-" <<< "$version_output"
WORKDIR /home/admin/oceanbase
EXPOSE 2881 2882 2886
ENTRYPOINT []
CMD ["/home/admin/oceanbase/bin/oceanbase-helper", "start"]
