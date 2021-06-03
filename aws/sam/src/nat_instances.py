import boto3


def stop():
    ec2 = boto3.client('ec2')
    instance_ids = get_instance_ids()
    ec2.stop_instances(InstanceIds=instance_ids)
    waiter = ec2.get_waiter('instance_stopped')
    waiter.wait(InstanceIds=instance_ids)
    print("The instances has stopped")


def start():
    ec2 = boto3.client('ec2')
    instance_ids = get_instance_ids()
    ec2.start_instances(InstanceIds=instance_ids)
    waiter = ec2.get_waiter('instance_status_ok')
    waiter.wait(InstanceIds=instance_ids)
    print("The instances has started")


def get_instance_ids():
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:Group',
                'Values': ['NAT']
            }
        ]
    )
    instance_ids = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])

    return instance_ids
