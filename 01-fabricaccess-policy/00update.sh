/usr/local/bin/terraform taint aci_rest.bind_vl697epg_to_aep
/usr/local/bin/terraform taint aci_rest.rest_enable_ospf_on_irvsdc2-main_l3out
/usr/local/bin/terraform taint aci_rest.rest_irvsdc2-main_l3out_to_irvsdc2-isn_l3dom
/usr/local/bin/terraform taint aci_rest.rest_create_ospf_intf_profile_and_attach_policy
/usr/local/bin/terraform taint aci_rest.rest_set_svi_on_irvsdc2-isn1
/usr/local/bin/terraform taint aci_rest.rest_set_svi_on_irvsdc2-isn2
/usr/local/bin/terraform apply --auto-approve
# /usr/local/bin/ansible-playbook -i ../ansible-gap/inventory.yaml ../ansible-gap/01-tfgap.yaml