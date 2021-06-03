import boto3
import os
import nat_instances


def lambda_handler(event, context):
    print(event)
    print(context)
    print(os.environ)

    disable_task_schedule('RunScheduledTask')
    stop_ecs(os.environ['ECS_CLUSTER'], os.environ['ECS_APP_SERVICE'])
    stop_ecs(os.environ['ECS_CLUSTER'], os.environ['ECS_QUEUE_WORKER_SERVICE'])
    nat_instances.stop()


def disable_task_schedule(rule_name):
    events = boto3.client('events')
    events.disable_rule(Name=rule_name)


def stop_ecs(cluster, service):
    ecs = boto3.client('ecs')
    ecs.update_service(
        cluster=cluster,
        service=service,
        desiredCount=0
    )
