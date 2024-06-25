 #!/bin/bash

if [[ -n ${OB_SYS_USERNAME} && -n ${OB_SYS_PASSWORD} ]]; then
  echo "y" | /usr/local/oblogproxy/run.sh config_sys ${OB_SYS_USERNAME} ${OB_SYS_PASSWORD}
fi

rm -rf /usr/local/oblogproxy/run/*
/usr/local/oblogproxy/run.sh start
exec /sbin/init
