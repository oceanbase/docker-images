 #!/bin/bash

if [[ -n ${OB_SYS_USERNAME} && -n ${OB_SYS_PASSWORD} ]]; then
  echo "y" | /usr/local/oblogproxy/run.sh config_sys ${OB_SYS_USERNAME} ${OB_SYS_PASSWORD}
fi

/usr/local/oblogproxy/run.sh start
echo "boot success!" && exec /sbin/init
