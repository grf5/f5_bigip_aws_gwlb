# F5 BIG-IP Terraform Plan for Amazon Web Services Gateway Load Balancer

## Overview
This Terraform plan deploys a proof-of-concept environment for the F5 BIG-IP VE deployed in an AWS Gateway Load Balancer (GWLB) Configuration.

BIG-IP licensing and configuration is performed via [f5-bigip-runtime-init](https://github.com/F5Networks/f5-bigip-runtime-init).

## Diagram

![GWLB Diagram](diagram.png)

### Inventory:
* EC2 Account
    * BIG-IP 15.1.2.1 EHF AMI (required to deploy this plan; can use Marketlace images soon)    
* Security Services VPC
    * Internet Gateway (for mgmt reachability)
    * Security Group (Mgmt Reachability)
    * Main Route Table
    * Availability Zone 1
        * BIG-IP 15.1.2.1
    * Availability Zone 2
        * BIG-IP 15.1.2.1
* Juice Shop Web App VPC
    * NLB w/ Juice Shop server targets
    * Security Group (Mgmt and App Reachability)
    * Main Route Table
    * Ingress Route Table (attached to IGW)
    * Availability Zone 1
        * Egress Route Table
        * Juice Shop App Server (Ubuntu)
            * Juice Shop Container (Docker)
            * EIP for mgmt reachability
    * Availability Zone 2
        * Egress Route Table
        * Juice Shop App Server (Ubuntu)
            * Juice Shop Container (Docker)
            * EIP for mgmt reachability
* Juice Shop Web API VPC
    * NLB w/ Juice Shop server targets
    * Security Group (Mgmt and App Reachability)
    * Main Route Table
    * Ingress Route Table (attached to IGW)
    * Availability Zone 1
        * Egress Route Table
        * Juice Shop API Server (Ubuntu)
            * Juice Shop Container (Docker)
            * EIP for mgmt reachability
    * Availability Zone 2
        * Egress Route Table
        * Juice Shop API Server (Ubuntu)
            * Juice Shop Container (Docker)
            * EIP for mgmt reachability

## Notes
- Security groups will automatically allow connections from the host where the Terraform plan was executed.
- Route tables will steer ingress traffic to the GWLB endpoint, and egress server traffic to the GWLB endpoint. The main route table steers inspected traffic destined for the Internet back to the igw as a default route.
- GWLB GENEVE tunnel configuration is performed automatically.

## Usage
1. Copy admin.auto.tfvars.example to admin.auto.tfvars and populate all variables with valid values.
2. Execute the "./setup.sh" shell script to deploy.

## Debugging

Logs are sent to /var/log/cloud.

If licensing fails, the initial configuration will not complete successfully. You can re-run the initial configuration using the following commands:

```
cd /config/cloud
bash manual_run.sh
```

## Errors
There is a known issue in the AWS provider where EIPs cannot be configured because the ENI is not ready yet. **To continue, simply run the ./setup.sh script again and the installation will continue.** If this is an issue for you, please "thumbs up" the issue I created: https://github.com/hashicorp/terraform-provider-aws/issues/19699

Error Message:
```
╷
│ Error: Failure associating EIP: IncorrectInstanceState: The pending-instance-creation instance to which 'eni-0ee36cd9d3c25cd44' is attached is not in a valid state for this operation
│       status code: 400, request id: 55e6ac47-2e3a-4c60-8e48-bb756f822ba0
│ 
│   with aws_eip.F5_BIGIP_AZ2EIP,
│   on main.tf line 253, in resource "aws_eip" "F5_BIGIP_AZ2EIP":
│  253: resource "aws_eip" "F5_BIGIP_AZ2EIP" {
│ 
╵
```

## Development
Requires:
* Terraform 0.15.5
* AWS provider 0.3.45 
* HTTP 2.1.0

## Support
This project offers no official support from F5 and is best-effort by the community.

## Community Code of Conduct
Please refer to the [F5 DevCentral Community Code of Conduct](code_of_conduct.md).

## License
[Apache License 2.0](LICENSE)

## Copyright
Copyright 2014-2021 F5 Networks Inc.

### F5 Networks Contributor License Agreement
Before you start contributing to any project sponsored by F5 Networks, Inc. (F5) on GitHub, you will need to sign a Contributor License Agreement (CLA).

If you are signing as an individual, we recommend that you talk to your employer (if applicable) before signing the CLA since some employment agreements may have restrictions on your contributions to other projects.
Otherwise by submitting a CLA you represent that you are legally entitled to grant the licenses recited therein.

If your employer has rights to intellectual property that you create, such as your contributions, you represent that you have received permission to make contributions on behalf of that employer, that your employer has waived such rights for your contributions, or that your employer has executed a separate CLA with F5.

If you are signing on behalf of a company, you represent that you are legally entitled to grant the license recited therein.
You represent further that each employee of the entity that submits contributions is authorized to submit such contributions on behalf of the entity pursuant to the CLA.
