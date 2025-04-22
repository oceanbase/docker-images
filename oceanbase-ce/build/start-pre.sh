#!/bin/bash
/root/convert-sparse-files.sh /root/demo/store /tmp/store 
/root/handle-clog.sh > /root/empty_clog
cd /root/demo && tar -cf store.tar store && lz4 store.tar
cp -r /root/demo/store.tar.lz4 /root/share 
cp -r /root/demo/etc /root/share 
cp -r /root/.obd/cluster /root/share
cp -r /root/empty_clog /root/share 
cp -r /root/demo/store /root/share 
