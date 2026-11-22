# The same resulting image is used by Operator and Compose.
ARG HELPER_IMAGE
FROM scratch AS obshell-amd64
ADD --checksum=sha256:6f864be226bfd77ade853dd98b9848761d3e82f2fff277f273f54efaabfb781f https://mirrors.oceanbase.com/community/stable/el/7/x86_64/obshell-4.5.1.3-12026111915.el7.x86_64.rpm /obshell.rpm

FROM scratch AS obshell-arm64
ADD --checksum=sha256:3e4614bec54241c4218ebd321997f9fee42f9978a004e276b1383db4def2a38c https://mirrors.oceanbase.com/community/stable/el/7/aarch64/obshell-4.5.1.3-12026111915.el7.aarch64.rpm /obshell.rpm

FROM obshell-${TARGETARCH} AS obshell-rpm

FROM ${HELPER_IMAGE}
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG RPM_VERSION
RUN --mount=type=bind,source=oceanseek/rpms,target=/tmp/rpms \
    --mount=type=bind,source=oceanseek/verify-rpms.py,target=/tmp/verify-rpms.py \
    set -eu; \
    test -n "${RPM_VERSION}"; \
    cd /tmp/rpms; \
    python3 /tmp/verify-rpms.py /tmp/rpms; \
    duplicates="$(rpm -qp --qf '%{NAME}\n' ./*.rpm | sort | uniq -d)"; \
    test -z "${duplicates}"; \
    yum --disablerepo='*' install -y tar procps-ng ./*.rpm \
        || yum install -y tar procps-ng ./*.rpm; \
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
