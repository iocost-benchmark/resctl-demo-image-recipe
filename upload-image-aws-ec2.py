#!/usr/bin/env python3
# TODO licence
# TODO expand documentation
# sudo apt install python3-libcloud
import argparse
import logging
import os
from libcloud import storage
from libcloud import compute

# setup logging
log_level = logging.INFO
logging.basicConfig(level=log_level,
                    datefmt='%Y/%m/%d %H:%M:%S',
                    format='%(asctime)s %(levelname)s: %(message)s')
log = logging.getLogger(__name__)

# read arguments
parser = argparse.ArgumentParser(description='Upload image to EC2.')
parser.add_argument('--ami-name', default='AMI name', help='The AMI name.')
parser.add_argument('--ami-description', default='AMI description', help='The AMI description.')
parser.add_argument('--image-file', default='', help='The file to upload.')
args = parser.parse_args()

# read keys from env
EC2_ACCESS_ID = os.environ['EC2_ACCESS_ID']
EC2_SECRET_KEY = os.environ['EC2_SECRET_KEY']
EC2_REGION = os.environ['EC2_REGION']
EC2_BUCKET = os.environ['EC2_BUCKET']

# connect to AWS
aws_s3_driver = storage.providers.get_driver(storage.providers.Provider.S3_EU_WEST)
aws_s3 = aws_s3_driver(EC2_ACCESS_ID, EC2_SECRET_KEY, region=EC2_REGION)

aws_ec2_driver = compute.providers.get_driver(compute.providers.Provider.EC2)
aws_ec2 = aws_ec2_driver(EC2_ACCESS_ID, EC2_SECRET_KEY, region=EC2_REGION)

# TODO aws iam create-role if needed
# TODO aws iam put-role-policy if needed

# TODO check image file exists and print some info before uploading
# TODO input from commandline
object_name = 'resctl-demo-image.vmdk'

# TODO check if bucket exists and create if needed
# TODO creating buckets needs a specific driver for the region
container = aws_s3.get_container(container_name=EC2_BUCKET)

# upload vmdk to bucket
if args.image_file != '':
    log.info('uploading image %s to container %s as object %s',
             args.image_file,
             container.name,
             object_name)
    with open(args.image_file, 'rb') as iterator:
        obj = aws_s3.upload_object_via_stream(iterator=iterator,
                                              container=container,
                                              object_name=object_name)
        log.info('upload complete')


# import disk image as snapshot
log.info('importing compressed disk image as disk snapshot')
snapshot_description=args.ami_description
snapshot = aws_ec2.ex_import_snapshot(description=snapshot_description,
                                      disk_container=[{
                                          'Description': 'root',
                                          'Format': 'VMDK',
                                          'UserBucket': {
                                              'S3Bucket': EC2_BUCKET,
                                              'S3Key': object_name,
                                          }
                                      }])
snapshot_id = snapshot.id
log.info('import complete; snapshot_id=%s', snapshot_id)


# create image from EBS snapshot
arch = 'x86_64'
log.debug('creating EC2 AMI name=%s, description=%s', args.ami_name, args.ami_description)
image = aws_ec2.ex_register_image(name=args.ami_name,
                                  description=args.ami_description,
                                  architecture=arch,
                                  root_device_name='/dev/sda1',
                                  block_device_mapping=[{
                                      'DeviceName': '/dev/sda1',
                                      'Ebs': {
                                          'SnapshotId': snapshot_id,
                                          'VolumeType': 'gp2',
                                          'DeleteOnTermination': 'true',
                                      }
                                  }],
                                  virtualization_type='hvm',
                                  ena_support=True,
                                  sriov_net_support='simple')
image_id = image.id
log.info("creating EC2 AMI complete; id=%s", image_id)
# TODO make image public: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sharingamis-intro.html
# TODO delete file from s3
