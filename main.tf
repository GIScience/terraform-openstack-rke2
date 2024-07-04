locals {
  node_config = {
    cluster_name       = var.cluster_name
    keypair_name       = module.keypair.keypair_name
    ssh_key_file       = var.ssh_key_file
    system_user        = var.system_user
    use_ssh_agent      = var.use_ssh_agent
    network_id         = local.nodes_net_id
    subnet_id          = local.nodes_subnet_id
    secgroup_id        = module.secgroup.secgroup_id
    server_affinity    = var.server_group_affinity
    config_drive       = var.nodes_config_drive
    floating_ip_pool   = var.public_net_name
    user_data          = var.user_data_file != null ? file(var.user_data_file) : null
    boot_from_volume   = var.boot_from_volume
    boot_volume_size   = var.boot_volume_size
    boot_volume_type   = var.boot_volume_type
    availability_zones = var.availability_zones
    bootstrap_server   = module.server.floating_ip[0]
    bastion_host       = module.server.floating_ip[0]
    rke2_token         = random_string.rke2_token.result
    registries_conf    = var.registries_conf
    proxy_url          = var.proxy_url
    no_proxy           = concat(["localhost", "127.0.0.1", "169.254.169.254", "127.0.0.0/8", "169.254.0.0/16", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], var.no_proxy)
  }
  tmpdir           = "${path.root}/.terraform/tmp/rke2"
  ssh_key_arg      = var.use_ssh_agent ? "" : "-i ${var.ssh_key_file}"
  ssh              = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${local.ssh_key_arg}"
  scp              = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${local.ssh_key_arg}"
  remote_rke2_yaml = "${var.system_user}@${module.server.floating_ip[0]}:/etc/rancher/rke2/rke2-remote.yaml"

  nodes_net_id      = var.use_existing_network ? var.existing_network_id : module.network.nodes_net_id
  nodes_subnet_id   = var.use_existing_network ? var.existing_subnet_id : module.network.nodes_subnet_id
  nodes_subent_cidr = var.use_existing_network ? var.existing_subnet_cidr : module.network.nodes_subnet_cidr
  router_ip         = var.use_existing_network ? var.existing_router_ip : module.network.router_ip

  secgroup_rules = concat(var.secgroup_rules, [
    {
      "port" : 9345
      "protocol" : "tcp"
      "source" : "${local.nodes_subent_cidr}"
    },
    {
      "port" : 6443
      "protocol" : "tcp"
      "source" : "${local.nodes_subent_cidr}"
    },
    {
      "port" : 10250
      "protocol" : "tcp"
      "source" : "${local.nodes_subent_cidr}"
    },
    {
      "port" : 51820
      "protocol" : "udp"
      "source" : "${local.nodes_subent_cidr}"
    }
  ])
}

module "keypair" {
  source           = "./modules/keypair"
  cluster_name     = var.cluster_name
  ssh_key_file     = var.ssh_key_file
  ssh_keypair_name = var.ssh_keypair_name
}

module "network" {
  source          = "./modules/network"
  count           = var.use_existing_network ? 0 : 1
  network_name    = "${var.cluster_name}-nodes-net"
  subnet_name     = "${var.cluster_name}-nodes-subnet"
  router_name     = "${var.cluster_name}-router"
  nodes_net_cidr  = var.nodes_net_cidr
  public_net_name = var.public_net_name
  dns_servers     = var.dns_servers
  dns_domain      = var.dns_domain
}

module "secgroup" {
  source      = "./modules/secgroup"
  name_prefix = var.cluster_name
  rules       = local.secgroup_rules
}

module "server" {
  source                   = "./modules/node"
  cluster_name             = var.cluster_name
  additional_metadata      = var.additional_metadata
  name_prefix              = "${var.cluster_name}-server"
  nodes_count              = var.nodes_count
  image_name               = var.image_name
  image_id                 = var.image_id
  instance_tags            = var.instance_tags
  flavor_name              = var.flavor_name
  keypair_name             = module.keypair.keypair_name
  ssh_key_file             = var.ssh_key_file
  system_user              = var.system_user
  use_ssh_agent            = var.use_ssh_agent
  network_id               = local.nodes_net_id
  subnet_id                = local.nodes_subnet_id
  secgroup_id              = module.secgroup.secgroup_id
  server_affinity          = var.server_group_affinity
  assign_floating_ip       = "true"
  config_drive             = var.nodes_config_drive
  floating_ip_pool         = var.public_net_name
  user_data                = var.user_data_file != null ? file(var.user_data_file) : null
  boot_from_volume         = var.boot_from_volume
  boot_volume_size         = var.boot_volume_size
  boot_volume_type         = var.boot_volume_type
  availability_zones       = var.availability_zones
  rke2_version             = var.rke2_version
  rke2_config              = var.rke2_config
  containerd_config_file   = var.containerd_config_file
  registries_conf          = var.registries_conf
  rke2_token               = random_string.rke2_token.result
  additional_san           = var.additional_san
  manifests_path           = var.manifests_path
  manifests_gzb64          = var.manifests_gzb64
  additional_configs_path  = var.additional_configs_path
  additional_configs_gzb64 = var.additional_configs_gzb64
  do_upgrade               = var.do_upgrade
  proxy_url                = var.proxy_url
  kube_vip                 = var.kube_vip_loadbalancer
  internal_vip             = var.kube_vip_loadbalancer ? openstack_networking_port_v2.kube_vip[0].all_fixed_ips[0] : ""
  no_proxy                 = concat(["localhost", "127.0.0.1", "169.254.169.254", "127.0.0.0/8", "169.254.0.0/16", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], var.no_proxy)
}

resource "local_file" "tmpdirfile" {
  content  = ""
  filename = "${local.tmpdir}/placeholder"
}

resource "random_string" "rke2_token" {
  length = 64
}

resource "openstack_networking_port_v2" "kube_vip" {
  count              = var.kube_vip_loadbalancer ? 1 : 0
  name               = "${var.cluster_name}-vip"
  network_id         = local.nodes_net_id
  security_group_ids = [module.secgroup.secgroup_id]
  admin_state_up     = false

  fixed_ip {
    subnet_id = local.nodes_subnet_id
  }
}

resource "openstack_networking_floatingip_v2" "kube_vip" {
  count       = var.kube_vip_loadbalancer ? 1 : 0
  pool        = var.public_net_name
  description = "Floating IP for ${var.cluster_name}-kube-vip (in-use)"
}

resource "openstack_networking_floatingip_associate_v2" "kube_vip" {
  count       = var.kube_vip_loadbalancer ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.kube_vip[0].address
  port_id     = openstack_networking_port_v2.kube_vip[0].id
}
