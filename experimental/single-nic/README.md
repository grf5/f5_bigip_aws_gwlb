# F5 BIG-IP Terraform Plan for Amazon Web Services Gateway Load Balancer


## WARNING
**Do not use the single NIC plan for production/testing. This plan is used for internal F5 testing and is not advised for use at this time.**

## Overview
This Terraform plan deploys a proof-of-concept environment for the F5 BIG-IP VE deployed in an AWS Gateway Load Balancer (GWLB) Configuration

## Usage
#. Copy admin.auto.tfvars.example to admin.auto.tfvars and populate all variables with valid values.
#. Execute the "./setup.sh" shell script to deploy.

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
Requires Terraform 0.15.5 and AWS provider 0.3.44 (as of June 2021)

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
