resource "packet_device" "compute1" {
        hostname = "compute1"
        plan = "${var.packet_machine_type}"
        facility = "ewr1"
        operating_system = "ubuntu_14_04"
        billing_cycle = "hourly"
        project_id = "${packet_project.virl_project.id}"
        depends_on = ["packet_ssh_key.virlkey","packet_project.virl_project"]

# Alternate project_id. If you use a consistent project defined in variables.tf, uncomment the line below. Remember to comment out the two lines above!
# Only have one project_id and depends_on defined at a time
        #project_id = "${var.packet_project_id}"
        #depends_on = ["packet_ssh_key.virlkey"]


  connection {
        type = "ssh"
        user = "root"
        port = 22
        timeout = "1200"
        private_key = "${var.ssh_private_key}"
      }

   provisioner "remote-exec" {
      inline = [
        "mkdir -p /etc/salt/minion.d",
        "mkdir -p /etc/salt/pki/minion",
        "mkdir -p /etc/salt/master.d"
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
        source = "conf/compute.extra.conf"
        destination = "/etc/salt/minion.d/extra.conf"
    }
   provisioner "remote-exec" {
      inline = [
        "set -e",
        "set -x",
        "chmod 755 /usr/local/bin/getintip",
        "chmod 755 /root/compute_builder",
        "apt-get update",
        "apt-get dist-upgrade -y",
        "apt-get install at -y",
        "printf '/usr/bin/curl -H X-Auth-Token:${var.packet_api_key} -X DELETE https://api.packet.net/devices/${packet_device.compute1.id}\n'>/etc/deadtimer",
        "at now + ${var.dead_mans_timer} hours -f /etc/deadtimer",
        "reboot"
   ]
  }
