teams=(wisdom logic insight vision clarity focus genius reason skill wit) 
teams=(achievement ambition brilliance courage creativity determination excellence growth innovation leadership mastery perseverance progress resilience vision) 
animals=(akita alligator alpaca anaconda armadillo badger bat bear beaver bison bobcat bonobo bunny bushbaby butterfly calf camel cat cheetah chicken chimp chinchilla chinook clam cobra corgi cougar cow coyote crab crocodile cub deer dog duck eagle elephant ermine falcon fawn ferret fox frog garter gerbil giraffe goat gopher gorilla grizzly hare hawk hedgehog hippopotamus horse hummingbird ibex impala jackal jaguar jellyfish kangaroo kid kingfisher koala lamb lemming lemur lion lizard llama lobster lynx marmoset marmot marten meerkat mink mole mongoose moose mouse muskrat octopus opossum orangutan otter panda peacock pig pika platypus polar poodle porcupine possum pronghorn puma pup python quagga rabbit raccoon rat rattlesnake rhinoceros sable salamander seahorse sheep shih shrew skunk snake spaniel starfish stoat tapir tasmani tiger toad turkey turtle tzu vicuña vole wallaby weasel wolf wolverine wombat yak zebra)
animals=(apple beach blaze blend blink brave brick brisk brisk brush carve charm chill clash clear click climb clock crack craft crane creek crisp crisp crisp crush daisy drain dream drift drink drive flair flame flare flash flick flute frost froze giant glare glide glint globe grape grasp grill grove grove lemon lucky match mount pearl plane plant pluck plumb plume pride quest quilt rapid scope scout shark sharp shift shine shine shine sleep slice slice smile smoke spade spark spark spear stack stair start stone storm strip sweet swoop table trail trend trick trunk vivid vocal waver whale wheat wrist)
auth="scratch/teams.htpasswd"; echo -n '' > $auth;
provider=ai-hacker
console=$(oc whoami --show-console)
api=$(oc whoami --show-server)
rosa delete idp --cluster=rosa-$GUID $provider -y
oc get identity -o jsonpath='{range .items[?(@.providerName=="ai-hacker")]}{.metadata.name}{"\n"}{end}' | xargs -i oc delete identity {}
for i in {0..9}; do
  team=${teams[$i]}
  oc delete group $team
  oc delete project $team
done
for i in {0..9}; do
  team=${teams[$i]}
  login="scratch/$team.users.csv"; 
  echo $console > $login;
  echo $api >> $login;
  users=$(for u in {0..9}; do echo -n "${animals[$((u + i * 10))]} "; done)
  echo '{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"'$team'","labels":{"opendatahub.io/dashboard":"true"}}}' | oc create -f -
  oc adm groups new $team; 
  oc adm groups add-users $team $users
  oc adm policy add-role-to-group admin $team -n $team
  oc apply -n $team -f configs/setup-s3.yaml
  for user in $users; do 
    pass=$(openssl rand -base64 12);
    echo "$team,$user,$pass" >> $login;
    htpasswd -bn $user $pass >> $auth;
  done
done
rosa create idp --cluster=rosa-$GUID --name $provider --type htpasswd --from-file $auth
for i in {0..9}; do
  team=${teams[$i]}
  login="scratch/$team.users.csv"; 
  echo -n 'MinIO-Root,' >> $login;
  oc get secret -n $team minio-root-user -o go-template --template="{{.data.MINIO_ROOT_USER|base64decode}},{{.data.MINIO_ROOT_PASSWORD|base64decode}}" >> $login
done
# confirm setup
egrep -i 'https|minio' scratch/*


exit 0;

rosa delete idp --cluster=rosa-$GUID bootcamp -y
rosa create idp --cluster=rosa-$GUID --name bootcamp --type htpasswd --from-file scratch/users.htpasswd
oc adm groups add-users cluster-admin admin

for i in $(seq -f"%02g" 1 10); do
  team=team$i
  oc delete group $team
done
rosa list idp -c rosa-$GUID | egrep -v 'NAME|admin' | cut -d' ' -f1 | xargs -i rosa delete idp -c rosa-$GUID {} -y


for i in {0..9}; do
  team=${teams[$i]}
  users=$(for u in {0..9}; do index=$((u + i * 10)); printf "%2d: %s " "$index" "${animals[$index]}"; done)
  echo "$users"
done
