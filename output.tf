

output "bastion_ip" {
    value = "${module.bastion.public_ip}"
}


output "kubeNodes_ip" {
    value = "${concat(module.ec2_cluster_az1.private_ip, module.ec2_cluster_az2.private_ip)}"
}