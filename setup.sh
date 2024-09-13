# Upgrade Cluster to latest version
rosa list versions
rosa upgrade cluster -c rosa-$GUID --schedule-date $(date -d "+5 minutes 30 seconds" +"%Y-%m-%d") --schedule-time $(date -d "+5 minutes 30 seconds" +"%H:%M") --control-plane -m auto -y --version 4.16.10
# wait for cluster upgrade to finish
# todo
rosa create machinepool -c rosa-${GUID} --name=intel-amx --min-replicas=2 --max-replicas=8 --instance-type=m7i.8xlarge --enable-autoscaling --labels nodes=amx
# wait for machinepool to be ready
oc wait --for=jsonpath='{.status.phase}'=Active node -l nodes=amx
sleep 5m
rosa list machinepools -c rosa-${GUID}
rosa update machinepool -c rosa-$GUID --replicas 0 workers
# Have a default storage class
# Install Operators
## Web Terminal Operator
oc apply -f configs/web-terminal-subscription.yaml
## OpenShift Service Mesh
oc create ns istio-system
oc create -f configs/servicemesh-subscription.yaml
## OpenShift Serverless
oc create -f configs/serverless-operator.yaml
## Authorino
oc create -f configs/authorino-subscription.yaml
# Verify dependencies
oc get subscriptions -A
## OpenShift AI >2.11 via OLM on ROSA
oc get projects -w | grep -E "redhat-ods|rhods"
oc create -f configs/rhoai-operator-dsc.yaml
oc get DSCInitialization,FeatureTracker -n redhat-ods-operator
## Intel Device Plugins Operator
## Create QAT instance using defaults
## ?? Node Feature Discovery Operator using defaults
## ?? OpenShift Pipelines
## ?? Red Hat OpenShift Dev Spaces
# Create namespace for each team, setup groups and roles
# ?? Create Data Science Project
# ?? Github authentication
rosa-create-users-groups.sh
# ?? Map each namespace to a worker node
# Provision S3 Storage (endpoint requires protocol, valid cert via public url)
wget https://github.com/rh-aiservices-bu/fraud-detection/raw/main/setup/setup-s3.yaml
# Application Routes
# Create Workbench
# Available images: oc get imagestream -n redhat-ods-applications
