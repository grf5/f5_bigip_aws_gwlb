output "JuiceShopAZ1SecureCRTCommand" {
  description = "Mac CLI to launch Secure CRT session to host"
  value = format("/Applications/SecureCRT.app/Contents/MacOS/SecureCRT /N %s /SSH2 /ACCEPTHOSTKEYS /AUTH publickey /I ~/.ssh/%s-key-%s.pem /L ubuntu /P 22 %s","JuiceShopAppAZ1",var.projectPrefix,random_id.buildSuffix.hex,aws_eip.juiceShopAppAZ1EIP.public_ip)
  depends_on = [
    aws_eip.juiceShopAPIAZ1EIP
  ]
}

output "JuiceShopAZ2SecureCRTCommand" {
  description = "Mac CLI to launch Secure CRT session to host"
  value = format("/Applications/SecureCRT.app/Contents/MacOS/SecureCRT /N %s /SSH2 /ACCEPTHOSTKEYS /AUTH publickey /I ~/.ssh/%s-key-%s.pem /L ubuntu /P 22 %s","JuiceShopAppAZ2",var.projectPrefix,random_id.buildSuffix.hex,aws_eip.juiceShopAppAZ2EIP.public_ip)
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
