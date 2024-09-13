teams=(wisdom logic insight vision clarity focus genius reason skill wit) 
animals=(akita alligator alpaca anaconda armadillo badger bat bear beaver bison bobcat bonobo bunny bushbaby butterfly calf camel cat cheetah chicken chimp chinchilla chinook clam cobra corgi cougar cow coyote crab crocodile cub deer dog duck eagle elephant ermine falcon fawn ferret fox frog garter gerbil giraffe goat gopher gorilla grizzly hare hawk hedgehog hippopotamus horse hummingbird ibex impala jackal jaguar jellyfish kangaroo kid kingfisher koala lamb lemming lemur lion lizard llama lobster lynx marmoset marmot marten meerkat mink mole mongoose moose mouse muskrat octopus opossum orangutan otter panda peacock pig pika platypus polar poodle porcupine possum pronghorn puma pup python quagga rabbit raccoon rat rattlesnake rhinoceros sable salamander seahorse sheep shih shrew skunk snake spaniel starfish stoat tapir tasmani tiger toad turkey turtle tzu vicuña vole wallaby weasel wolf wolverine wombat yak zebra)
auth="teams.htpasswd"; echo -n '' > $auth;
provider=ai-hacker
rosa delete idp --cluster=rosa-$GUID ai-hackers -y
for i in {0..9}; do
  team=${teams[$i]}
  oc delete rolebinding $team-admin-rb
  oc delete group $team
  oc delete project $team
done
for i in {0..9}; do
  team=${teams[$i]}
  login="$team.users.csv"; echo -n '' > $login;
  users=$(for u in {0..9}; do echo -n "${animals[$((u + i * 10))]} "; done)
  oc new-project $team;
  oc adm groups new $team; 
  oc adm groups add-users $team $users
  # oc create rolebinding $team-admin-rb --role=admin --group=$team --namespace=$team
  oc adm policy add-role-to-group admin $team -n $team
  oc apply -n $team -f setup-s3.yaml
  for user in $users; do 
    oc create identity $provider:$user
    pass=$(openssl rand -base64 12);
    echo "$team,$user,$pass" >> $login;
    htpasswd -bn $user $pass >> $auth;
  done
done
rosa create idp --cluster=rosa-$GUID --name $provider --type htpasswd --from-file $auth

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
  users=$(for u in {0..9}; do index=$((u + i * 10)); echo -n "$index: ${animals[$index]} "; done)
  echo "$users"
done
