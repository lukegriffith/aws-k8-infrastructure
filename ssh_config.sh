#!/bin/bash

cfg="Host k8bastion\n
\tForwardAgent yes\n
\tUser ec2-user\n
\tHostName "

bastion_ip=$(terraform output -json | jq -r .bastion_ip.value[0])

cfg=$cfg$bastion_ip"\n"


for i in `seq 1 $(terraform output -json | jq '.kubeNodes_ip.value | length' -r)`;
do  
    node_ip=$(terraform output -json | jq -r .kubeNodes_ip.value[$i])
    cfg=$cfg"Host k8node"$i"\n
\tHostName $node_ip\n
\tProxyJump ec2-user@$bastion_ip\n
\tUser ec2-user\n"

done

echo -e $cfg