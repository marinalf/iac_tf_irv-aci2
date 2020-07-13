# tenant-irvsdc2.tf
# terraform file for APIC policy as code
# specific to tenant: irvsdc2
# since 2020.07.05

# declare provider, won't need as it's in main.tf
# provider "aci" {
#   username = var.apic_user
#   password = var.apic_password
#   url      = var.apic_url
#   insecure = var.apic_insecure
# }

#===== Summary of steps
# - tenant
# - l3out, in this case for peering with irvsdc2-isn1&2
# - VRF
# - bridge domain
# - application profile
# - end point group
# - bind EPG into AEP
#   - irvsdc2-isn1&2 not needed for now, maybe later for oob
#   - irvsdc2-fi1&2 giving it vlans

# create tenant: irvsdc2
resource "aci_tenant" "irvsdc2" {
  name        = "irvsdc2"
  description = "site-specific infrastructure for irvsdc2"
}

# create VRF
resource "aci_vrf" "main_vrf" {
  tenant_dn = aci_tenant.irvsdc2.id
  name      = "main_vrf"
  # keep things to default value for now
  bd_enforced_enable     = "no"
  ip_data_plane_learning = "enabled"
  pc_enf_dir             = "ingress"
  pc_enf_pref            = "enforced"
}

# create l3out

resource "aci_l3_domain_profile" "irvsdc2-isn_l3dom" {
  name                      = "irvsdc2-isn_l3dom"
  relation_infra_rs_vlan_ns = aci_vlan_pool.irvsdc2_vlpool.id
}

resource "aci_l3_outside" "irvsdc2-main_l3out" {
  tenant_dn                    = aci_tenant.irvsdc2.id
  name                         = "irvsdc2-main_l3out"
  relation_l3ext_rs_ectx       = aci_vrf.main_vrf.id
  relation_l3ext_rs_l3_dom_att = aci_l3_domain_profile.irvsdc2-isn_l3dom.id
}

# !!! gap - bind l3out to vrf - address in -rest.tf
# !!! gap - bind l3out to l3dom - address in -rest.tf

resource "aci_logical_node_profile" "leaf-201-202" {
  l3_outside_dn = aci_l3_outside.irvsdc2-main_l3out.id
  name          = "leaf-201-202"
}

# bind the node profile to the node with router id
# 2020.07.06 - rtr_id_loop_back errors out somehow but it's picking up rtr_id by default so moving on
resource "aci_logical_node_to_fabric_node" "n201" {
  logical_node_profile_dn = aci_logical_node_profile.leaf-201-202.id
  tdn                     = "topology/pod-1/node-201"
  rtr_id                  = "192.168.255.5"
  # rtr_id_loop_back = "192.1682.255.4"
}

resource "aci_logical_node_to_fabric_node" "n202" {
  logical_node_profile_dn = aci_logical_node_profile.leaf-201-202.id
  tdn                     = "topology/pod-1/node-202"
  rtr_id                  = "192.168.255.6"
  #rtr_id_loop_back = "192.1682.255.5"
}

resource "aci_logical_interface_profile" "e41-42" {
  logical_node_profile_dn = aci_logical_node_profile.leaf-201-202.id
  name                    = "e41-42"
  # there's a clue to use this attribute for path setup but need more info
  # relation_l3ext_rs_path_l3_out_att = [
  #       "topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn1_vpcipg]",
  #   ]
}

resource "aci_ospf_interface_policy" "irvsdc2-isn-main_ospfintfpol" {
  tenant_dn = aci_tenant.irvsdc2.id
  name      = "irvsdc2-isn-main_ospfintfpol"
  nw_t      = "bcast"
  ctrl      = "mtu-ignore"
  cost      = "50000"
}

# !!! address these in -rest.tf
# !!! gap - also don't know how to enable ospf on l3out
# !!! gap - don't know how to set svi ip address in logical interface profile
# !!! gap - no ospf interface profile so can't attach ospf interface policy to logical interface profile

#===== on to external EPG
resource "aci_external_network_instance_profile" "irvsdc2-main_l3outepg" {
  l3_outside_dn       = aci_l3_outside.irvsdc2-main_l3out.id
  name                = "irvsdc2-main_l3outepg"
  description         = "default route 0.0.0.0/0 for irvsdc2-main vrf"
  relation_fv_rs_prov = [aci_contract.unimatrix0.id]
  relation_fv_rs_cons = [aci_contract.unimatrix0.id]
}

# then associate a subnet to it
resource "aci_l3_ext_subnet" "irvsdc2-main_l3outepg_default_subnet" {
  external_network_instance_profile_dn = aci_external_network_instance_profile.irvsdc2-main_l3outepg.id
  ip                                   = "0.0.0.0/0"
}

#===== on to overlay policies

resource "aci_bridge_domain" "vl697-10_95_19_96_27_bd" {
  tenant_dn                = aci_tenant.irvsdc2.id
  name                     = "vl697-10_95_19_96_27_bd"
  relation_fv_rs_ctx       = aci_vrf.main_vrf.id
  relation_fv_rs_bd_to_out = [aci_l3_outside.irvsdc2-main_l3out.id]
}

resource "aci_subnet" "vl697-10_95_19_97_27_subnet" {
  bridge_domain_dn = aci_bridge_domain.vl697-10_95_19_96_27_bd.id
  ip               = "10.95.19.97/27"
  scope            = "public"
}

resource "aci_application_profile" "irvsdc2-infra_ap" {
  tenant_dn = aci_tenant.irvsdc2.id
  name      = "irvsdc2-infra_ap"
}

# in unimatrix-0 every borg can be who they are - 'allow ip any any'
resource "aci_contract" "unimatrix0" {
  tenant_dn = aci_tenant.irvsdc2.id
  name      = "unimatrix0"
  scope     = "tenant"
}

resource "aci_contract_subject" "ip_traffic" {
  contract_dn                  = aci_contract.unimatrix0.id
  name                         = "ip_traffic"
  relation_vz_rs_subj_filt_att = [aci_filter.ip_traffic.id]
}

resource "aci_filter" "ip_traffic" {
  tenant_dn = aci_tenant.irvsdc2.id
  name      = "ip_traffic"
}

resource "aci_filter_entry" "ip_traffic" {
  filter_dn = aci_filter.ip_traffic.id
  name      = "ip_traffic"
  ether_t   = "ip"
}

resource "aci_application_epg" "vl697-10_95_19_96_27_epg" {
  application_profile_dn = aci_application_profile.irvsdc2-infra_ap.id
  name                   = "vl697-10_95_19_96_27_epg"
  relation_fv_rs_bd      = aci_bridge_domain.vl697-10_95_19_96_27_bd.id
  # provide/consume contracts
  relation_fv_rs_prov = [aci_contract.unimatrix0.id]
  relation_fv_rs_cons = [aci_contract.unimatrix0.id]
  # bind this epg to physical domain
  relation_fv_rs_dom_att = [aci_physical_domain.irvsdc2_physdom.id]
}

#=== adding vMotion BD & EPG: vl709-192_168_9_0_24_epg
# remember to bind this to AEP with ansible

resource "aci_bridge_domain" "vl709-192_168_9_0_24_bd" {
  tenant_dn                = aci_tenant.irvsdc2.id
  name                     = "vl709-192_168_9_0_24_bd"
  relation_fv_rs_ctx       = aci_vrf.main_vrf.id
  relation_fv_rs_bd_to_out = [aci_l3_outside.irvsdc2-main_l3out.id]
}

resource "aci_subnet" "vl709-192_168_9_0_24_subnet" {
  bridge_domain_dn = aci_bridge_domain.vl709-192_168_9_0_24_bd.id
  ip               = "192.168.9.1/24"
  scope            = "public"
}

resource "aci_application_epg" "vl709-192_168_9_0_24_epg" {
  application_profile_dn = aci_application_profile.irvsdc2-infra_ap.id
  name                   = "vl709-192_168_9_0_24_epg"
  relation_fv_rs_bd      = aci_bridge_domain.vl709-192_168_9_0_24_bd.id
  # provide/consume contracts
  relation_fv_rs_prov = [aci_contract.unimatrix0.id]
  relation_fv_rs_cons = [aci_contract.unimatrix0.id]
  # bind this epg to physical domain
  relation_fv_rs_dom_att = [aci_physical_domain.irvsdc2_physdom.id]
}

#=== sample 3-tier EPG below

# resource "aci_application_epg" "web01_epg" {
#   application_profile_dn = aci_application_profile.irvsdc2-infra_ap.id
#   name = "web01_epg"
#   relation_fv_rs_bd = aci_bridge_domain.vl697-10_95_19_96_27_bd.id
#   # provide/consume contracts
#   relation_fv_rs_prov = [aci_contract.unimatrix0.id]
#   relation_fv_rs_cons = [aci_contract.unimatrix0.id]
#   # bind this epg to physical domain
#   relation_fv_rs_dom_att = [aci_physical_domain.irvsdc2_physdom.id]
# }

# resource "aci_application_epg" "db01_epg" {
#   application_profile_dn = aci_application_profile.irvsdc2-infra_ap.id
#   name = "db01_epg"
#   relation_fv_rs_bd = aci_bridge_domain.vl697-10_95_19_96_27_bd.id
#   # provide/consume contracts
#   relation_fv_rs_prov = [aci_contract.unimatrix0.id]
#   relation_fv_rs_cons = [aci_contract.unimatrix0.id]
#   # bind this epg to physical domain
#   relation_fv_rs_dom_att = [aci_physical_domain.irvsdc2_physdom.id]
# }

# resource "aci_application_epg" "monitoring01_epg" {
#   application_profile_dn = aci_application_profile.irvsdc2-infra_ap.id
#   name = "monitoring01_epg"
#   relation_fv_rs_bd = aci_bridge_domain.vl697-10_95_19_96_27_bd.id
#   # provide/consume contracts
#   relation_fv_rs_prov = [aci_contract.unimatrix0.id]
#   relation_fv_rs_cons = [aci_contract.unimatrix0.id]
#   # bind this epg to physical domain
#   relation_fv_rs_dom_att = [aci_physical_domain.irvsdc2_physdom.id]
# }
