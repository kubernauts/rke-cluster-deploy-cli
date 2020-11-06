#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Please supply racher server url and cluster name prefix.."
  exit 1
fi
RANCHER_SERVER=$1
CLUSTER_NAME=$2
echo "Enter your credentials for ${RANCHER_SERVER}"
echo -n Username: 
read username
echo -n Password: 
read -s password
echo
# Fetch Login Token --Need to isntall jq package for windows can download jq.exe and and place the same under usr/bin of git installation directory--
LOGINRESPONSE=`curl -s ''$RANCHER_SERVER'/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"'$username'","password":"'$password'","description":"automation"}' --insecure`
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
# Create API key
APIRESPONSE=`curl -s ''$RANCHER_SERVER'/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"current":false,"enabled":true,"expired":false,"isDerived":false,"ttl":1800000,"type":"token","description":"automation"}' --insecure`
# Extract and store token
APITOKEN=`echo $APIRESPONSE | jq -r .token`
# Create cluster for now using flannel and kubernetes version as v1.19.3-rancher1-1
CLUSTERRESPONSE=`curl -s ''$RANCHER_SERVER'/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"dockerRootDir":"/var/lib/docker","enableClusterAlerting":false,"enableClusterMonitoring":false,"enableNetworkPolicy":false,"windowsPreferedCluster":false,"type":"cluster","name":"'$CLUSTER_NAME'","rancherKubernetesEngineConfig":{"addonJobTimeout":30,"ignoreDockerVersion":true,"sshAgentAuth":false,"type":"rancherKubernetesEngineConfig","kubernetesVersion":"v1.19.3-rancher1-1","authentication":{"strategy":"x509","type":"authnConfig"},"dns":{"type":"dnsConfig","nodelocal":{"type":"nodelocal","ip_address":"","node_selector":null,"update_strategy":{}}},"network":{"mtu":0,"plugin":"flannel","type":"networkConfig","options":{"flannel_backend_type":"vxlan"}},"ingress":{"provider":"nginx","type":"ingressConfig"},"monitoring":{"provider":"metrics-server","replicas":1,"type":"monitoringConfig"},"services":{"type":"rkeConfigServices","kubeApi":{"alwaysPullImages":false,"podSecurityPolicy":false,"serviceNodePortRange":"30000-32767","type":"kubeAPIService"},"etcd":{"creation":"12h","extraArgs":{"heartbeat-interval":500,"election-timeout":5000},"gid":0,"retention":"72h","snapshot":false,"uid":0,"type":"etcdService","backupConfig":{"enabled":true,"intervalHours":12,"retention":6,"safeTimestamp":false,"type":"backupConfig"}}},"upgradeStrategy":{"maxUnavailableControlplane":"1","maxUnavailableWorker":"10%","drain":"false","nodeDrainInput":{"deleteLocalData":false,"force":false,"gracePeriod":-1,"ignoreDaemonSets":true,"timeout":120,"type":"nodeDrainInput"},"maxUnavailableUnit":"percentage"}},"localClusterAuthEndpoint":{"enabled":true,"type":"localClusterAuthEndpoint"},"labels":{},"scheduledClusterScan":{"enabled":false,"scheduleConfig":null,"scanConfig":null}}' --insecure`
# Extract clusterid to use for generating the docker run command
CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`
ROLEFLAGS="--etcd --controlplane --worker"
# Create token
curl -s ''$RANCHER_SERVER'/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure > /dev/null
# Generate node command with cluster registraion token
AGENTCMD=`curl -s ''$RANCHER_SERVER'/v3/clusterregistrationtoken?id="'$CLUSTERID'"' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --insecure | jq -r '.data[].nodeCommand' | head -1`
# Concat Roles to Node commands
#DOCKERRUNCMD="$AGENTCMD $ROLEFLAGS"
# Echo command
echo $DOCKERRUNCMD
#Run Cluster registry command in list of nodes
NODEUSER="ubuntu"
for host in $(< hosts.txt)
do
 IFS=',' read -ra hostarray <<< "$host"
 if [ ${#hostarray[@]} == 1 ]
 then
	DOCKERRUNCMD="$AGENTCMD $ROLEFLAGS"
 else
	DOCKERRUNCMD="$AGENTCMD ${hostarray[1]} ${hostarray[2]} ${hostarray[3]}"
 fi 
 ssh ${NODEUSER}@${hostarray[0]} $DOCKERRUNCMD
done
