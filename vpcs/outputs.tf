output "JuiceShopAZ1SecureCRTCommand" {
  description = "Juice Shop App AZ1 SSH:"
  value = format("ssh://ubuntu@%s:22",aws_eip.juiceShopAppAZ1EIP.public_ip)
  depends_on = [
    aws_eip.juiceShopAppAZ1EIP
  ]
}

output "JuiceShopAZ2SecureCRTCommand" {
  description = "Juice Shop App AZ2 SSH:"
  value = format("ssh://ubuntu@%s:22",aws_eip.juiceShopAppAZ2EIP.public_ip)
  depends_on = [
    aws_eip.juiceShopAppAZ2EIP
  ]
}

output "JuiceShopAPIAZ1SecureCRTCommand" {
  description = "Juice Shop API AZ1 SSH:"
  value = format("ssh://ubuntu@%s:22",aws_eip.juiceShopAPIAZ1EIP.public_ip)
  depends_on = [
    aws_eip.juiceShopAPIAZ1EIP
  ]
}

output "JuiceShopAPIAZ2SecureCRTCommand" {
  description = "Juice Shop API AZ2 SSH:"
  value = format("ssh://ubuntu@%s:22",aws_eip.juiceShopAPIAZ2EIP.public_ip)
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

output "hostKeyPEM" {
  description = "private key for accessing lab hosts (also written to ~/.ssh)"
  value = format("%s",tls_private_key.newkey.private_key_pem)
  sensitive = true
}