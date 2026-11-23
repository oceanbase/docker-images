# The same resulting image is used by Operator and Compose.
FROM quay.io/oceanbase/oceanbase-helper:2.4.0@sha256:df32d0d10ea3c16b941fcf15dbbf1e9de85205505a9077b5b882a7f9809c91ac AS helper
FROM alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/alinux3@sha256:e5791e41fc76bcd6de81842fd808f07a12913869315f150c7b07f9ed28cef9e7
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=bind,source=oceanseek/install-runtime.sh,target=/tmp/install-runtime.sh \
    bash /tmp/install-runtime.sh
COPY --from=helper /home/admin/oceanbase/bin/oceanbase-helper /home/admin/oceanbase/bin/oceanbase-helper
COPY oceanseek/helper/LICENSE /usr/share/licenses/oceanbase-helper/LICENSE
ARG VERSION
RUN set -eu; \
    test -n "$VERSION"; \
    arch=$(rpm --eval '%{_arch}'); \
    mirror="https://mirrors.oceanbase.com/community/stable/el/7/$arch"; \
    yum install -y \
        "$mirror/oblogservice-ce-${VERSION}.el7.$arch.rpm"; \
    test "$(rpm -q --qf '%{VERSION}-%{RELEASE}' oblogservice-ce)" = "${VERSION}.el7"; \
    test -x /home/admin/oblogservice/bin/oblogservice; \
    test -x /home/admin/oceanbase/bin/oceanbase-helper; \
    ln -s /home/admin/oceanbase/bin/oceanbase-helper /home/admin/oblogservice/bin/oceanbase-helper; \
    command -v tar; \
    command -v pgrep; \
    command -v ps; \
    yum clean all
# Pin the final image timezone after RPM installation for both deployers.
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN dependencies="$(ldd /home/admin/oblogservice/bin/oblogservice)" \
    && printf '%s\n' "${dependencies}" \
    && [[ "${dependencies}" != *"not found"* ]]
WORKDIR /home/admin/oblogservice
EXPOSE 50051 50052
ENTRYPOINT []
CMD ["/home/admin/oblogservice/bin/oceanbase-helper", "logservice", "start"]
