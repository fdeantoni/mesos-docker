# mesos-docker
A mesos docker image to run mesos master with mesos agent package 

# Building and Pushing

Create the docker image:

	$ sudo docker build -t jdoe/mesos:1.8.1 .
	
Push the docker image to the registry:

	$ sudo docker login
	$ sudo docker push jdoe/mesos:1.8.1

# Running

To run the master:

	$ docker run -d --net host \
	  -e MESOS_ZK="zk://127.0.0.1:2181,127.0.0.2:2181,127.0.0.3:2181/mesos" \
	  -e MESOS_HOSTNAME="localhost" \
	  -e MESOS_IP="127.0.0.1" \
	  -e MESOS_MASTER_PORT="5050" \
	  -e MESOS_MASTER_QUORUM="2" \
	  -e MESOS_CLUSTER_NAME="cluster" \
	  -e MESOS_DIST_PORT="5049" \
	  -v mesos-master-data:/var/lib/mesos \
	jdoe/mesos:1.8.1 master 
	
When the master is up and running, you can grab the mesos distribution package from: http://localhost:5049/mesos.tar.gz

# Installing Agent Package

To install the agent package downloaded from the master, you need to first install the necessary dependencies:

    $ sudo apt-get install libcurl4 libcurl4-openssl-dev libevent-dev libsvn1 libsasl2-modules curl
    
Unpack the downloaded `mesos.tar.gz` into a folder of your choosing (e.g. `/opt`):

    $ tar -zxvf mesos.tar.gz
    
and create a startup script (e.g. `/opt/mesos/agent-start.sh`) with the following content:

    #!/usr/bin/env bash
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/mesos/lib"
    
    MESOS_ZK=$(cat /etc/mesos-agent/zk)
    MESOS_HOSTNAME=$(cat /etc/mesos-agent/hostname)
    MESOS_IP=$( getent hosts ${MESOS_HOSTNAME} | awk '{ print $1 }' )
    MESOS_ATTRIBUTES=$(cat /etc/mesos-agent/attributes)
    MESOS_RESOURCES=$(cat /etc/mesos-agent/resources)
    MESOS_MODULES="/etc/mesos-agent/mesos-agent-modules.json"
    MESOS_WORK_DIR=$(cat /etc/mesos-agent/work_dir)
    MESOS_LOG_DIR=$(cat /etc/mesos-agent/log_dir)
    
    exec /opt/mesos/sbin/mesos-agent --version=false \
                     --master=${MESOS_ZK} \
                     --log_dir=${MESOS_LOG_DIR} \
                     --containerizers=docker,mesos \
                     --docker_stop_timeout=30secs \
                     --executor_registration_timeout=30mins \
                     --executor_shutdown_grace_period=60secs \
                     --hostname=${MESOS_HOSTNAME} \
                     --ip=${MESOS_IP} \
                     --attributes=${MESOS_ATTRIBUTES} \
                     --resources="${MESOS_RESOURCES}" \
                     --modules="${MESOS_MODULES}" \
                     --container_logger="org_apache_mesos_LogrotateContainerLogger" \
                     --work_dir="${MESOS_WORK_DIR}"
                     
The above startup script requires the package to be under `/opt/mesos` and various configuration files to exist under 
`/etc/mesos-agent`. You should adjust this as relevant to your scenario.                     

With this startup script in place you can create a service. Create a file `/etc/systemd/system/mesos-agent.service` 
with the following content:

    [Unit]
    Description=Mesos Agent
    After=network.target
    Wants=network.target
    
    [Service]
    ExecStart=/opt/mesos/agent-start.sh
    KillMode=process
    Restart=always
    RestartSec=20
    LimitNOFILE=16384
    CPUAccounting=true
    MemoryAccounting=true
    
    [Install]
    WantedBy=multi-user.target
    
After creating it, reload `systemd` to update the configuration:

    $ sudo systemctl daemon-reload
    
            