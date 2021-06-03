import boto3
import os
import nat_instances


def lambda_handler(event, context):
    print(event)
    print(context)
    print(os.environ)

    nat_instances.start()
    start_ecs(os.environ['ECS_CLUSTER'], os.environ['ECS_APP_SERVICE'])
    start_ecs(os.environ['ECS_CLUSTER'], os.environ['ECS_QUEUE_WORKER_SERVICE'])
    enable_task_schedule('RunScheduledTask')


def start_ecs(cluster, service):
    ecs = boto3.client('ecs')
    ecs.update_service(
        cluster=cluster,
        service=service,
        desiredCount=1
    )


def enable_task_schedule(rule_name):
    events = boto3.client('events')
    events.enable_rule(Name=rule_name)
