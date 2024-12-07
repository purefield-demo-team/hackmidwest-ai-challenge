source tools/format.sh
step=$1
NAMESPACE=redhat
clusterName="rosa-$GUID"
clusterInfo=$(rosa list clusters -o json)
CONSOLE_URL=$(echo "$clusterInfo" | jq -r '.[].console.url')
API_URL=$(echo "$clusterInfo" | jq -r '.[].api.url')
APP_URL=$(echo "$CONSOLE_URL" | cut -d\. -f2-)
BASE_DOMAIN=$(echo "$CONSOLE_URL" | cut -d\. -f3-)
SETUP_PATH=$(pwd)
PROJECT_PATH=$(dirname $SETUP_PATH)
DEMO_PATH=$PROJECT_PATH/demo-app/
SCRATCH_PATH="$DEMO_PATH/scratch/"
GITOPS_PATH="$DEMO_PATH/gitops/"
baseDomain=$(echo $BASE_DOMAIN | cut -d\. -f2-)
__ "Install AI Demo App" 1

if [[ -z "$step" || "$step" == "1" ]]; then 
  __ "Step 1 - Pre-requisites" 2

  __ "Checkout AI Starter Kit" 3
  cmd "git clone https://github.com/purefield-demo-team/ai-hackathon-starter.git $DEMO_PATH"
  
  __ "Setup Scratch Environment" 3
  cmd "mkdir -p $SCRATCH_PATH"
  
  oc status 2>&1 
  if [ $? -ne 0 ]; then
    __ "Log into OpenShift Cluster as cluster-admin" 3
    _? "What is the cluster-admin password" API_PWD $API_PWD
    cmd oc login -u cluster-admin -p "$API_PWD" "$API_URL"
  fi
  
  __ "Collect Demo App details" 3
  
  step=2
fi

if [[ -n "$step" && "$step" == "2" ]]; then 
  __ "Step 2 - Setup Project/Namespace" 2
  _? "What is the namespace for the AI demo app: " NAMESPACE $NAMESPACE

  oc get ns $NAMESPACE 2>&1 
  if [ $? -ne 0 ]; then
    __ "Setup App namespace" 3
    cmd "oc new-project $NAMESPACE"
  fi
  cmd "oc project $NAMESPACE"
  
  step=3
fi

if [[ -n "$step" && "$step" == "3" ]]; then 
  __ "Step 3 - Install Red Hat Keycloak" 2
  
  __ "Create SSL Certificate" 3
  __ "Generate SSL Certificate" 4
  cmd "openssl req -subj '/CN=keycloak-${NAMESPACE}.${APP_URL}/O=Test Keycloak./C=US' -newkey rsa:2048 -nodes -x509 -days 365 -keyout ${SCRATCH_PATH}key.pem -out    ${SCRATCH_PATH}certificate.pem"

  __ "Copy SSL Certificate into secret" 4
  cmd "oc create secret -n $NAMESPACE tls keycloak-tls-secret --cert ${SCRATCH_PATH}certificate.pem --key ${SCRATCH_PATH}key.pem"

  __ "Run helm charts for postgresql" 3
  setValues="cluster.name=rosa,cluster.domain=$baseDomain"
  cmd "helm install keycloak-postgresql ${GITOPS_PATH}rhbk/keycloak-postgresql-chart/ --set-string '$setValues'"

  __ "Wait for keycloak-postgres pod to be present" 4
  podSelector="-l name=keycloak-postgresql -n $NAMESPACE"
  oo 1 "oc get pod $podSelector -o name | wc -l"
  cmd "oc wait pod $podSelector --for=condition=ready --timeout=3m"

  __ "Restore the keycloak.backup file in the gitops/rhbk folder to postgresql" 3
  pod=$(oc get pod $podSelector -o name | cut -d\/ -f2-)
  # oc rsh pod/$pod /bin/bash -c 'pg_dump -d keycloak -U postgres -F t -f /var/lib/pgsql/data/userdata/keycloak.backup
  cmd "rsync --rsh='oc rsh' ${GITOPS_PATH}rhbk/keycloak.backup $pod:/var/lib/pgsql/data/userdata/"
  cmd "oc rsh pod/$pod /bin/bash -c 'ls -rtla /var/lib/pgsql/data/userdata/keycloak.backup'"
  cmd "oc rsh pod/$pod /bin/bash -c 'pg_restore -d keycloak -U postgres /var/lib/pgsql/data/userdata/keycloak.backup'"
  cmd "oc rsh pod/$pod /bin/bash -c 'rm -f /var/lib/pgsql/data/userdata/keycloak.backup*'"

  __ "Run helm charts" 3
  setValues="cluster.name=rosa,cluster.domain=$baseDomain"
  cmd "helm install keycloak ${GITOPS_PATH}rhbk/keycloak-chart/ --set-string '$setValues'"

  step=4
fi

if [[ -n "$step" && "$step" == "4" ]]; then 
  __ "Step 4 - Install Strapi" 2
  podSelector="-l name=strapi-postgresql -n $NAMESPACE"

  __ "Run helm charts for strapi" 3
  setValues="cluster.name=rosa,cluster.domain=$baseDomain"
  cmd "helm install strapi ${GITOPS_PATH}strapi/ --set-string '$setValues'"

  __ "Wait for strapi-postgres pod to be present" 4
  oo 1 "oc get pod $podSelector -o name | wc -l"
  cmd "oc wait pod $podSelector --for=condition=ready --timeout=3m"
  pod=$(oc get pod $podSelector -o name | cut -d\/ -f2-)

  __ "Restore the strapi.backup file in the gitops/strapi folder to postgresql" 3
  cmd "rsync --rsh='oc rsh' ${GITOPS_PATH}strapi/strapi.backup $pod:/var/lib/pgsql/data/userdata/"
  cmd "oc rsh pod/$pod /bin/bash -c 'ls -rtla /var/lib/pgsql/data/userdata/strapi.backup'"
  cmd "oc rsh pod/$pod /bin/bash -c 'pg_restore -d strapi -U postgres /var/lib/pgsql/data/userdata/strapi.backup'"
  cmd "oc rsh pod/$pod /bin/bash -c 'rm -f /var/lib/pgsql/data/userdata/strapi.backup*'"

  __ "Update Keycloak url and namespace" 3
  export sql="update strapi_core_store_settings set value=REPLACE(REPLACE(REPLACE(value, 'salamander', 'rosa'), 'aimlworkbench.com', '$baseDomain'), 'restore-db-test', '$NAMESPACE') where id = 20"
  cmd 'oc rsh '$pod'  /bin/bash -c "psql -U postgres -d strapi -c \"$sql\""'
  unset sql
  
  __ "Update Vector-ask-short url" 3
  export sql="update strapi_webhooks set url=REPLACE(url, 'vector-ask-short.aimlworkbench.com', 'vector-ask-$NAMESPACE.apps.rosa.$baseDomain') where id in (2,3,5)"
  cmd 'oc rsh '$pod'  /bin/bash -c "psql -U postgres -d strapi -c \"$sql\""'
  unset sql

  __ "Build strapi app" 3
  cmd "oc start-build strapi"
  __ "Wait for strapi build to complete" 4
  cmd "oc wait builds -l buildconfig=strapi --for=condition=complete --timeout=3m"

  step=5
fi

if [[ -n "$step" && "$step" == "5" ]]; then 
  __ "Step 5 - Install Redis" 2
  
  __ "Run helm charts for redis" 3
  setValues="cluster.name=rosa,cluster.domain=$baseDomain"
  cmd "helm install redis-search ${GITOPS_PATH}redis-search/ --set-string '$setValues'"

  step=6
fi
if [[ -n "$step" && "$step" == "6" ]]; then 
  __ "Step 6 - Setup Model Server" 2

  __ "Setup S3 Storage" 3
  cmd "oc apply -n $NAMESPACE -f configs/setup-s3.yaml"

  __ "Sync Model to S3 bucket" 3
  __ "Install python dependencies" 4
  cmd "pip install -qr requirements.txt"
  __ "Run Python Sync from HuggingFace to S3 bucket" 4
  _? "Connection Name" s3Connection aws-connection-my-storage aws-connection-my-storage
  export ENDPOINT_URL=$(oc get secret -n redhat $s3Connection -o template --template '{{.data.AWS_S3_ENDPOINT}}' | base64 -d)
  export AWS_S3_BUCKET=$(oc get secret -n redhat $s3Connection -o template --template '{{.data.AWS_S3_BUCKET}}' | base64 -d)
  export AWS_ACCESS_KEY_ID=$(oc get secret -n redhat $s3Connection -o template --template '{{.data.AWS_ACCESS_KEY_ID}}' | base64 -d)
  export AWS_SECRET_ACCESS_KEY=$(oc get secret -n redhat $s3Connection -o template --template '{{.data.AWS_SECRET_ACCESS_KEY}}' | base64 -d)
  __ "defog/llama-3-sqlcoder-8b" 5
  cmd "python ./sync-model.py -m 'defog/llama-3-sqlcoder-8b'       -b 'llama-3-sqlcoder-8b'"
  __ "intfloat/e5-mistral-7b-instruct" 5
  cmd "python ./sync-model.py -m 'intfloat/e5-mistral-7b-instruct' -b 'e5-mistral-7b-instruct'"
  unset ENDPOINT_URL; unset AWS_ACCESS_KEY_ID; unset AWS_SECRET_ACCESS_KEY

  __ "Run helm charts for model server" 3
  setValues="cluster.name=rosa,cluster.domain=$baseDomain"
  cmd "helm install vector-ask-model ${GITOPS_PATH}vector-ask/ai-model/ --set-string '$setValues'"

  step=7
fi
if [[ -n "$step" && "$step" == "7" ]]; then 
  __ "Step 7 - Install NL2SQL" 2
  podSelector="-l name=nl2sql-sample-postgresql-postgresql -n $NAMESPACE"

  __ "Run helm charts for nl2sql" 3
  setValues="cluster.name=rosa,cluster.domain=$baseDomain"
  cmd "helm install nl2sql-sample-postgresql ${GITOPS_PATH}vector-ask/nl2sql-sample-db/ --set-string '$setValues'"

  __ "Wait for nl2sql-postgres pod to be present" 4
  oo 1 "oc get pod $podSelector -o name | wc -l"
  cmd "oc wait pod $podSelector --for=condition=ready --timeout=3m"
  pod=$(oc get pod $podSelector -o name | cut -d\/ -f2-)

  __ "Restore the dvdrental.backup file in the gitops/vector-ask/nl2sql-sample-db folder to postgresql" 3
  cmd "rsync --rsh='oc rsh' ${GITOPS_PATH}vector-ask/nl2sql-sample-db/dvdrental.backup $pod:/var/lib/pgsql/data/userdata/"
  cmd "oc rsh pod/$pod /bin/bash -c 'ls -rtla /var/lib/pgsql/data/userdata/dvdrental.backup'"
  cmd "oc rsh pod/$pod /bin/bash -c 'pg_restore -d nl2sql-sample -U postgres /var/lib/pgsql/data/userdata/dvdrental.backup'"
  cmd "oc rsh pod/$pod /bin/bash -c 'rm -f /var/lib/pgsql/data/userdata/dvdrental.backup'"

  step=8
fi
if [[ -n "$step" && "$step" == "8" ]]; then 
  __ "Step 8 - Install Quarkus Vector-Ask App" 2
  
  _? "Optional: OpenAI Key: " openAiKey xxxxxx
  vllmApiUrl="https://llama-3-sqlcoder-8b-$NAMESPACE.apps.rosa.$baseDomain/v1"
  vllmEmbeddingApiUrl="https://e5-mistral-7b-instruct-$NAMESPACE.apps.rosa.$baseDomain/v1"
  setValues="openai.key=$openAiKey,cluster.name=rosa,cluster.domain=$baseDomain,vllmApiUrl=$vllmApiUrl,vllmEmbeddingApiUrl=$vllmEmbeddingApiUrl"
  
  __ "Run helm charts for quarkus app" 3
  cmd "helm install vector-ask ${GITOPS_PATH}vector-ask/quarkus/ --set-string '$setValues'"

  __ "Build quarkus app" 3
  cmd "oc start-build vector-ask"
  __ "Wait for vector-ask build to complete" 4
  cmd "oc wait builds -l buildconfig=vector-ask --for=condition=complete --timeout=5m"

  step=9
fi
if [[ -n "$step" && "$step" == "9" ]]; then 
  __ "Step 9 - Install React Frontend" 2

  _? "Optional: OpenAI Key: " openAiKey xxxxxx $openAiKey
  strapiUrl="https://strapi-$NAMESPACE.apps.rosa.$baseDomain/api"
  keycloakUrl="https://keycloak-$NAMESPACE.apps.rosa.$baseDomain"
  setValues="openai.key=$openAiKey,cluster.name=rosa,cluster.domain=$baseDomain,strapi.url=$strapiUrl,keycloak.url=$keycloakUrl"

  __ "Add react-frontend url to keycloak realm" 3
  username=admin
  __ "Try to find initial keycloak admin password in pre-requisites" 4
  _? "Keycloak admin password: " password "" $(egrep 'keycloak.*?inital admin password is' ${GITOPS_PATH}rhbk/pre-requisites.txt | cut -d\: -f 2)
  reactUrl=https://react-frontend-$NAMESPACE.apps.rosa.$baseDomain
  export access_token="$(curl -ksX POST "$keycloakUrl/realms/master/protocol/openid-connect/token" \
       -H "Content-Type: application/x-www-form-urlencoded" \
       -d 'client_id=admin-cli' \
       -d 'grant_type=password' \
       -d "username=$username" \
       -d "password=$password" | jq -r '.access_token')"
  id=$(curl -ksX GET "$keycloakUrl/admin/realms/fihr-rag-llm/clients?clientId=fihr-rag-chat" \
       -H "Authorization: Bearer $access_token" | jq -r '.[].id')
  __ "Update keycloak realm" 4
  export data='{
         "clientId": "fihr-rag-chat",
         "redirectUris": [
           "'$reactUrl/*'",
           "'$reactUrl'",
           "http://localhost:3000/*",
           "http://localhost:3000/"
         ]
       }'
  cmd "curl -ksX PUT '$keycloakUrl/admin/realms/fihr-rag-llm/clients/$id' -H 'Content-Type: application/json' -H \"Authorization: Bearer \$access_token\" -d \"\$data\""
  unset access_token
  unset password
  unset data

  __ "Run helm charts for the react app" 3
  cmd "helm install react-frontend ${GITOPS_PATH}react-frontend/ --set-string '$setValues'"

  __ "Build react-frontend app" 3
  cmd "oc start-build react-frontend"
  __ "Wait for react-frontend build to complete (timeout 30min)" 4
  cmd "oc wait builds -l buildconfig=react-frontend --for=condition=complete --timeout=30m"

  step=final
fi
if [[ -n "$step" && "$step" == "final" ]]; then 
  __ "Final Step - Verification" 2

  __ "Wait for model servers to be ready" 3
  cmd "oc wait InferenceService.serving.kserve.io -n redhat --all --for=condition=ready --timeout=15m"

  __ "Here are the deployed routes to the apps" 3
  __ "Open the react-frontent app in your browser and register to log in:" 4
  oc get route -n redhat -o json | jq -r '.items[] | [.metadata.name, ", https://", .spec.host] | join ("")'

  ___ "Deployment Complete"
fi
