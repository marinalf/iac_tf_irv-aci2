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

# !!! gap - bind l3out to l3dom - address in -rest.tf
resource "aci_rest" "rest_irvsdc2-main_l3out_to_irvsdc2-isn_l3dom" {
  path       = "/api/node/mo/${aci_l3_outside.irvsdc2-main_l3out.id}.json"
  payload    = <<EOF
  {
    "l3extOut": {
      "attributes": {
        "dn": "${aci_l3_outside.irvsdc2-main_l3out.id}",
        "status": "modified"
      },
      "children": [
        {
          "l3extRsL3DomAtt": {
            "attributes": {
              "tDn": "${aci_l3_domain_profile.irvsdc2-isn_l3dom.id}",
              "status": "created,modified"
            },
            "children": []
          }
        }
      ]
    }
  }
  EOF
  depends_on = [aci_l3_outside.irvsdc2-main_l3out]
}

# !!! gap - enable ospf on l3out
resource "aci_rest" "rest_enable_ospf_on_irvsdc2-main_l3out" {
  path       = "/api/node/mo/${aci_l3_outside.irvsdc2-main_l3out.id}/ospfExtP.json"
  payload    = <<EOF
  {
    "ospfExtP": {
      "attributes": {
        "dn": "uni/tn-irvsdc2/out-irvsdc2-main_l3out/ospfExtP",
        "areaId": "65201",
        "status": "created,modified",
        "areaType": "nssa"
      },
      "children": []
    }
  }
  EOF
  depends_on = [aci_l3_outside.irvsdc2-main_l3out]
}

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

# !!! gap - create ospf interface profile, attach to logical interface profile, bind with ospf policy
resource "aci_rest" "rest_create_ospf_intf_profile_and_attach_policy" {
  path       = "/api/node/mo/${aci_logical_interface_profile.e41-42.id}/ospfIfP.json"
  payload    = <<EOF
  {
    "ospfIfP": {
      "attributes": {
        "dn": "${aci_logical_interface_profile.e41-42.id}/ospfIfP",
        "rn": "ospfIfP",
        "status": "created,modified"
      },
      "children": [
        {
          "ospfRsIfPol": {
            "attributes": {
              "tnOspfIfPolName": "${aci_ospf_interface_policy.irvsdc2-isn-main_ospfintfpol.name}",
              "status": "created,modified"
            },
            "children": []
          }
        }
      ]
    }
  }
  EOF
  depends_on = [aci_logical_interface_profile.e41-42, aci_ospf_interface_policy.irvsdc2-isn-main_ospfintfpol]
}


# !!! gap - don't know how to set svi ip address in logical interface profile
# HARDCODED!!!
resource "aci_rest" "rest_set_svi_on_irvsdc2-isn1" {
  path       = "/api/node/mo/uni/tn-irvsdc2/out-irvsdc2-main_l3out/lnodep-leaf-201-202/lifp-e41-42/rspathL3OutAtt-[topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn1_vpcipg]].json"
  payload    = <<EOF
  {
    "l3extRsPathL3OutAtt": {
      "attributes": {
        "dn": "uni/tn-irvsdc2/out-irvsdc2-main_l3out/lnodep-leaf-201-202/lifp-e41-42/rspathL3OutAtt-[topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn1_vpcipg]]",
        "ifInstT": "ext-svi",
        "encap": "vlan-102",
        "mtu": "9216",
        "tDn": "topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn1_vpcipg]",
        "rn": "rspathL3OutAtt-[topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn1_vpcipg]]",
        "status": "created,modified"
      },
      "children": [
        {
          "l3extMember": {
            "attributes": {
              "addr": "192.168.254.17/29",
              "status": "created,modified",
              "side": "A"
            },
            "children": []
          }
        },
        {
          "l3extMember": {
            "attributes": {
              "side": "B",
              "addr": "192.168.254.18/29",
              "status": "created,modified"
            },
            "children": []
          }
        }
      ]
    }
  }
  EOF
  depends_on = [aci_logical_interface_profile.e41-42]
}

resource "aci_rest" "rest_set_svi_on_irvsdc2-isn2" {
  path       = "/api/node/mo/uni/tn-irvsdc2/out-irvsdc2-main_l3out/lnodep-leaf-201-202/lifp-e41-42/rspathL3OutAtt-[topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn2_vpcipg]].json"
  payload    = <<EOF
  {
    "l3extRsPathL3OutAtt": {
      "attributes": {
        "dn": "uni/tn-irvsdc2/out-irvsdc2-main_l3out/lnodep-leaf-201-202/lifp-e41-42/rspathL3OutAtt-[topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn2_vpcipg]]",
        #"mac": "00:22:BD:F8:19:FF",
        "ifInstT": "ext-svi",
        "encap": "vlan-103",
        "mtu": "9216",
        "tDn": "topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn2_vpcipg]",
        "rn": "rspathL3OutAtt-[topology/pod-1/protpaths-201-202/pathep-[irvsdc2-isn2_vpcipg]]",
        "status": "created,modified"
      },
      "children": [
        {
          "l3extMember": {
            "attributes": {
              "addr": "192.168.254.33/29",
              "status": "created,modified",
              "side": "A"
            },
            "children": []
          }
        },
        {
          "l3extMember": {
            "attributes": {
              "side": "B",
              "addr": "192.168.254.34/29",
              "status": "created,modified"
            },
            "children": []
          }
        }
      ]
    }
  }
  EOF
  depends_on = [aci_logical_interface_profile.e41-42]
}



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

#=====================================
#===== on to overlay policies, default

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

#===== then segmentation policy, default

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

#=== adding first infra EPG

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

# !!! gap - attempting to address tf gap with aci_rest
# must taint with: before apply
# > terraform taint aci_rest.bind_vl697epg_to_aep
resource "aci_rest" "bind_vl697epg_to_aep" {
  path       = "/api/node/mo/${aci_attachable_access_entity_profile.irvsdc2-fi1_aep.id}/gen-default.json"
  class_name = "infraRsFuncToEpg"
  content = {
    "tDn" : aci_application_epg.vl697-10_95_19_96_27_epg.id,
    "status" : "created,modified"
    "encap" : "vlan-697"
  }
  depends_on = [aci_application_epg.vl697-10_95_19_96_27_epg, aci_attachable_access_entity_profile.irvsdc2-fi1_aep]
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

# !!! gap - attempting to address tf gap with aci_rest
# must taint with: before apply
# > terraform taint aci_rest.bind_vl697epg_to_aep
resource "aci_rest" "bind_vl709epg_to_aep" {
  path       = "/api/node/mo/${aci_attachable_access_entity_profile.irvsdc2-fi1_aep.id}/gen-default.json"
  class_name = "infraRsFuncToEpg"
  content = {
    "tDn" : aci_application_epg.vl709-192_168_9_0_24_epg.id,
    "status" : "created,modified"
    "encap" : "vlan-697"
  }
  depends_on = [aci_application_epg.vl709-192_168_9_0_24_epg, aci_attachable_access_entity_profile.irvsdc2-fi1_aep]
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
