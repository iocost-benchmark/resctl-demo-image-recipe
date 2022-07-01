#!/usr/bin/env python3
# Copyright 2020 Collabora Ltd.
# SPDX-License-Identifier: MIT
#
# cleanup-aws-ec2.py attempts to cleanup the AWS cloud account from stale images
# and makes the latest image public.
#
# The S3 bucket does not need to be cleaned-up as this is only used for intermediate
# image storage.
#
# The AWS credentials are passed to this script via environment variables:
#  - `EC2_ACCESS_ID` should be set to the AWS Access ID.
#  - `EC2_SECRET_KEY` should be set to the AWS Secret key. These can be generated from:
#  - `EC2_REGION` should be set to the AWS region the image should reside in. Currently
#    only `eu-west-1` is supported.

import boto3
import os
from botocore.exceptions import ClientError
from datetime import datetime

# Connect to AWS EC2
EC2_ACCESS_ID = os.environ['EC2_ACCESS_ID']
EC2_SECRET_KEY = os.environ['EC2_SECRET_KEY']
EC2_REGION = os.environ['EC2_REGION']

session = boto3.Session(
    aws_access_key_id=EC2_ACCESS_ID,
    aws_secret_access_key=EC2_SECRET_KEY,
    region_name=EC2_REGION
)

ec2_client = session.client('ec2')

# List all images
images = ec2_client.describe_images(Owners=['self'])
images = images['Images']

# Sort images by creation date (oldest first)
images = sorted(images, key=lambda d: d['CreationDate']) 

# Filter AMIs to be removed
images_to_remove = []
for image in images:
    # Only remove nightly builds
    if not image['Name'].startswith('resctl-demo/bookworm/main'):
        continue

    # Find the snapshot ID
    # TODO: make this work in cases where there are multiple snapshots
    snapshot_id = image['BlockDeviceMappings'][0]['Ebs']['SnapshotId']

    # Add the ID to the list to remove
    images_to_remove.append({
        'image_id': image['ImageId'],
        'snapshot_id': snapshot_id
    })

# Keep the latest three nightly images
if len(images_to_remove) > 3:
    images_to_remove.pop()
    images_to_remove.pop()
    images_to_remove.pop()

# Actually remove the images
for image in images_to_remove:
    print("Removing ami ", image)

    # Remove AMI & snapshot
    ec2_client.deregister_image(ImageId=image['image_id'])
    ec2_client.delete_snapshot(SnapshotId=image['snapshot_id'])
