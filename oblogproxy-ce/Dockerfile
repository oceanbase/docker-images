FROM openanolis/anolisos:8.8

ARG VERSION

RUN yum install -y yum-utils diffutils && \
    yum-config-manager --add-repo https://mirrors.oceanbase.com/oceanbase/OceanBase.repo && \
    sed -i 's/$releasever/8/' /etc/yum.repos.d/OceanBase.repo && \
    if [[ -z "${VERSION}" ]]; then \
      echo "VERSION is empty, build image with the latest rpm"; \
      version=`yum info oblogproxy | grep Version | awk '{print $3}'`; \
      release=`yum info oblogproxy | grep Release | awk '{print $3}' | awk -F. '{print $1}'`; \
      VERSION="${version}-${release}"; \
    fi && \
    yum install -y oblogproxy-${VERSION}.el8 && yum clean all

COPY start.sh /root/boot/
WORKDIR /root/boot/

EXPOSE 2983

ENTRYPOINT ["bash", "-c", "./start.sh"]
