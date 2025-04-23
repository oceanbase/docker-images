FROM openanolis/anolisos AS builder

ARG VERSION

WORKDIR /root

RUN mkdir -p pkgs

ADD build/demo.yaml /root/

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo http://mirrors.oceanbase.com/oceanbase/OceanBase.repo && \
    yum install -y ob-deploy && \
    yum clean all

# download and clone all the required packages
RUN yum install -y --downloadonly --downloaddir=/root/pkgs oceanbase-ce-${VERSION}.el8 oceanbase-ce-libs-${VERSION}.el8
RUN obd mirror clone /root/pkgs/*.rpm
RUN obd env set IO_DEFAULT_CONFIRM 1
RUN obd mirror disable remote
RUN obd cluster deploy demo -c /root/demo.yaml

RUN rm -rf /root/demo/store && rm -rf /root/demo/etc
RUN cd /root/.obd && rm -rf log/obd && rm -rf /root/.obd/mirror/local/* && rm -rf /root/.obd/cluster
RUN find /root/.obd/repository -name "ob_admin" | xargs rm -rf
RUN find /root/.obd/repository -name "oblogminer" | xargs rm -rf

FROM openanolis/anolisos

WORKDIR /root
RUN yum install -y gettext ncurses-compat-libs openssh-server squashfs-tools && yum clean all

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo http://mirrors.oceanbase.com/oceanbase/OceanBase.repo && \
    yum install -y ob-deploy obclient ob-sysbench && \
    yum clean all

RUN obd env set IO_DEFAULT_CONFIRM 1
RUN obd mirror disable remote

RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''
RUN ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
RUN ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

COPY --from=builder /root/demo /root/demo
COPY --from=builder /root/.obd /root/.obd


COPY share/cluster /root/.obd/cluster
COPY share/etc.img /root/demo/etc.img
COPY share/store.img /root/demo/store.img
COPY share/empty_clog /root/empty_clog
COPY build/recover-clog.sh /root/recover-clog.sh
COPY templates /root/templates
COPY boot /root/boot

ENTRYPOINT ["bash", "-c", "/usr/sbin/sshd && /root/boot/start.sh"]
