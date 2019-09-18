#!/bin/bash

set -e

if [[ "$1" = 'master' ]]; then

	: ${MESOS_ZK="zk://127.0.0.1:2181,127.0.0.2:2181,127.0.0.3:2181/mesos"}
	: ${MESOS_HOSTNAME="$(hostname)"}
	: ${MESOS_IP="$(hostname -i)"}
	: ${MESOS_MASTER_PORT="5050"}
	: ${MESOS_DIST_PORT="5049"}
	: ${MESOS_MASTER_QUORUM="2"}
	: ${MESOS_CLUSTER_NAME="cluster"}

	: ${DIST_DIR="/dist"}
	mkdir -p ${DIST_DIR}
	echo "Building mesos package..."
	tar -czf mesos.tar.gz -C /opt mesos
	mv mesos.tar.gz ${DIST_DIR}
	busybox httpd -p ${MESOS_DIST_PORT} -h ${DIST_DIR}
	echo "Mesos package available on http://${MESOS_IP}:${MESOS_DIST_PORT}/mesos.tar.gz"

    exec /opt/mesos/sbin/mesos-master --version=false \
                      --zk=${MESOS_ZK} \
                      --port=${MESOS_MASTER_PORT} \
                      --log_dir=/var/log/mesos \
                      --cluster=${MESOS_CLUSTER_NAME} \
                      --hostname=${MESOS_HOSTNAME} \
                      --ip=${MESOS_IP} \
                      --quorum=${MESOS_MASTER_QUORUM} \
                      --work_dir=/var/lib/mesos/master

else

	exec "$@"

fi

