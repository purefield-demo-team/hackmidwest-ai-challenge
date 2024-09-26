teamname=(redhat achievement ambition brightness brilliance courage creativity excellence flair genius growth independence innovation intelligence leadership mastery opportunity outcome performance philosophy possibility progress resilience shrewdness skill success talent television vision wisdom wit) 
username=(daniel dean anthony rh1 rh2 rh3 rh4 rh5 rh6 rh7 actor akita alligator alpaca anaconda apple armadillo badger basis bat beach bear beaver bison blast blaze blend blink blood bobcat bonobo bonus boost brand brave bread brick brisk brush bunny burst bushbaby butterfly buyer calf camel carve cat charm cheek cheer cheetah chest chicken child chill chimp chinchilla chinook clam clash claw clear click climb clock cobra corgi cougar cow coyote crab crack craft crane creek crest crisp crocodile crown crush cub daisy dance death deer depth dog drain drama dream drift drink drive duck eagle elephant entry ermine error event falcon fawn ferret flair flame flare flash flick flute focus force fox frog frost froze garter gerbil giant giraffe glare gleam glide glint globe goat gopher gorilla grape grasp grill grizzly grove guest hare hawk heart hedgehog honey horse hotel ibex impala jackal jaguar jellyfish jump kangaroo kid koala lamb leap lemming lemon lemur light lion lizard llama lobster lucky lynx magic marmoset marmot marten match media meerkat mink mole mongoose month moose mount mouse movie music muskrat nerve night octopus opossum orangutan otter owner panda paper peacock pearl phone photo piano pig pika pizza plane plant platypus pluck plumb plume polar poodle porcupine possum power pride pronghorn pulse puma pup python quagga queen quest quilt rabbit raccoon rapid rat ratio river roar rush sable salad scale scene scope scout seahorse shark sharp sheep shift shih shine shirt shock shout shrew skill skunk sleep slice smile smoke snake sonic spade spaniel spark spear speed spike stack stair starfish start steak stoat stone storm story strip surge sweet swift swirl swoop sword table tapir tasmani thing tiger toad tooth topic trail trend trick trunk truth turkey turtle tzu uncle union video virus vivid vocal vole wallaby waver weasel whale wheat whirl wolf wolverine woman wombat world wrist yak youth zebra)
# echo "$WORDS" | tr ' ' '\n' | awk '{ print length, $0 }' | sort -n | cut -d" " -f2 | uniq | head -n 30 | sort | xargs

# test our data
for i in {0..30}; do
  team=${teamname[$i]}
	printf "%-15s" "$team"
  users=$(for u in {0..9}; do index=$((u + i * 10)); printf "%4d: %-10s " "$index" "${username[$index]}"; done)
  echo "$users"
done

auth="scratch/teamname.htpasswd"; echo -n '' > $auth;
provider=ai-hacker
console=$(oc whoami --show-console)
api=$(oc whoami --show-server)
rosa delete idp --cluster=rosa-$GUID $provider -y
oc get identity -o jsonpath='{range .items[?(@.providerName=="ai-hacker")]}{.metadata.name}{"\n"}{end}' | xargs -i oc delete identity {}
oc get users -o name | grep -v admin | xargs -i oc delete {}
oc delete project -l app.kubernetes.io/part-of=che.eclipse.org
for i in {0..30}; do
  team=${teamname[$i]}
  oc delete group $team
  oc delete project $team
done
for i in {0..30}; do
  team=${teamname[$i]}
  login="scratch/$team.users.csv"; 
  echo $console > $login;
  echo $api >> $login;
	echo 'group,username,password' >> $login;
  users=$(for u in {0..9}; do echo -n "${username[$((u + i * 10))]} "; done)
  echo '{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"'$team'","labels":{"event":"hmw","opendatahub.io/dashboard":"true"}}}' | oc create -f -
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
for i in {0..30}; do
  team=${teamname[$i]}
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

