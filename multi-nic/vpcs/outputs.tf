output "JuiceShopAZ1SSH" {
  description = "Juice Shop App AZ1 SSH:"
  value = format("ssh ubuntu@%s -p 22",aws_eip.juiceShopAppAZ1EIP.public_ip)
  depends_on = [
    aws_eip.juiceShopAppAZ1EIP
  ]
}

output "JuiceShopAZ2SSH" {
  description = "Juice Shop App AZ2 SSH:"
  value = format("ssh ubuntu@%s -p 22 -i vpcs/%s",aws_eip.juiceShopAppAZ2EIP.public_ip,local_file.newkey_pem.filename)
  depends_on = [
    aws_eip.juiceShopAppAZ2EIP
  ]
}

output "JuiceShopAPIAZ1SSH" {
  description = "Juice Shop API AZ1 SSH:"
  value = format("ssh ubuntu@%s -p 22 -i vpcs/%s",aws_eip.juiceShopAPIAZ1EIP.public_ip,local_file.newkey_pem.filename)
  depends_on = [
    aws_eip.juiceShopAPIAZ1EIP
  ]
}

output "JuiceShopAPIAZ2SSH" {
  description = "Juice Shop API AZ2 SSH:"
  value = format("ssh ubuntu@%s -p 22 -i vpcs/%s",aws_eip.juiceShopAPIAZ2EIP.public_ip,local_file.newkey_pem.filename)
  depends_on = [
    aws_eip.juiceShopAPIAZ2EIP
  ]
}

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

output "hostKeyPEM" {
  description = "private key for accessing lab hosts"
  value = format("$(cat vpcs/%s)",local_file.newkey_pem.filename)
}