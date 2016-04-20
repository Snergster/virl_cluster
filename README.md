THESE STEPS ARE FOR USERS WHO WANT TO RUN 'VIRL CLUSTER on PACKET'.  YOU MUST HAVE A VALID VIRL LICENSE KEY BEFORE ATTEMPTING.

#Steps:

1. On your local VIRL server, run the command

   `sudo salt-call state.sls virl.terraform`
   
   This will install terraform, clone the repo, create an ssh key, copy in minion keys and replace many variables in the variables.tf file.
   
2. Register with www.packet.net for an account

3. Log in to app.packet.net:
  3. Create api key token

4. `cd virl_cluster`

5. edit `passwords.tf` Note: The salt state will generate new keys with each run

6. Edit `settings.tf` to replace the `default` field with your packet_api_key 

7. Edit `settings.tf` and edit the `packet_machine_type` default field to select the machine type (size) that you want. In addition, you can select where you want your VIRL server to be hosted from the available Packet.net data centers. EWR1 == New York, SJC1 == San Jose, CA, AMS1 == Amsterdam. Instructions in the settings.tf file will guide you to the changes that you need to make.

8. Default configuration will be one controller node and one compute node.  If you'd like to use a larger cluster, you have the following options:

   virl3node.tf.orig == one controller node, two compute nodes
   
   virl4node.tf.orig == one controller node, three compute nodes
   
   virl5node.tf.orig == one controller node, four compute nodes
   
   The controller node and the compute nodes will all be based on the `packet_machine_type` that you've specified.
   
   To select one of the configurations listed above:
   
  1. Delete the file 'virl2node.tf' using the command `rm virl2node.tf`
  2. Make a copy the configuration file of choice and name it `virlXnode.tf` for example:
    
    `cp virl3node.tf.orig virl3node.tf`

   Note - there can only be ONE 'virlXnode.tf' file present in the directory.
  
  3. Edit ./conf/virl.ini. You need to enable the compute nodes that you require:
     
    If you are using 'virl2node.tf', then following parameters must be set:

    `compute1_active: True`

    `compute2_active: False`

    `compute3_active: False`

    `compute4_active: False`

    If you are using 'virl3node.tf', then following parameters must be set:
    
    `compute1_active: True`

    `compute2_active: True`

    `compute3_active: False`

    `compute4_active: False` 
    
    If you are using 'virl4node.tf', then following parameters must be set:
    
    `compute1_active: True`

    `compute2_active: True`

    `compute3_active: True`

    `compute4_active: False`

    If you are using 'virl5node.tf', then following parameters must be set:
    
    `compute1_active: True`

    `compute2_active: True`

    `compute3_active: True`

    `compute4_active: True`

    Adjust the file as per the examples above and save the changes.
    
8. Run the command 

   `terraform plan .`
   
   This will validate the terraform .tf file.
   
9. Run the command 

   `terraform apply .`     
   
   This will spin up your Remote VIRL servers and install the VIRL software stack. If this runs without errors, expect it to take ~30 minutes. When it completes, the system will report the IP address of your Remote VIRL Controller node. Login using
   
    `ssh root@<ip address>` or `ssh virl@<ip address>`
    
    NOTE - the VIRL servers will reboot once the VIRL software has been installed. You must therefore wait until the reboot has completed before logging in.

10. To see more information about your Remote VIRL controller node, run the command 

   `terraform show` 
   
   The output will provided details of your Remote VIRL VIRL controller node.


11. If logged in as `root`, to run commands such as 'nova service-list' you need to be operating as the virl user. To do this, use the command
 
    `su -l virl`

12. The VIRL server is provisioned in a secure manner. To access the server, you must establish an OpenVPN tunnel to the server.
    1. Install an OpenVPN client for your system.
    2. The set up of the remote VIRL server will automatically configure the OpenVPN server. The 'cluster.ovpn' connection profile will be automatically downloaded to the directory from which you ran the `terraform apply .` command. 
    3. The 'cluster.ovpn' file can be copied out to other devices, such as a laptop hosting your local VIRL instance.
    4. Download the file and open it with your OpenVPN client
   
    NOTE - the VIRL server will reboot once the VIRL software has been installed. You must therefore wait until the reboot has completed before bringing up the OpenVPN tunnel.
    
13. With your OpenVPN tunnel up, the VIRL server is available at http://172.16.11.254.
    If using VM Maestro, you must set up the connection profile to point to `172.16.11.254`

14. When you're ready to terminate your remote VIRL server instance, on your LOCAL VIRL server, issue the command 
 
    `terraform destroy .`

15. Log in to the Packet.net portal
   1. Review the 'Manage' tab to confirm that the server instance has indeed been deleted and if necessary, delete the server
   2. Review the 'SSH Keys' tab and remove any ssh keys that are registered
   
To start up again, repeat step 8.

[NOTE] Your uwmadmin and guest passwords are in passwords.tf. If you can't remember them, this is where you can find them, or by running terraform output

# To obtain your VM Maestro clients...
Once your VIRL Server has come up, log in to the UWM interface as 'uwmadmin' using your password. Navigate to the 'VIRL Server/VIRL Software' tab and select the VM Maestro client package(s) that you'd like. Now press 'install'. The package will be installed on your VIRL server and will be available from `http://172.16.11.254/download/`.

# If your VIRL server bring-up fails to complete successfully:

1. Terminate the instance using the command:

   `terraform destroy .`

2. Log in to the Packet.net portal
   1. Review the 'Manage' tab to confirm that the server instance has indeed been deleted and if necessary, delete the server.
   2. Review the 'SSH Keys' tab and remove any ssh keys that are registered
   3. Delete any project that is does not have an active server instance in it. Double-click on the project name and use the 'settings' panel to delete the project.
    
   [NOTE] a server can only be terminated on the Packet.net portal once the server's status is reported as 'green'. You may therefore need to wait for a few minutes in order for the server to reach this state.

# Dead man's timer:

When a VIRL server is initialised, a 'dead man's timer' value is set. The purpose of the timer is to avoid a server instance being left running on the platform for an indefinite period. 

The timer value is set by default to four (4) hours and can be changed by modifying the 'dead mans timer' value in the settings.tf file before you start your server instance. The value you set will be applied each time you start up a server instance until you next modify the value.

If your server is running at the point where the timer expires, your server instance will be terminated automatically. Any information held on the server will be lost.

You are able to see when the timer will expire by logging in (via ssh) to the server instance and issuing the command `sudo atq`. You can remove the timer, leaving the server to run indefinitely, by issuing the command `sudo atrm 1`.
