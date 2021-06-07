resource "random_id" "buildSuffix" {
  byte_length = 2
}
variable "projectPrefix" {
  description = "projectPrefix name for tagging"
  default     = "gwlb-bigip"
}
variable "resourceOwner" {
  description = "Owner of the deployment for tagging purposes"
  default     = "grobinson"
}
variable "awsRegion" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
}
variable "awsAz1" {
  description = "Availability zone, will dynamically choose one if left empty"
  type        = string
  default     = null
}
variable "awsAz2" {
  description = "Availability zone, will dynamically choose one if left empty"
  type        = string
  default     = null
}
variable "adminSecret" {
  description = "BIG-IP admin user password"
  type = string
  default = null
  sensitive = true
}
variable "bigipLicenseAZ1" {
  description = "BIG-IP License for AZ1 instance"
  type = string
}
variable "bigipLicenseAZ2" {
  description = "BIG-IP License for AZ2 instance"
  type = string
}
variable "juiceShopAppCIDR" {
  description = "CIDR block for entire Juice Shop App VPC"
  default = "10.10.0.0/16"
  type = string
}
variable "juiceShopAppSubnetAZ1" {
  description = "Subnet for Juice Shop App AZ1"
  default = "10.10.100.0/24"
  type = string
}
variable "juiceShopAppSubnetAZ2" {
  description = "Subnet for Juice Shop App AZ2"
  default = "10.10.200.0/24"
  type = string
}
variable "juiceShopAppGWLBESubnetAZ1" {
  description = "Subnet for GWLB Endpoint in Juice Shop App AZ1"
  default = "10.10.101.0/24"
  type = string
}
variable "juiceShopAppGWLBESubnetAZ2" {
  description = "Subnet for GWLB Endpoint in Juice Shop App AZ2"
  default = "10.10.201.0/24"
  type = string
}
variable "juiceShopAPICIDR" {
  description = "CIDR block for entire Juice Shop API VPC"
  default = "10.20.0.0/16"
  type = string
}
variable "juiceShopAPISubnetAZ1" {
  description = "Subnet for Juice Shop API AZ1"
  default = "10.20.100.0/24"
  type = string
}
variable "juiceShopAPISubnetAZ2" {
  description = "Subnet for Juice Shop API AZ2"
  default = "10.20.200.0/24"
  type = string
}
variable "juiceShopAPIGWLBESubnetAZ1" {
  description = "Subnet for GWLB Endpoint in Juice Shop API AZ1"
  default = "10.20.101.0/24"
  type = string
}
variable "juiceShopAPIGWLBESubnetAZ2" {
  description = "Subnet for GWLB Endpoint in Juice Shop API AZ2"
  default = "10.20.201.0/24"
  type = string
}
variable "securityServicesCIDR" {
  description = "CIDR block for entire Security Services VPC"
  default = "10.250.0.0/16"
  type = string
}
variable "securityServicesSubnetAZ1" {
  description = "Subnet for Security Services AZ1"
  default = "10.250.150.0/24"
  type = string
}
variable "securityServicesSubnetAZ2" {
  description = "Subnet for Security Services AZ2"
  default = "10.250.250.0/24"
  type = string
}