/usr/local/bin/terraform apply --auto-approve
/usr/local/bin/ansible-playbook -i ../ansible-gap/inventory.yaml ../ansible-gap/01-tfgap.yaml