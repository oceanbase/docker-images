FROM registry.openanolis.cn/openanolis/anolisos:8.9
WORKDIR /root
COPY VERSION /tmp/obdiag-version
ARG VERSION
RUN yum install -y yum-utils \
    && yum-config-manager --add-repo https://mirrors.aliyun.com/oceanbase/OceanBase.repo \
    && pinned_version="$(cat /tmp/obdiag-version)" \
    && test "${VERSION:-$pinned_version}" = "$pinned_version" \
    && yum install -y "oceanbase-diagnostic-tool-${pinned_version}.el8" \
    && test "$(rpm -q --qf '%{VERSION}-%{RELEASE}' oceanbase-diagnostic-tool)" = "${pinned_version}.el8" \
    && sh /opt/oceanbase-diagnostic-tool/init.sh \
    && yum clean all \
    && rm -f /tmp/obdiag-version
