#echo "stopping 0"
#nixops ssh node0-coordinator -- systemctl kill cardano-node

#Hack, but can't imagine better
#yes_file=/tmp/pos-prototype-deployment-yes-file.txt
#yes | head -100 > $yes_file

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function exit_ {
   e=$1
   if [[ $e -ne 0 ]]; then
     echo ".. failed with code $e"
     exit $e
   fi
}

cmd=$1

if [[ "$cmd" == "" ]]; then
  cmd=redeploy
fi

deployment_name=$2

if [[ "$deployment_name" == "" ]]; then
  deployment_name=cardano
fi

deploy_args=$3

shift
shift

function nodes {
  nixops info -d $deployment_name --plain | grep node | grep -v obsolete | awk '{ print $1 }'
}

function all_nodes {
  nixops info -d $deployment_name --plain | grep node | awk '{ print $1 }'
}

batch=40
pause=500
pause2=100
node_count=`nodes | wc -l`
batch_cnt=$((node_count/batch))

if [[ $((batch_cnt*batch)) -lt $node_count ]]; then
   batch_cnt=$((batch_cnt+1))
fi

function runEach {
  nodes    | { while read n; do
                 $1 $n &
               done
               wait
             }
}
function runEachAll {
  all_nodes | { while read n; do
                 $1 $n &
               done
               wait
             }
}


function node_list {
  local i=$1
  local j=$((i*batch+1))
  nodes | tail -n +$j | head -$batch
}

function runBatched {
   local pause_=$3
   local i=$((batch_cnt-1))
   while [[ $i -gt -1 ]]; do
     echo "$2 nodes $((i*batch))..$((i*batch+batch-1))"
     #j=$((i*batch))
     #pids=''
     #while [[ $j -lt $((i*batch+batch)) ]]; do
     #  $1 $j 1>&2 <$yes_file &
     #  pids="$pids $!"
     #  j=$((j+1))
     #done
     #echo "Pids: $pids"
     #wait
     echo $1 `node_list $i`
     yes | $1 `node_list $i`
     if [[ $i == 0 ]]; then
       break;
     fi
     echo "Pausing for $pause_ sec"
     sleep ${pause_}s
     i=$((i-1))
   done
}

function stop_node {
  echo nixops stop -d $deployment_name --include $@ >&2
  nixops stop -d $deployment_name --include $@
  exit_ $?
}

function start_node_light {
  nixops ssh -d $deployment_name $1 systemctl start cardano-node
  exit_ $?
}

function rm_jsonLog {
  nixops ssh -d $deployment_name $1 rm /var/lib/cardano-node/jsonLog.json
  exit_ $?
}

function restart_node_light {
  nixops ssh -d $deployment_name $1 systemctl restart cardano-node
  exit_ $?
}

function stop_node_light {
  nixops ssh -d $deployment_name $1 systemctl stop cardano-node
  exit_ $?
}

function deploy_node {
  echo nixops deploy -d $deployment_name -I nixpkgs=~/nixpkgs --show-trace $deploy_args --include $@ >&2
  local tmp_file=/tmp/tmp_file_`date +%F%H%M%S`.txt
  local e=1
  while [[ $e -ne 0 ]]; do
     nixops deploy -d $deployment_name -I nixpkgs=~/nixpkgs --show-trace $deploy_args --include $@ > $tmp_file
     e=$?
     if [[ $e -eq 0 ]]; then
        e=`grep "error" $tmp_file|wc -l`
     fi
  done
}
function upload_nodht {
  nixops scp -d $deployment_name --to $1 /tmp/nodht_params.txt /var/lib/cardano-node/nodht_params.txt
  exit_ $?
}

case "$cmd" in
   stop | redeploy | restart )
     echo "Stopping via SSH"
     echo nixops ssh -d $deployment_name node\$i systemctl stop cardano-node >&2
     runEachAll stop_node_light
     #runBatched stop_node "Stopping" $pause
     ;;
esac
if [[ "$cmd" == "redeploy" ]]; then
     echo "Pausing for $pause2 sec"
     sleep ${pause2}s
fi
case "$cmd" in
   redeploy | deploy )
     runBatched deploy_node "Deploying" $pause
     "$dir/genParamsNoDht.sh" | tr "\n" " " > /tmp/nodht_params.txt
     runEach upload_nodht
     runEach rm_jsonLog
     runEach restart_node_light
     ;;
   restart | start )
     echo "Starting via SSH"
     echo nixops ssh -d $deployment_name node\$i systemctl start cardano-node >&2
     runEach rm_jsonLog
     runEach start_node_light
     ;;
esac