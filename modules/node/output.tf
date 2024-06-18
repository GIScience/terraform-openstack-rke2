output "floating_ip" {
  value = openstack_networking_floatingip_associate_v2.associate_floating_ip[*].floating_ip
}

locals {
  raw_floating_ip_associations = merge([
    for assoc in openstack_compute_floatingip_associate_v2.associate_floating_ip: {
      for inst in openstack_compute_instance_v2.instance:
        inst.id == assoc.instance_id ? assoc.floating_ip : "" => inst.id == assoc.instance_id ? inst.name : ""...
    }
  ]...)
  remove_empty_keys = [ for k, v in local.raw_floating_ip_associations: k if k != ""]
  floating_ip_associations = { for key in local.remove_empty_keys: key => element(lookup(local.raw_floating_ip_associations, key), 0) }
}

output "floating_ip_associate" {
  value = local.floating_ip_associations
}

output "internal_ip" {
  value = openstack_compute_instance_v2.instance[*].access_ip_v4
}
