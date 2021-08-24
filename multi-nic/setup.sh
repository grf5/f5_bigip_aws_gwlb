#!/bin/bash
# init to ensure we have proper providers
terraform -chdir=vpcs init -upgrade
# run the plan to ensure we have proper configuration
terraform -chdir=vpcs plan -input=false -var-file=../admin.auto.tfvars -out tfplan
# apply if no error
test $? -eq 0 && terraform -chdir=vpcs apply -input=false --auto-approve tfplan || echo "There was an error during Terraform plan execution; aborting apply action."; 
