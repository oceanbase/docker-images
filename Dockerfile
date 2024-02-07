FROM openanolis/anolisos

# docker build --build-arg VERSION={VERSION} .
ARG VERSION

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo https://mirrors.aliyun.com/oceanbase/OceanBase.repo && \
    sed -i 's/$releasever/7/' /etc/yum.repos.d/OceanBase.repo && \
    yum install -y ob-deploy obclient ob-sysbench libaio bc libselinux-utils zip && \
    rm -rf /usr/obd/mirror/remote/* && \
    yum clean all

ENV OBVersion=$VERSION
RUN if [ -z "${OBVersion}" ]; then \
      echo "VERSION is empty, then build the docker with latest rpm"; \
      VersionPre=`yum info oceanbase-ce | grep Version | awk '{print $3}'`; \
      Release=`yum info oceanbase-ce | grep Release | awk '{print $3}' | awk -F. '{print $1}'`; \
      OBVersion="${VersionPre}-${Release}"; \
    else \
      echo "build the docker with VERSION ${OBVersion}"; \
    fi && \
    mkdir -p /root/pkg && \
    cd /root/pkg && \
    yum install -y --downloadonly --downloaddir=. oceanbase-ce-${OBVersion}.el7 oceanbase-ce-libs-${OBVersion}.el7 obagent ob-configserver && \
    rm -rf /usr/obd/mirror/remote/* && \
    yum clean all

COPY boot /root/boot/
ENV PATH /root/boot:$PATH
ENV LD_LIBRARY_PATH /root/ob/lib:$LD_LIBRARY_PATH

WORKDIR /root
CMD _boot

EXPOSE 2881
