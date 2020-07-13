# main.tf
# main terraform file for APIC policy as code
# since 2020.06.24

provider "aci" {
  username = var.apic_user
  password = var.apic_password
  url      = var.apic_url
  insecure = var.apic_insecure
}

#####
# Goal - to setup fabric to useable state to be ready for l3out & overlay policies
#####
# ** can't find below terraform resources so did it manually but leave them here for references to fabric init steps
# - route reflector policy
# - OOB management IP address
# - DNS policy
# - time zone
# - NTP policy
#####
# this script will do
# - register node fabric membership
# - populate common fabric access policies (link_level, cdp, lldp, port_channel)
# - .. also vlan pool, physical domain (l3out will stick to a tenant)
# - populate leaf switch + interface profile according to node fabric membership
# - create vpc policy, AEP and apply to interfaces

# great list of data and resources:
# https://github.com/terraform-providers/terraform-provider-aci/tree/master/aci

#===== node fabric membership and vpc protection group

resource "aci_fabric_node_member" "irvsdc2-aci-n101" {
  serial  = "FDO22181CK7"
  pod_id  = "1"
  node_id = "101"
  name    = "irvsdc2-aci-n101"
  # role    = "spine"
}

resource "aci_fabric_node_member" "irvsdc2-aci-n102" {
  serial  = "FDO22350P3U"
  pod_id  = "1"
  node_id = "102"
  name    = "irvsdc2-aci-n102"
  # role    = "spine"
}

resource "aci_fabric_node_member" "irvsdc2-aci-n201" {
  serial  = "FDO22273SZD"
  pod_id  = "1"
  node_id = "201"
  name    = "irvsdc2-aci-n201"
  # role    = "leaf"
}

resource "aci_fabric_node_member" "irvsdc2-aci-n202" {
  serial  = "FDO21270V6D"
  pod_id  = "1"
  node_id = "202"
  name    = "irvsdc2-aci-n202"
  # role    = "leaf"
}

resource "aci_vpc_explicit_protection_group" "leaf-201-202_vpcgrp" {
  name                             = "leaf-201-202_vpcgrp"
  switch1                          = "201"
  switch2                          = "202"
  vpc_explicit_protection_group_id = "201"
}

#===== populate common fabric access policies
# (link_level, cdp, lldp, port_channel)
# no link_leve policy so let's see if it'll work on default

resource "aci_cdp_interface_policy" "cdp-on" {
  name     = "cdp-on"
  admin_st = "enabled"
}

resource "aci_cdp_interface_policy" "cdp-off" {
  name     = "cdp-off"
  admin_st = "disabled"
}

resource "aci_lldp_interface_policy" "lldp-on" {
  name        = "lldp-on"
  admin_rx_st = "enabled"
  admin_tx_st = "disabled"
}

resource "aci_lldp_interface_policy" "lldp-off" {
  name        = "lldp-on"
  admin_rx_st = "enabled"
  admin_tx_st = "disabled"
}

resource "aci_lacp_policy" "lacp-active" {
  name = "lacp-active"
  ctrl = "fast-sel-hot-stdby,graceful-conv,susp-individual,symmetric-hash"
  mode = "active"
}

#===== create vlan pools and physical domain

resource "aci_vlan_pool" "irvsdc2_vlpool" {
  name       = "irvsdc2_vlpool"
  alloc_mode = "dynamic"
}

resource "aci_ranges" "vlpool1" {
  vlan_pool_dn = aci_vlan_pool.irvsdc2_vlpool.id
  _from        = "vlan-100"
  to           = "vlan-1000"
  alloc_mode   = "static"
  description  = "static vlan range"
  role         = "external"
}

resource "aci_ranges" "vlpool2" {
  vlan_pool_dn = aci_vlan_pool.irvsdc2_vlpool.id
  _from        = "vlan-1001"
  to           = "vlan-3000"
  alloc_mode   = "dynamic"
  description  = "dynamic vlan range"
  role         = "external"
}

resource "aci_physical_domain" "irvsdc2_physdom" {
  name                      = "irvsdc2_physdom"
  relation_infra_rs_vlan_ns = aci_vlan_pool.irvsdc2_vlpool.id
}

#===== populate leaf switch + interface profile

resource "aci_leaf_interface_profile" "leaf-201-202" {
  name = "leaf-201-202"
}

resource "aci_leaf_profile" "leaf-201-202" {
  name                         = "leaf-201-202"
  relation_infra_rs_acc_port_p = [aci_leaf_interface_profile.leaf-201-202.id]
}

resource "aci_switch_association" "leaf-201-202" {
  leaf_profile_dn                  = aci_leaf_profile.leaf-201-202.id
  name                             = "leaf-201-202"
  switch_association_type          = "range"
  relation_infra_rs_acc_node_p_grp = aci_leaf_interface_profile.leaf-201-202.id
}

resource "aci_node_block" "leaf-201-202" {
  switch_association_dn = aci_switch_association.leaf-201-202.id
  name                  = "leaf-201-202"
  from_                 = "201"
  to_                   = "202"
}

#===== create vpc policy, AEP and apply to interfaces: for irvsdc2-isn1&2
# - AEP
# - interface policy group
# - interface selector

# create AEP, associate it to a domain
resource "aci_attachable_access_entity_profile" "irvsdc2-isn_aep" {
  name                    = "irvsdc2-isn_aep"
  relation_infra_rs_dom_p = [aci_physical_domain.irvsdc2_physdom.id, aci_l3_domain_profile.irvsdc2-isn_l3dom.id]
}

# create vpc interface port group, give it policies, associate to AEP for isn1
resource "aci_pcvpc_interface_policy_group" "irvsdc2-isn1_vpcipg" {
  name                          = "irvsdc2-isn1_vpcipg"
  lag_t                         = "node"
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp-on.id
  relation_infra_rs_lacp_pol    = aci_lacp_policy.lacp-active.id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.cdp-on.id
  relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.irvsdc2-isn_aep.id
}

# same thing for isn2
resource "aci_pcvpc_interface_policy_group" "irvsdc2-isn2_vpcipg" {
  name                          = "irvsdc2-isn2_vpcipg"
  lag_t                         = "node"
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp-on.id
  relation_infra_rs_lacp_pol    = aci_lacp_policy.lacp-active.id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.cdp-on.id
  relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.irvsdc2-isn_aep.id
}

# create port selector, associate to interface port group, isn1
resource "aci_access_port_selector" "n201-202_e41" {
  leaf_interface_profile_dn      = aci_leaf_interface_profile.leaf-201-202.id
  name                           = "e41"
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_pcvpc_interface_policy_group.irvsdc2-isn1_vpcipg.id
}

# create port block, associate to port selector, isn1
resource "aci_access_port_block" "n201-202_e41" {
  access_port_selector_dn = aci_access_port_selector.n201-202_e41.id
  name                    = "e41"
  from_port               = "41"
  to_port                 = "41"
}

# create port selector, associate to interface port group, isn1
resource "aci_access_port_selector" "n201-202_e42" {
  leaf_interface_profile_dn      = aci_leaf_interface_profile.leaf-201-202.id
  name                           = "e42"
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_pcvpc_interface_policy_group.irvsdc2-isn2_vpcipg.id
}

# create port block, associate to port selector, isn1
resource "aci_access_port_block" "n201-202_e42" {
  access_port_selector_dn = aci_access_port_selector.n201-202_e42.id
  name                    = "e42"
  from_port               = "42"
  to_port                 = "42"
}

#===== create vpc policy, AEP and apply to interfaces: for irvsdc2-fi1
# !! make sure port e49-50,51-52 are downlinks
# - AEP (Attachable Entity Profile)
# - interface policy group
# - interface selector

# create AEP, associate it to a domain
# AEP groups ports with similar policies so we only need one AEP for a pair of FI
resource "aci_attachable_access_entity_profile" "irvsdc2-fi1_aep" {
  name                    = "irvsdc2-fi1_aep"
  relation_infra_rs_dom_p = [aci_physical_domain.irvsdc2_physdom.id]
}

# create vpc interface port group, give it policies, associate to AEP for fi1a
# this is equivalent to vpc port group in nx-os, so we need for fi-A and one for fi-B
resource "aci_pcvpc_interface_policy_group" "irvsdc2-fi1a_vpcipg" {
  name                          = "irvsdc2-fi1a_vpcipg"
  lag_t                         = "node"
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp-on.id
  relation_infra_rs_lacp_pol    = aci_lacp_policy.lacp-active.id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.cdp-on.id
  # bind this to the AEP above
  relation_infra_rs_att_ent_p = aci_attachable_access_entity_profile.irvsdc2-fi1_aep.id
}

# same thing for fi1b
resource "aci_pcvpc_interface_policy_group" "irvsdc2-fi1b_vpcipg" {
  name                          = "irvsdc2-fi1b_vpcipg"
  lag_t                         = "node"
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp-on.id
  relation_infra_rs_lacp_pol    = aci_lacp_policy.lacp-active.id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.cdp-on.id
  # bind this to the AEP above
  relation_infra_rs_att_ent_p = aci_attachable_access_entity_profile.irvsdc2-fi1_aep.id
}
# with this we then only need to manipulate overlay policy on AEP and all the related vpc and member ports gets the connectivity

# create port selector, associate to interface port group, fi1a
resource "aci_access_port_selector" "n201-202_e51" {
  leaf_interface_profile_dn      = aci_leaf_interface_profile.leaf-201-202.id
  name                           = "e51"
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_pcvpc_interface_policy_group.irvsdc2-fi1a_vpcipg.id
}

# create port block, associate to port selector, fi1a
resource "aci_access_port_block" "n201-202_e51" {
  access_port_selector_dn = aci_access_port_selector.n201-202_e51.id
  name                    = "e51"
  from_port               = "51"
  to_port                 = "51"
}

# create port selector, associate to interface port group, fi1b
resource "aci_access_port_selector" "n201-202_e52" {
  leaf_interface_profile_dn      = aci_leaf_interface_profile.leaf-201-202.id
  name                           = "e52"
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_pcvpc_interface_policy_group.irvsdc2-fi1b_vpcipg.id
}

# create port block, associate to port selector, fi1b
resource "aci_access_port_block" "n201-202_e52" {
  access_port_selector_dn = aci_access_port_selector.n201-202_e52.id
  name                    = "e52"
  from_port               = "52"
  to_port                 = "52"
}
