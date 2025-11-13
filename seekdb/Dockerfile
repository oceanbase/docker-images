FROM openanolis/anolisos:23

ARG TARGETARCH
ARG VERSION

WORKDIR /var/lib/oceanbase
RUN yum install -y mysql procps && yum clean all

RUN if [[ ${TARGETPLATFORM} == 'linux/amd64' ]] ; then yum install -y http://mirrors.aliyun.com/oceanbase/community/stable/el/9/x86_64/seekdb-${VERSION}.el9.x86_64.rpm ; else yum install -y
  http://mirrors.aliyun.com/oceanbase/community/stable/el/9/aarch64/seekdb-${VERSION}.el9.aarch64.rpm ; fi ; yum clean all

COPY start.sh /root/
RUN chmod +x /root/start.sh
ENTRYPOINT ["/root/start.sh"]

