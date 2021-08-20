output "JuiceShopAppURL" {
  description = "URL to front-end of Juice Shop App URL (NLB)"
  value = format("http://%s", aws_lb.juiceShopAppNLB.dns_name)
}

output "JuiceShopAPIURL" {
  description = "URL to front-end of Juice Shop API URL (NLB)"
  value = format("http://%s",aws_lb.juiceShopAPINLB.dns_name)
}

output "BIG-IP_AZ1_Mgmt_URL" {
  description = "URL for managing the BIG-IP in AZ1"
  value = format("https://%s/",aws_eip.F5_BIGIP_AZ1EIP_MGMT.public_ip)
}

output "BIG-IP_AZ2_Mgmt_URL" {
  description = "URL for managing the BIG-IP in AZ2"
  value = format("https://%s/",aws_eip.F5_BIGIP_AZ2EIP_MGMT.public_ip)
}

output "BIG-IP_AZ1_Dataplane_Public_IP" {
  description = "The data NIC public IP for BIG-IP in AZ1"
  value = format("https://%s/",aws_eip.F5_BIGIP_AZ1EIP_DATA.public_ip)
}

output "BIG-IP_AZ2_Dataplane_Public_IP" {
  description = "The data NIC public IP for BIG-IP in AZ2"
  value = format("https://%s/",aws_eip.F5_BIGIP_AZ2EIP_DATA.public_ip)
}

output "hostKeyPEM" {
  description = "private key for accessing lab hosts"
  value = format("$(cat vpcs/%s)",local_file.newkey_pem.filename)
}
output "SSH_Bash_aliases" {
  description = "cut/paste block to create ssh aliases"
  value = "\nCut and paste this block to enable SSH aliases (shortcuts):\n\nalias juiceshop1='ssh ubuntu@${aws_eip.juiceShopAPIAZ1EIP.public_ip} -p 22 -i vpcs/${local_file.newkey_pem.filename}'\nalias juiceshop2='ssh ubuntu@${aws_eip.juiceShopAPIAZ2EIP.public_ip} -p 22 -i vpcs/${local_file.newkey_pem.filename}'\nalias bigip1='ssh admin@${aws_eip.F5_BIGIP_AZ1EIP_MGMT.public_ip} -p 22 -i vpcs/${local_file.newkey_pem.filename}'\nalias bigip2='ssh admin@${aws_eip.F5_BIGIP_AZ2EIP_MGMT.public_ip} -p 22 -i vpcs/${local_file.newkey_pem.filename}'\nalias bigip1data='ssh admin@${aws_eip.F5_BIGIP_AZ1EIP_DATA.public_ip} -p 22 -i vpcs/${local_file.newkey_pem.filename}'\nalias bigip2data='ssh admin@${aws_eip.F5_BIGIP_AZ2EIP_DATA.public_ip} -p 22 -i vpcs/${local_file.newkey_pem.filename}'\n"
}