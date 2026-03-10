#!/bin/bash

# Author      : BALAJI POTHULA <balaji.pothula@techie.com>,
# Date        : 17 January 2026,
# Description : AWS EC2 CLI Commands.

# Get your Public IPv4 Address.
curl https://checkip.amazonaws.com

# Adds the specified inbound (ingress) rules to a security group.
aws ec2 authorize-security-group-ingress \
  --group-id 'sg-012aa7d0d744e7a41' \
  --ip-permissions IpProtocol='tcp',FromPort=22,ToPort=22,IpRanges="[{CidrIp='49.43.233.163/32', Description='SSH Connection from My IP'}]" \
  --output 'yaml' \
  --region 'ap-south-1'

# Removes the specified inbound (ingress) rules from a security group.
aws ec2 revoke-security-group-ingress \
  --group-id 'sg-012aa7d0d744e7a41' \
  --ip-permissions "$(aws ec2 describe-security-groups --group-ids 'sg-012aa7d0d744e7a41' --query 'SecurityGroups[0].IpPermissions')" \
  --output 'yaml' \
  --region 'ap-south-1'

# Launches the specified number of instances using an AMI for which you have permissions.
# ami-02b8269d5e85954ef :: Ubuntu Server 24.04 LTS (HVM), SSD Volume Type
aws ec2 run-instances \
  --image-id 'ami-02b8269d5e85954ef' \
  --instance-type 't2.micro' \
  --key-name 'ec2helper' \
  --security-group-ids 'sg-012aa7d0d744e7a41' \
  --subnet-id 'subnet-09884475c56e146c7' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2helper}]' \
  --associate-public-ip-address \
  --count 1 \
  --output 'yaml' \
  --region 'ap-south-1'

# Launches the specified number of instances using an AMI for which you have permissions.
# Launches LiteOS AMI EC2 instance.
aws ec2 run-instances \
  --image-id 'ami-010403f4c6443c715' \
  --instance-type 't3.nano' \
  --security-group-ids 'sg-012aa7d0d744e7a41' \
  --subnet-id 'subnet-09884475c56e146c7' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ec2liteos}]' \
  --associate-public-ip-address \
  --count 1 \
  --output 'yaml' \
  --region 'ap-south-1'

# Describes the specified instances or all instances.
# Get the specified instance public IP address.
aws ec2 describe-instances \
  --instance-ids 'i-0a160d337fc724b2b' \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output 'text' \
  --region 'ap-south-1'

# Terminates the specified instances.
aws ec2 terminate-instances \
  --instance-ids 'i-0a160d337fc724b2b' \
  --no-force \
  --output 'yaml' \
  --region 'ap-south-1'

# Requests a reboot of the specified instances.
aws ec2 reboot-instances \
  --instance-ids 'i-016853a873e823d97' \
  --output 'yaml' \
  --region 'ap-south-1'

# Creates an EBS volume that can be attached to an instance in the same Availability Zone.
aws ec2 create-volume \
  --availability-zone 'ap-south-1b' \
  --no-encrypted \
  --iops 3000 \
  --size 1 \
  --volume-type 'gp3' \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=virt-usb-stick}]' \
  --no-multi-attach-enabled \
  --throughpu 125 \
  --output 'yaml' \
  --region 'ap-south-1'

# Attaches an Amazon EBS volume to a running or stopped instance.
aws ec2 attach-volume \
  --device '/dev/sdf' \
  --instance-id 'i-0a160d337fc724b2b' \
  --volume-id 'vol-0e2a9e0e1adf0e6e0' \
  --output 'yaml' \
  --region 'ap-south-1'

# Detaches an EBS volume from an instance.
# Make sure to unmount any file systems on the device within your OS before detaching the volume.
aws ec2 detach-volume \
  --device '/dev/sdf' \
  --no-force \
  --instance-id 'i-0a160d337fc724b2b' \
  --volume-id 'vol-0e2a9e0e1adf0e6e0' \
  --output 'yaml' \
  --region 'ap-south-1'

# Deletes the specified EBS volume.
# The volume must be in the available state.
aws ec2 delete-volume \
  --volume-id 'vol-0e2a9e0e1adf0e6e0' \
  --output 'yaml' \
  --region 'ap-south-1'

# Creates a snapshot of an EBS volume and stores it in Amazon S3.
# LiteOS v1.0
aws ec2 create-snapshot \
  --description 'LiteOS v1.0 Sanpshot' \
  --volume-id 'vol-0e2a9e0e1adf0e6e0' \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=lite-os-v1.0}]' \
  --output 'yaml' \
  --region 'ap-south-1'

# Describes the specified EBS snapshots available to you or all of the EBS snapshots available to you.
aws ec2 describe-snapshots \
  --snapshot-ids 'snap-0a56fab007bb0b050' \
  --query 'Snapshots[*].{ID:SnapshotId,State:State,Progress:Progress}' \
  --output 'yaml' \
  --region 'ap-south-1'

# Deletes the specified snapshot.
aws ec2 delete-snapshot \
  --snapshot-id 'snap-0a56fab007bb0b050' \
  --output 'yaml' \
  --region 'ap-south-1'

# Registers an AMI.
# LiteOS v1.0
aws ec2 register-image \
  --boot-mode 'uefi' \
  --tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value=lite-os-v1.0}]' \
  --name 'lite-os-v1.0' \
  --description 'LiteOS v1.0 Image' \
  --architecture 'x86_64' \
  --root-device-name '/dev/xvda' \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={DeleteOnTermination=true,Iops=3000,SnapshotId=snap-0a56fab007bb0b050,VolumeSize=8,VolumeType=gp3,Throughput=125}' \
  --virtualization-type 'hvm' \
  --ena-support \
  --output 'yaml' \
  --region 'ap-south-1'

# Deregisters the specified AMI.
aws ec2 deregister-image \
  --image-id 'ami-067359a5ff3e14ad9' \
  --delete-associated-snapshots \
  --output 'yaml' \
  --region 'ap-south-1'

