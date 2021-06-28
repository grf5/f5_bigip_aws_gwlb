##
## General Environment Setup
##

provider "aws" {
  region = var.awsRegion
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "tls_private_key" "newkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "newkey_pem" { 
  filename = "${path.module}/.ssh/${var.projectPrefix}-key-${random_id.buildSuffix.hex}.pem"
  sensitive_content = tls_private_key.newkey.private_key_pem
  file_permission = "0400"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.projectPrefix}-key-${random_id.buildSuffix.hex}"
  public_key = tls_private_key.newkey.public_key_openssh
}

data "http" "ip_address" {
  url             = var.get_address_url
  request_headers = var.get_address_request_headers
}

data "aws_caller_identity" "current" {}

##
## Locals
##

locals {
  awsAz1 = var.awsAz1 != null ? var.awsAz1 : data.aws_availability_zones.available.names[0]
  awsAz2 = var.awsAz2 != null ? var.awsAz1 : data.aws_availability_zones.available.names[1]
}

##
## Juice Shop VM AMI - Ubuntu
##

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

###################################
## Security Services (F5 BIG-IP) ##
###################################

##
## VPC
##

resource "aws_vpc" "securityServicesVPC" {
  cidr_block = var.securityServicesCIDR
  tags = {
    Name  = "${var.projectPrefix}-securityServicesVPC-${random_id.buildSuffix.hex}"
  }
}

resource "aws_default_security_group" "securityServicesSG" {
  vpc_id = aws_vpc.securityServicesVPC.id
  tags = {
    Name  = "${var.projectPrefix}-securityServicesSG-${random_id.buildSuffix.hex}"
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [format("%s/%s",data.http.ip_address.body,32)]
  }

  ingress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [var.juiceShopAppCIDR,var.juiceShopAPICIDR,var.securityServicesCIDR]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "securityServicesSubnetAZ1" {
  vpc_id = aws_vpc.securityServicesVPC.id
  cidr_block = var.securityServicesSubnetAZ1
  availability_zone = local.awsAz1
  tags = {
    Name  = "${var.projectPrefix}-securityServicesSubnetAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_subnet" "securityServicesSubnetAZ2" {
  vpc_id = aws_vpc.securityServicesVPC.id
  cidr_block = var.securityServicesSubnetAZ2
  availability_zone = local.awsAz2
  tags = {
    Name  = "${var.projectPrefix}-securityServicesSubnetAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_internet_gateway" "securityServicesIGW" {
  vpc_id = aws_vpc.securityServicesVPC.id
  tags = {
    Name  = "${var.projectPrefix}-securityServicesIGW-${random_id.buildSuffix.hex}"
  }
}

resource "aws_eip" "securityServicesNGWEIPAZ1" {
  vpc = true
  tags = {
    Name = "securityServicesNGWEIPAZ1"
  }
}

resource "aws_eip" "securityServicesNGWEIPAZ2" {
  vpc = true
  tags = {
    Name = "securityServicesNGWEIPAZ2"
  }
}

resource "aws_nat_gateway" "securityServicesNGWAZ1" {
  allocation_id =aws_eip.securityServicesNGWEIPAZ1.id
  subnet_id = aws_subnet.securityServicesSubnetAZ1.id
  tags = {
    Name = "securityServicesNGWAZ1"
  }
  depends_on = [
    aws_internet_gateway.securityServicesIGW
  ]
}

resource "aws_nat_gateway" "securityServicesNGWAZ2" {
  allocation_id =aws_eip.securityServicesNGWEIPAZ2.id
  subnet_id = aws_subnet.securityServicesSubnetAZ2.id 
  tags = {
    Name = "securityServicesNGWAZ2"
  }
  depends_on = [
    aws_internet_gateway.securityServicesIGW
  ]
}

resource "aws_default_route_table" "securityServicesMainRT" {
  default_route_table_id = aws_vpc.securityServicesVPC.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.securityServicesIGW.id
  }
  tags = {
    Name  = "${var.projectPrefix}-securityServicesMainRT-${random_id.buildSuffix.hex}"
  }
}

## 
## BIG-IP AMI/Onboarding Config
##

data "aws_ami" "f5BigIP_GWLB_AMI" {
  most_recent      = true
  name_regex       = "BIG-IP.*GWLB.*"
  owners           = ["self","065972273535"]
}

data "template_file" "bigip_runtime_init_AZ1" {
  template = "${file("${path.module}/bigip_runtime_init_user_data.tpl")}"
  vars = {
    bigip_license = "${var.bigipLicenseAZ1}",
    bigipAdminPassword = "${var.bigipAdminPassword}"
  }
}

data "template_file" "bigip_runtime_init_AZ2" {
  template = "${file("${path.module}/bigip_runtime_init_user_data.tpl")}"
  vars = {
    bigip_license = "${var.bigipLicenseAZ2}",
    bigipAdminPassword = "${var.bigipAdminPassword}"
  }
}

##
## AZ1 F5 BIG-IP Instance
##

resource "aws_network_interface" "F5_BIGIP_AZ1ENI_DATA" {
  subnet_id       = aws_subnet.securityServicesSubnetAZ1.id
  source_dest_check = false
  tags = {
    Name = "F5_BIGIP_AZ1ENI_DATA"
  }
}

resource "aws_network_interface" "F5_BIGIP_AZ1ENI_MGMT" {
  subnet_id       = aws_subnet.securityServicesSubnetAZ1.id
  tags = {
    Name = "F5_BIGIP_AZ1ENI_MGMT"
  }
}

resource "aws_eip" "F5_BIGIP_AZ1EIP" {
  vpc = true
  network_interface = aws_network_interface.F5_BIGIP_AZ1ENI_MGMT.id
  associate_with_private_ip = aws_network_interface.F5_BIGIP_AZ1ENI_MGMT.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.securityServicesIGW
  ]
  tags = {
    Name = "F5_BIGIP_AZ1EIP"
  }
}

resource "aws_instance" "F5_BIGIP_AZ1" {
  ami               = data.aws_ami.f5BigIP_GWLB_AMI.id
  instance_type     = "c5.xlarge"
  availability_zone = local.awsAz1
  key_name          = aws_key_pair.deployer.id
	user_data = "${data.template_file.bigip_runtime_init_AZ1.rendered}"
  network_interface {
    network_interface_id = aws_network_interface.F5_BIGIP_AZ1ENI_DATA.id
    device_index = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.F5_BIGIP_AZ1ENI_MGMT.id
    device_index = 1
  }
  # Let's ensure an EIP is provisioned so licensing and bigip-runtime-init runs successfully
  depends_on = [
    aws_eip.F5_BIGIP_AZ1EIP
  ]
  tags = {
    Name = "${var.projectPrefix}-F5_BIGIP_AZ1-${random_id.buildSuffix.hex}"
  }
}

##
## AZ2 F5 BIG-IP Instance
##

resource "aws_network_interface" "F5_BIGIP_AZ2ENI_DATA" {
  subnet_id       = aws_subnet.securityServicesSubnetAZ2.id
  source_dest_check = false
  tags = {
    Name = "F5_BIGIP_AZ2ENI_DATA"
  }
}

resource "aws_network_interface" "F5_BIGIP_AZ2ENI_MGMT" {
  subnet_id       = aws_subnet.securityServicesSubnetAZ2.id
  tags = {
    Name = "F5_BIGIP_AZ2ENI_MGMT"
  }
}

resource "aws_eip" "F5_BIGIP_AZ2EIP" {
  vpc = true
  network_interface = aws_network_interface.F5_BIGIP_AZ2ENI_MGMT.id
  associate_with_private_ip = aws_network_interface.F5_BIGIP_AZ2ENI_MGMT.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.securityServicesIGW
  ]
  tags = {
    Name = "F5_BIGIP_AZ2EIP"
  }
}

resource "aws_instance" "F5_BIGIP_AZ2" {
  ami               = data.aws_ami.f5BigIP_GWLB_AMI.id
  instance_type     = "c5.xlarge"
  availability_zone = local.awsAz2
  key_name          = aws_key_pair.deployer.id
	user_data = "${data.template_file.bigip_runtime_init_AZ2.rendered}"
  network_interface {
    network_interface_id = aws_network_interface.F5_BIGIP_AZ2ENI_DATA.id
    device_index = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.F5_BIGIP_AZ2ENI_MGMT.id
    device_index = 1
  }
  # Let's ensure an EIP is provisioned so licensing and bigip-runtime-init runs successfully
  depends_on = [
    aws_eip.F5_BIGIP_AZ2EIP
  ]
  tags = {
    Name = "${var.projectPrefix}-F5_BIGIP_AZ2-${random_id.buildSuffix.hex}"
  }
}

##
## F5 GWLB Objects
##

resource "aws_lb" "securityServicesGWLB" {
  name = "${var.projectPrefix}-secSvcsGWLB-${random_id.buildSuffix.hex}"
  load_balancer_type = "gateway"
  subnet_mapping {
    subnet_id = aws_subnet.securityServicesSubnetAZ1.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.securityServicesSubnetAZ2.id
  }
}

resource "aws_lb_target_group" "securityServicesTG" {
  name = "${var.projectPrefix}-secSvcsTG-${random_id.buildSuffix.hex}"
  vpc_id = aws_vpc.securityServicesVPC.id
  port = 6081
  protocol = "GENEVE"
  health_check {
    port = 443
    protocol = "HTTPS"
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 4
    interval = 5
  }
}

resource "aws_lb_listener" "securityServicesGWLBListener" {
  load_balancer_arn = aws_lb.securityServicesGWLB.arn 
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.securityServicesTG.id
  }
}

resource "aws_lb_target_group_attachment" "securityServicesTGAttachmentAZ1" {
  target_group_arn = aws_lb_target_group.securityServicesTG.arn
  target_id = aws_instance.F5_BIGIP_AZ1.id
}

resource "aws_lb_target_group_attachment" "securityServicesTGAttachmentAZ2" {
  target_group_arn = aws_lb_target_group.securityServicesTG.arn
  target_id = aws_instance.F5_BIGIP_AZ2.id
}

resource "aws_vpc_endpoint_service" "securityServicesES" {
  acceptance_required = false
  allowed_principals = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
  gateway_load_balancer_arns = [aws_lb.securityServicesGWLB.arn]
  tags = {
    Name = "${var.projectPrefix}-securityServicesES-${random_id.buildSuffix.hex}"
  }
}

####################################################################
########################## Juice Shop App ##########################
####################################################################

##
## VPC
##

resource "aws_vpc" "juiceShopAppVPC" {
  cidr_block = var.juiceShopAppCIDR
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppVPC-${random_id.buildSuffix.hex}"
  }
}

resource "aws_default_security_group" "juiceShopAppSG" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppSG-${random_id.buildSuffix.hex}"
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [var.juiceShopAppCIDR]
  }

  ingress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [format("%s/%s",data.http.ip_address.body,32)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "juiceShopAppSubnetAZ1" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  cidr_block = var.juiceShopAppSubnetAZ1
  availability_zone = local.awsAz1
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppSubnetAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_subnet" "juiceShopAppSubnetAZ2" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  cidr_block = var.juiceShopAppSubnetAZ2
  availability_zone = local.awsAz2
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppSubnetAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_internet_gateway" "juiceShopAppIGW" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppIGW-${random_id.buildSuffix.hex}"
  }  
}

resource "aws_default_route_table" "juiceShopAppMainRT" {
  default_route_table_id = aws_vpc.juiceShopAppVPC.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.juiceShopAppIGW.id
  }
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppMainRT-${random_id.buildSuffix.hex}"
  }
}

## 
## Juice Shop AZ1
##

resource "aws_network_interface" "juiceShopAppAZ1ENI" {
  subnet_id       = aws_subnet.juiceShopAppSubnetAZ1.id
  tags = {
    Name = "juiceShopAppAZ1ENI"
  }
}

resource "aws_eip" "juiceShopAppAZ1EIP" {
  vpc = true
  network_interface = aws_network_interface.juiceShopAppAZ1ENI.id
  associate_with_private_ip = aws_network_interface.juiceShopAppAZ1ENI.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.juiceShopAppIGW
  ]
  tags = {
    Name = "juiceShopAppAZ1EIP"
  }
}

resource "aws_instance" "juiceShopAppAZ1" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "m5.xlarge"
  availability_zone = local.awsAz1
  key_name          = aws_key_pair.deployer.id
	user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt -y upgrade
              sudo apt -y install apt-transport-https ca-certificates curl software-properties-common docker
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
              sudo apt update
              sudo apt-cache policy docker-ce
              sudo apt -y install docker-ce
              sudo usermod -aG docker ubuntu
              docker pull bkimminich/juice-shop
              docker run -d -p 80:3000 --restart unless-stopped bkimminich/juice-shop
              sudo reboot
              EOF    
  network_interface {
    network_interface_id = aws_network_interface.juiceShopAppAZ1ENI.id
    device_index = 0
  }
  # Let's ensure an EIP is provisioned so user-data can run successfully
  depends_on = [
    aws_eip.juiceShopAppAZ1EIP
  ]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAppAZ1-${random_id.buildSuffix.hex}"
  }
}

##
## Juice Shop AZ2
##

resource "aws_network_interface" "juiceShopAppAZ2ENI" {
  subnet_id = aws_subnet.juiceShopAppSubnetAZ2.id
  tags = {
    Name = "juiceShopAppAZ2ENI"
  }
}

resource "aws_eip" "juiceShopAppAZ2EIP" {
  vpc = true
  network_interface = aws_network_interface.juiceShopAppAZ2ENI.id
  associate_with_private_ip = aws_network_interface.juiceShopAppAZ2ENI.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.juiceShopAppIGW
  ]
  tags = {
    Name = "juiceShopAppAZ2EIP"
  }
}

resource "aws_instance" "juiceShopAppAZ2" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "m5.xlarge"
  availability_zone = local.awsAz2
  key_name          = aws_key_pair.deployer.id
	user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt -y upgrade
              sudo apt -y install apt-transport-https ca-certificates curl software-properties-common docker
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
              sudo apt update
              sudo apt-cache policy docker-ce
              sudo apt -y install docker-ce
              sudo usermod -aG docker ubuntu
              docker pull bkimminich/juice-shop
              docker run -d -p 80:3000 --restart unless-stopped bkimminich/juice-shop
              sudo reboot
              EOF    
  network_interface {
    network_interface_id = aws_network_interface.juiceShopAppAZ2ENI.id
    device_index = 0
  }
  # Let's ensure an EIP is provisioned so user-data can run successfully
  depends_on = [
    aws_eip.juiceShopAppAZ2EIP
  ]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAppAZ2-${random_id.buildSuffix.hex}"
  }
}

##
## Network Load Balancing for App
##

resource "aws_lb" "juiceShopAppNLB" {
  name = "${var.projectPrefix}-juiceShopAppNLB-${random_id.buildSuffix.hex}"
  load_balancer_type = "network"
  internal = false
  subnet_mapping {
    subnet_id = aws_subnet.juiceShopAppSubnetAZ1.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.juiceShopAppSubnetAZ2.id
  }
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "${var.projectPrefix}-juiceShopAppNLB-${random_id.buildSuffix.hex}"
  }
}

resource "aws_lb_target_group" "juiceShopAppTG" {
  name = "${var.projectPrefix}-juiceShopAppTG-${random_id.buildSuffix.hex}"
  port = 80
  protocol = "TCP"
  vpc_id = aws_vpc.juiceShopAppVPC.id
  health_check {
    enabled = true
    interval = 10
  }
  tags = {
    Name = "${var.projectPrefix}-juiceShopAppTG-${random_id.buildSuffix.hex}"
  }  
}

resource "aws_lb_listener" "juiceShopAppNLBListener" {
  load_balancer_arn = aws_lb.juiceShopAppNLB.arn
  port = "80"
  protocol = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.juiceShopAppTG.arn
    type = "forward"
  }
}

resource "aws_lb_target_group_attachment" "juiceShopAppAZ1TGAttachment" {
  target_group_arn = aws_lb_target_group.juiceShopAppTG.arn
  target_id = aws_instance.juiceShopAppAZ1.id
}

resource "aws_lb_target_group_attachment" "juiceShopAppAZ2TGAttachment" {
  target_group_arn = aws_lb_target_group.juiceShopAppTG.arn
  target_id = aws_instance.juiceShopAppAZ2.id
}

##
## Security Service Insertion
##

resource "aws_subnet" "juiceShopAppGWLBESubnetAZ1" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  cidr_block = var.juiceShopAppGWLBESubnetAZ1
  availability_zone = local.awsAz1
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppGWLBESubnetAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_subnet" "juiceShopAppGWLBESubnetAZ2" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  cidr_block = var.juiceShopAppGWLBESubnetAZ2
  availability_zone = local.awsAz2
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAppGWLBESubnetAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_vpc_endpoint" "juiceShopAppEndpointAZ1" {
  service_name = aws_vpc_endpoint_service.securityServicesES.service_name
  vpc_id = aws_vpc.juiceShopAppVPC.id
  vpc_endpoint_type = aws_vpc_endpoint_service.securityServicesES.service_type
  subnet_ids = [aws_subnet.juiceShopAppGWLBESubnetAZ1.id]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAppEndpointAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_vpc_endpoint" "juiceShopAppEndpointAZ2" {
  service_name = aws_vpc_endpoint_service.securityServicesES.service_name
  vpc_id = aws_vpc.juiceShopAppVPC.id
  vpc_endpoint_type = aws_vpc_endpoint_service.securityServicesES.service_type
  subnet_ids = [aws_subnet.juiceShopAppGWLBESubnetAZ2.id]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAppEndpointAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_route_table" "juiceShopAppGWLBInboundRT" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  route {
    cidr_block = var.juiceShopAppSubnetAZ1
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAppEndpointAZ1.id
  }
  route {
    cidr_block = var.juiceShopAppSubnetAZ2
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAppEndpointAZ2.id
  }
  tags = {
    Name = "juiceShopAppGWLBInboundRT"
  }
}

resource "aws_route_table_association" "juiceShopAppGWLBInboundRT" {
  gateway_id = aws_internet_gateway.juiceShopAppIGW.id
  route_table_id = aws_route_table.juiceShopAppGWLBInboundRT.id
}

resource "aws_route_table" "juiceShopAppGWLBOutboundRTAZ1" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAppEndpointAZ1.id
  }
  tags = {
    Name = "juiceShopAppGWLBOutboundRTAZ1"
  }
}

resource "aws_route_table_association" "juiceShopAppGWLBOutboundRTAZ1" {
  route_table_id = aws_route_table.juiceShopAppGWLBOutboundRTAZ1.id  
  subnet_id = aws_subnet.juiceShopAppSubnetAZ1.id
}

resource "aws_route_table" "juiceShopAppGWLBOutboundRTAZ2" {
  vpc_id = aws_vpc.juiceShopAppVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAppEndpointAZ2.id
  }
  tags = {
    Name = "juiceShopAppGWLBOutboundRTAZ2"
  }
}

resource "aws_route_table_association" "juiceShopAppGWLBOutboundRTAZ2" {
  route_table_id = aws_route_table.juiceShopAppGWLBOutboundRTAZ2.id  
  subnet_id = aws_subnet.juiceShopAppSubnetAZ2.id
}

####################################################################
########################## Juice Shop API ##########################
####################################################################

##
## VPC
##

resource "aws_vpc" "juiceShopAPIVPC" {
  cidr_block = var.juiceShopAPICIDR
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPIVPC-${random_id.buildSuffix.hex}"
  }
}

resource "aws_default_security_group" "juiceShopAPISG" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPISG-${random_id.buildSuffix.hex}"
  }
  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [var.juiceShopAPICIDR]
  }

  ingress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks = [format("%s/%s",data.http.ip_address.body,32)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "juiceShopAPISubnetAZ1" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  cidr_block = var.juiceShopAPISubnetAZ1
  availability_zone = local.awsAz1
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPISubnetAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_subnet" "juiceShopAPISubnetAZ2" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  cidr_block = var.juiceShopAPISubnetAZ2
  availability_zone = local.awsAz2
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPISubnetAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_internet_gateway" "juiceShopAPIIGW" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPIIGW-${random_id.buildSuffix.hex}"
  }
}

resource "aws_default_route_table" "juiceShopAPIMainRT" {
  default_route_table_id = aws_vpc.juiceShopAPIVPC.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.juiceShopAPIIGW.id
  }
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPIMainRT-${random_id.buildSuffix.hex}"
  }
}

##
## Juice Shop API AZ1
##

resource "aws_network_interface" "juiceShopAPIAZ1ENI" {
  subnet_id       = aws_subnet.juiceShopAPISubnetAZ1.id
  tags = {
    Name = "juiceShopAPIAZ1ENI"
  }
}

resource "aws_eip" "juiceShopAPIAZ1EIP" {
  vpc = true
  network_interface = aws_network_interface.juiceShopAPIAZ1ENI.id
  associate_with_private_ip = aws_network_interface.juiceShopAPIAZ1ENI.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.juiceShopAPIIGW
  ]
  tags = {
    Name = "juiceShopAPIAZ1EIP"
  }
}

resource "aws_instance" "juiceShopAPIAZ1" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "m5.xlarge"
  availability_zone = local.awsAz1
  key_name          = aws_key_pair.deployer.id
	user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt -y upgrade
              sudo apt -y install apt-transport-https ca-certificates curl software-properties-common docker
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
              sudo apt update
              sudo apt-cache policy docker-ce
              sudo apt -y install docker-ce
              sudo usermod -aG docker ubuntu
              docker pull bkimminich/juice-shop
              docker run -d -p 80:3000 --restart unless-stopped bkimminich/juice-shop
              sudo reboot
              EOF    
  network_interface {
    network_interface_id = aws_network_interface.juiceShopAPIAZ1ENI.id
    device_index = 0
  }
  # Let's ensure an EIP is provisioned so user-data can run successfully
  depends_on = [
    aws_eip.juiceShopAPIAZ1EIP
  ]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAPIAZ1-${random_id.buildSuffix.hex}"
  }
}

##
## Juice Shop API AZ2
##

resource "aws_network_interface" "juiceShopAPIAZ2ENI" {
  subnet_id       = aws_subnet.juiceShopAPISubnetAZ2.id
  tags = {
    Name = "juiceShopAPIAZ2ENI"
  }
}

resource "aws_eip" "juiceShopAPIAZ2EIP" {
  vpc = true
  network_interface = aws_network_interface.juiceShopAPIAZ2ENI.id
  associate_with_private_ip = aws_network_interface.juiceShopAPIAZ2ENI.private_ip
  # The IGW needs to exist before the EIP can be created
  depends_on = [
    aws_internet_gateway.juiceShopAPIIGW
  ]
  tags = {
    Name = "juiceShopAPIAZ2EIP"
  }
}

resource "aws_instance" "juiceShopAPIAZ2" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = "m5.xlarge"
  availability_zone = local.awsAz2
  key_name          = aws_key_pair.deployer.id
	user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt -y upgrade
              sudo apt -y install apt-transport-https ca-certificates curl software-properties-common docker
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
              sudo apt update
              sudo apt-cache policy docker-ce
              sudo apt -y install docker-ce
              sudo usermod -aG docker ubuntu
              docker pull bkimminich/juice-shop
              docker run -d -p 80:3000 --restart unless-stopped bkimminich/juice-shop
              sudo reboot
              EOF    
  network_interface {
    network_interface_id = aws_network_interface.juiceShopAPIAZ2ENI.id
    device_index = 0
  }
  # Let's ensure an EIP is provisioned so user-data can run successfully
  depends_on = [
    aws_eip.juiceShopAPIAZ2EIP
  ]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAPIAZ2-${random_id.buildSuffix.hex}"
  }
}

##
## Network Load Balancing for API
##

resource "aws_lb" "juiceShopAPINLB" {
  name = "${var.projectPrefix}-juiceShopAPINLB-${random_id.buildSuffix.hex}"
  load_balancer_type = "network"
  internal = false
  subnet_mapping {
    subnet_id = aws_subnet.juiceShopAPISubnetAZ1.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.juiceShopAPISubnetAZ2.id
  }
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "${var.projectPrefix}-juiceShopAPINLB-${random_id.buildSuffix.hex}"
  }
}

resource "aws_lb_target_group" "juiceShopAPITG" {
  name = "${var.projectPrefix}-juiceShopAPITG-${random_id.buildSuffix.hex}"
  port = 80
  protocol = "TCP"
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  health_check {
    enabled = true
    interval = 10
  }
  tags = {
    Name = "${var.projectPrefix}-juiceShopAPITG-${random_id.buildSuffix.hex}"
  }  
}

resource "aws_lb_listener" "juiceShopAPINLBListener" {
  load_balancer_arn = aws_lb.juiceShopAPINLB.arn
  port = "80"
  protocol = "TCP"
  default_action {
    target_group_arn = aws_lb_target_group.juiceShopAPITG.arn
    type = "forward"
  }
}

resource "aws_lb_target_group_attachment" "juiceShopAPIAZ1TGAttachment" {
  target_group_arn = aws_lb_target_group.juiceShopAPITG.arn
  target_id = aws_instance.juiceShopAPIAZ1.id
}

resource "aws_lb_target_group_attachment" "juiceShopAPIAZ2TGAttachment" {
  target_group_arn = aws_lb_target_group.juiceShopAPITG.arn
  target_id = aws_instance.juiceShopAPIAZ2.id
}

##
## Security Service Insertion
##

resource "aws_subnet" "juiceShopAPIGWLBESubnetAZ1" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  cidr_block = var.juiceShopAPIGWLBESubnetAZ1
  availability_zone = local.awsAz1
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPIGWLBESubnetAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_subnet" "juiceShopAPIGWLBESubnetAZ2" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  cidr_block = var.juiceShopAPIGWLBESubnetAZ2
  availability_zone = local.awsAz2
  tags = {
    Name  = "${var.projectPrefix}-juiceShopAPIGWLBESubnetAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_vpc_endpoint" "juiceShopAPIEndpointAZ1" {
  service_name = aws_vpc_endpoint_service.securityServicesES.service_name
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  vpc_endpoint_type = aws_vpc_endpoint_service.securityServicesES.service_type
  subnet_ids = [aws_subnet.juiceShopAPIGWLBESubnetAZ1.id]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAPIEndpointAZ1-${random_id.buildSuffix.hex}"
  }
}

resource "aws_vpc_endpoint" "juiceShopAPIEndpointAZ2" {
  service_name = aws_vpc_endpoint_service.securityServicesES.service_name
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  vpc_endpoint_type = aws_vpc_endpoint_service.securityServicesES.service_type
  subnet_ids = [aws_subnet.juiceShopAPIGWLBESubnetAZ2.id]
  tags = {
    Name = "${var.projectPrefix}-juiceShopAPIEndpointAZ2-${random_id.buildSuffix.hex}"
  }
}

resource "aws_route_table" "juiceShopAPIGWLBInboundRT" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  route {
    cidr_block = var.juiceShopAPISubnetAZ1
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAPIEndpointAZ1.id
  }
  route {
    cidr_block = var.juiceShopAPISubnetAZ2
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAPIEndpointAZ2.id
  }
  tags = {
    Name = "juiceShopAPIGWLBInboundRT"
  }
}

resource "aws_route_table_association" "juiceShopAPIGWLBInboundRT" {
  gateway_id = aws_internet_gateway.juiceShopAPIIGW.id
  route_table_id = aws_route_table.juiceShopAPIGWLBInboundRT.id
}

resource "aws_route_table" "juiceShopAPIGWLBOutboundRTAZ1" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAPIEndpointAZ1.id
  }
  tags = {
    Name = "juiceShopAPIGWLBOutboundRTAZ1"
  }
}

resource "aws_route_table_association" "juiceShopAPIGWLBOutboundRTAZ1" {
  route_table_id = aws_route_table.juiceShopAPIGWLBOutboundRTAZ1.id  
  subnet_id = aws_subnet.juiceShopAPISubnetAZ1.id
}

resource "aws_route_table" "juiceShopAPIGWLBOutboundRTAZ2" {
  vpc_id = aws_vpc.juiceShopAPIVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.juiceShopAPIEndpointAZ2.id
  }
  tags = {
    Name = "juiceShopAPIGWLBOutboundRTAZ2"
  }
}

resource "aws_route_table_association" "juiceShopAPIGWLBOutboundRTAZ2" {
  route_table_id = aws_route_table.juiceShopAPIGWLBOutboundRTAZ2.id  
  subnet_id = aws_subnet.juiceShopAPISubnetAZ2.id
}
