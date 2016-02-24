    output "4. VIRL controller ip" {
      value = "${packet_device.virl.network.0.address}"
    }
    output "5. uwm without OpenVPN" {
      value = "http://${packet_device.virl.network.0.address}:19400"
    }
    output "6. uwmadmin login" {
      value = "login uwmadmin password ${var.uwmadmin_password}"
    }
    output "3. guest login" {
      value = "login guest password ${var.guest_password}"
    }
    output "1. OpenVPN client file" {
        value = "Your OpenVPN client connection file is now available at ./cluster.ovpn"
    }
    output "2. uwm with OpenVPN" {
      value = "http://172.16.11.254:19400"    
    }
