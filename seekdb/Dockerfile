FROM quay.io/rockylinux/rockylinux:9.4

ARG VERSION
ARG TARGETPLATFORM

WORKDIR /var/lib/oceanbase
RUN yum install -y mysql procps && yum clean all

RUN if [[ ${TARGETPLATFORM} == 'linux/amd64' ]] ; then yum install -y https://mirrors.aliyun.com/oceanbase/community/stable/el/9/x86_64/seekdb-${VERSION}.el9.x86_64.rpm ; else yum install -y https://mirrors.aliyun.com/oceanbase/community/stable/el/9/aarch64/seekdb-${VERSION}.el9.aarch64.rpm ; fi ; yum clean all;

COPY start.sh /root/
RUN chmod +x /root/start.sh
ENV REPORTER=docker-seekdb
ENTRYPOINT ["/root/start.sh"]

