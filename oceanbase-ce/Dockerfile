FROM --platform=$BUILDPLATFORM openanolis/anolisos as builder

ARG VERSION

WORKDIR /root

COPY build /root/build
RUN mkdir -p pkgs

RUN yum install -y yum-utils && \
    yum-config-manager --add-repo http://mirrors.oceanbase.com/oceanbase/OceanBase.repo && \
    sed -i 's/$releasever/7/' /etc/yum.repos.d/OceanBase.repo && \
    yum install -y ob-deploy && \
    yum clean all

# download and clone all the required packages
RUN yum install -y --downloadonly --downloaddir=/root/pkgs oceanbase-ce-${VERSION}.el7 oceanbase-ce-libs-${VERSION}.el7 obagent ob-configserver
RUN obd mirror clone /root/pkgs/*.rpm
RUN obd env set IO_DEFAULT_CONFIRM 1
RUN obd mirror disable remote
RUN obd cluster deploy demo -c build/deploy.yaml
RUN obd cluster destroy -f demo

RUN obd demo -c oceanbase-ce --oceanbase-ce.home_path=/root/demo --oceanbase-ce.scenario=express_oltp --oceanbase-ce.datafile_size=256M --oceanbase-ce.log_disk_size=5G && obd cluster tenant create demo -n test -o express_oltp 
RUN obd cluster stop demo
RUN cd /root/demo && tar -cvzf store.tar.gz store
RUN rm -rf /root/demo/store && rm -rf /root/demo/log/* && rm -rf /root/demo/log_obshell/* && rm -rf /root/demo/etc/*.py && rm -rf /root/demo/etc/obshell && rm -rf /root/demo/etc/*.sql && rm -rf /root/demo/etc/*.log && rm -rf /root/demo/run/*
RUN cd /root/.obd && rm -rf log/obd && tar -cvzf repository.tar.gz repository && rm -rf /root/.obd/repository && rm -rf /root/.obd/mirror/local/*

FROM --platform=$BUILDPLATFORM openanolis/anolisos

WORKDIR /root
RUN yum install -y yum-utils && \
    yum-config-manager --add-repo http://mirrors.oceanbase.com/oceanbase/OceanBase.repo && \
    sed -i 's/$releasever/7/' /etc/yum.repos.d/OceanBase.repo && \
    yum install -y ob-deploy obclient ob-sysbench gettext ncurses-compat-libs openssh-server && \
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
COPY --from=builder /root/demo/store.tar.gz /root/demo
COPY --from=builder /root/.obd /root/.obd
COPY boot /root/boot
COPY templates /root/templates

ENTRYPOINT ["bash", "-c", "/usr/sbin/sshd && /root/boot/start.sh"]
