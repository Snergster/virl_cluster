# Configure the Packet Provider
provider "packet" {
        auth_token = "${var.packet_api_key}"
}

resource "packet_ssh_key" "virlckey" {
        name = "virlckey"
        public_key = "${file("${var.ssh_private_key}.pub")}"
}

/* Project id set in settings.tf start */

# resource "packet_device" "virl" {
        #project_id = "${var.packet_project_id}"
        #depends_on = ["packet_ssh_key.virlckey"]

/* Project id set in settings.tf end */

# Alternate project_id. If you use a consistent project defined in settings.tf, uncomment the section above. Remember to comment out the section below!
# Only have one project_id and depends_on defined at a time

/* Create project style start */

resource "packet_project" "virl_project" {
        name = "virl server on packet"
}

resource "packet_device" "virl" {
        project_id = "${packet_project.virl_project.id}"
        depends_on = ["packet_ssh_key.virlckey","packet_project.virl_project"]

/* Create project style end */

        hostname = "${var.hostname}"
        plan = "${var.packet_machine_type}"
        facility = "${var.packet_location}"
        operating_system = "ubuntu_16_04_image"
        user_data = "${file("conf/${var.packet_location}-cloud.config")}"
        billing_cycle = "hourly"

  connection {
        type = "ssh"
        user = "root"
        port = 22
        timeout = "1200"
        private_key = "${file("${var.ssh_private_key}")}"
      }

   provisioner "remote-exec" {
      inline = [
    # dead mans timer
        "apt-get install at time -y",
        "printf '/usr/bin/curl -H X-Auth-Token:${var.packet_api_key} -X DELETE https://api.packet.net/devices/${packet_device.virl.id}\n'>/etc/deadtimer",
        "sleep 3",
        "at now + ${var.dead_mans_timer} hours -f /etc/deadtimer"
    ]
    }
   provisioner "remote-exec" {
      inline = [
        "mkdir -p /etc/salt/minion.d",
        "mkdir -p /etc/salt/pki/minion",
        "mkdir -p /etc/salt/master.d",
        "dpkg --add-architecture i386"
    ]
    }
    provisioner "file" {
        source = "scripts/getintip"
        destination = "/usr/local/bin/getintip"
    }
    provisioner "file" {
        source = "conf/install_salt.sh"
        destination = "/root/install_salt.sh"
    }    
    provisioner "file" {
        source = "keys/"
        destination = "/etc/salt/pki/minion"
    }
    provisioner "file" {
        source = "conf/virl.ini"
        destination = "/etc/virl.ini"
    }
    provisioner "file" {
        source = "conf/extra.conf"
        destination = "/etc/salt/minion.d/extra.conf"
    }
    provisioner "file" {
        source = "conf/ubuntu-default.list"
        destination = "/etc/apt/sources.list.d/ubuntu-default.list"
    }


   provisioner "remote-exec" {
      inline = [
         "set -e",
         "set -x",
         "chmod 755 /usr/local/bin/getintip",
         "apt-get install crudini -y",
         "service atd start",
         "printf '\nmaster: ${var.salt_master}\nid: ${var.salt_id}\nappend_domain: ${var.salt_domain}\n' >>/etc/salt/minion.d/extra.conf",
         "crudini --set /etc/virl.ini DEFAULT salt_id ${var.salt_id}",
         "crudini --set /etc/virl.ini DEFAULT salt_master ${var.salt_master}",
         "crudini --set /etc/virl.ini DEFAULT salt_domain ${var.salt_domain}",
         "crudini --set /etc/virl.ini DEFAULT guest_password ${var.guest_password}",
         "crudini --set /etc/virl.ini DEFAULT uwmadmin_password ${var.uwmadmin_password}",
         "crudini --set /etc/virl.ini DEFAULT password ${var.openstack_password}",
         "crudini --set /etc/virl.ini DEFAULT mysql_password ${var.mysql_password}",
         "crudini --set /etc/virl.ini DEFAULT keystone_service_token ${var.openstack_token}",
         "crudini --set /etc/virl.ini DEFAULT openvpn_enable ${var.openvpn_enable}",
         "crudini --set /etc/virl.ini DEFAULT packet True",
         "crudini --set /etc/virl.ini DEFAULT hostname ${var.hostname}"
    ]
    }
/* controller and one compute */
   provisioner "remote-exec" {
      inline = [
         "set -e",
         "set -x",
         "crudini --set /etc/virl.ini DEFAULT internalnet_controller_IP ${packet_device.virl.network.2.address}",
         "crudini --set /etc/virl.ini DEFAULT internalnet_IP ${packet_device.virl.network.2.address}",
         "crudini --set /etc/virl.ini DEFAULT compute1_internalnet_ip ${packet_device.compute1.network.2.address}",
         "crudini --set /etc/virl.ini DEFAULT compute1_internalnet_gateway ${packet_device.compute1.network.2.gateway}"
    ]
    }


/* controller build section */
   provisioner "remote-exec" {
      inline = [
         "set -e",
         "set -x",
         "echo 'wget -O install_salt.sh https://bootstrap.saltstack.com/stable/bootstrap-salt.sh'",
         "sleep 1 || true",
         "echo 'look now'",
         "sh ./install_salt.sh -M -P stable",
    # create virl user
         "salt-call state.sls common.users",
    # copy authorized keys from root to virl user
         "salt-call grains.setval mitaka true",
         "salt-call grains.setval mysql_password ${var.mysql_password}",
         "salt-call file.write /etc/salt/minion.d/openstack.conf 'mysql.pass: ${var.mysql_password}'",
         "salt-call state.sls virl.packet.keycopy",
         "salt-call state.highstate",
         "echo 'look now'",
         "sleep 6 || true",
         "salt-call state.sls virl.basics",
         "salt-call state.sls common.salt-master.cluster",
         "salt-call state.sls openstack",
         "/usr/local/bin/vinstall salt",
         "salt-call state.sls openstack.setup",
         "salt-call state.sls common.bridge",
         "salt-call state.sls openstack.restart",
         "salt-call state.sls virl.std",
         "salt-call state.sls virl.ank",
         "service virl-std restart",
         "service virl-uwm restart",
         "salt-call state.sls virl.guest",
         "salt-call state.sls openstack.restart",
         "salt-call state.sls virl.routervms",
         "salt-call state.sls virl.openvpn",
         "salt-call state.sls virl.openvpn.packet",
    #This is to keep the sftp from failing and taking terraform out with it in case no vpn is actually installed
         "touch /var/local/virl/cluster.ovpn"

   ]
  }
/* openvpn client key pull */
    provisioner "local-exec" {
        command = "sftp -o 'IdentityFile=${var.ssh_private_key}' -o 'StrictHostKeyChecking=no' root@${packet_device.virl.network.0.address}:/var/local/virl/client.ovpn cluster.ovpn"
    }
/* default 1 compute */
    provisioner "local-exec" {
        command = "ssh -o 'IdentityFile=${var.ssh_private_key}' -o 'StrictHostKeyChecking=no' root@${packet_device.compute1.network.0.address} '/root/compute_builder ${packet_device.virl.network.2.address}'"
    }

   provisioner "remote-exec" {
      inline = [
        "sleep 5",
        "reboot"
        ]
        }
  }

resource "packet_device" "compute1" {
        hostname = "compute1"
        plan = "${var.packet_machine_type}"
        facility = "${var.packet_location}"
        operating_system = "ubuntu_16_04_image"
        billing_cycle = "hourly"
        project_id = "${packet_project.virl_project.id}"
        depends_on = ["packet_ssh_key.virlckey","packet_project.virl_project"]

# Alternate project_id. If you use a consistent project defined in settings.tf, uncomment the two lines below. Remember to comment out the two lines above!
# Only have one project_id and depends_on defined at a time
        #project_id = "${var.packet_project_id}"
        #depends_on = ["packet_ssh_key.virlckey"]


  connection {
        type = "ssh"
        user = "root"
        port = 22
        timeout = "1200"
        private_key = "${file("${var.ssh_private_key}")}"
      }
   provisioner "remote-exec" {
      inline = [
    # dead mans timer
        "apt-get install at time -y",
        "printf '/usr/bin/curl -H X-Auth-Token:${var.packet_api_key} -X DELETE https://api.packet.net/devices/${packet_device.compute1.id}\n'>/etc/deadtimer",
        "sleep 3",
        "at now + ${var.dead_mans_timer} hours -f /etc/deadtimer"
    ]
    }
   provisioner "remote-exec" {
      inline = [
        "mkdir -p /etc/salt/minion.d",
        "mkdir -p /etc/salt/pki/minion",
        "mkdir -p /etc/salt/master.d",
        "dpkg --add-architecture i386"
    ]
    }
    provisioner "file" {
        source = "scripts/getintip"
        destination = "/usr/local/bin/getintip"
    }
    provisioner "file" {
        source = "scripts/compute_builder"
        destination = "/root/compute_builder"
    }
    provisioner "file" {
        source = "conf/install_salt.sh"
        destination = "/root/install_salt.sh"
    }
    provisioner "file" {
        source = "conf/compute.extra.conf"
        destination = "/etc/salt/minion.d/extra.conf"
    }
    provisioner "file" {
        source = "conf/ubuntu-default.list"
        destination = "/etc/apt/sources.list.d/ubuntu-default.list"
    }

   provisioner "remote-exec" {
      inline = [
        "set -e",
        "set -x",
        "chmod 755 /usr/local/bin/getintip",
        "chmod 755 /root/compute_builder",
        "apt-get update",
        "sleep 1 || true",
        "DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade -y",
        "shutdown -r 1"
   ]
  }

}
