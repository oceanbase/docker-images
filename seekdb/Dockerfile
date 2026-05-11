# syntax=docker/dockerfile:1.4
FROM quay.io/rockylinux/rockylinux:9.4

ARG VERSION
ARG TARGETPLATFORM

WORKDIR /var/lib/oceanbase
RUN yum install -y mysql procps && yum clean all

RUN --mount=type=bind,source=.,target=/build \
    if [[ ${TARGETPLATFORM} == 'linux/amd64' ]] ; then ARCH=x86_64 ; else ARCH=aarch64 ; fi ; \
    RPM=seekdb-${VERSION}.el9.${ARCH}.rpm ; \
    if [ -f /build/${RPM} ] ; then \
        yum install -y /build/${RPM} ; \
    else \
        yum install -y https://mirrors.aliyun.com/oceanbase/community/stable/el/9/${ARCH}/${RPM} ; \
    fi ; \
    yum clean all

COPY start.sh /root/
RUN chmod +x /root/start.sh
ENV REPORTER=docker-seekdb
ENTRYPOINT ["/root/start.sh"]

