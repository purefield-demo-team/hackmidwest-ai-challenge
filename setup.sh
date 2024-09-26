# ssh to bastion using -A flag
BASTION=bastion.t8j8w.sandbox2873.opentlc.com
ssh-copy-id rosa@$BASTION
ssh -A rosa@$BASTION
# rosa login for oc cli
rosa create admin --cluster rosa-$GUID
# setup env
API_URL=https://api.rosa-t8j8w.ft2c.p3.openshiftapps.com:443
if [ -z "$API_PWD" ]; then read -sp "Enter: " API_PWD; fi
oc login -u cluster-admin -p "$API_PWD" "$API_URL"
# Checkout dependencies
git clone git@github.com:purefield-demo-team/hackmidwest-ai-challenge.git
cd hackmidwest-ai-challenge
# Setup dependencies
mkdir -p scratch/
# Add intel-amx machine pool
rosa create machinepool -c rosa-$GUID --name=intel-amx --min-replicas=2 --max-replicas=8 --instance-type=m7i.8xlarge --enable-autoscaling --labels nodes=amx
# Upgrade Cluster to latest version
rosa list versions  | sort -nr | head
rosa upgrade cluster -c rosa-$GUID --control-plane --schedule-date $(date -d "+5 minutes 30 seconds" +"%Y-%m-%d") --schedule-time $(date -d "+6 minutes" +"%H:%M") -m auto -y --version 4.16.11
watch rosa list upgrades -c rosa-$GUID
# wait for cluster upgrade to finish
# wait for machinepool to be ready
oc wait --for=jsonpath='{.status.phase}'=Active node -l nodes=amx
rosa list machinepools -c rosa-$GUID
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
oc create -f configs/rhoai-operator-ns.yaml
oc create -f configs/rhoai-operator-group.yaml
oc create -f configs/rhoai-operator-subscription.yaml
oc get projects -w | grep -E "redhat-ods|rhods"
oc create -f configs/rhoai-operator-dsc.yaml
oc get DSCInitialization,FeatureTracker -n redhat-ods-operator
## OpenShift Pipelines
# Install operator with defaults using UI
## Red Hat OpenShift Dev Spaces
# Install operator, create CheCluster with defaults using UI
oc patch checluster devspaces -n openshift-operators --type='merge' -p='{"spec": {"devEnvironments": {"secondsOfInactivityBeforeIdling": -1,"secondsOfRunBeforeIdling": -1}}}'

# Create namespace for each team, setup groups and roles
# - Create Data Science Project
# - Provision S3 Storage (endpoint requires protocol, valid cert via public url)
# ?? Github authentication
# ?? Map each namespace to a worker node
./rosa-create-users-groups.sh
# Application Routes
# Create Workbench
# Available images: oc get imagestream -n redhat-ods-applications
