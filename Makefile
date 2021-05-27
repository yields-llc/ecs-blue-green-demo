stack-family=ecs-blue-green-demo
github-owner=yields-llc

deploy-vpc-subnet:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/vpc-subnet.yml \
		--stack-name $(stack-family)-vpc-subnet \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-nat-instance:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/nat-instance.yml \
		--stack-name $(stack-family)-nat-instance \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-network:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/network.yml \
		--stack-name $(stack-family)-network \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-security-group:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/security-group.yml \
		--stack-name $(stack-family)-security-group \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-load-balancer:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/load-balancer.yml \
		--stack-name $(stack-family)-load-balancer \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-ecs-cluster:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/ecs-cluster.yml \
		--stack-name $(stack-family)-ecs-cluster \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-ecs-ecr:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/ecs-ecr.yml \
		--stack-name $(stack-family)-ecs-ecr \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-ecs-service:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/ecs-service.yml \
		--stack-name $(stack-family)-ecs-service \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset

push-docker-images: cache-account-id cache-region
	$(eval account-id := $(shell cat .cache/account-id.txt))
	$(eval region := $(shell cat .cache/region.txt))
	aws --profile $(profile) ecr get-login-password --region $(region) | docker login --username AWS --password-stdin $(account-id).dkr.ecr.$(region).amazonaws.com
	docker build -t $(stack-family)/php-fpm -f aws/ecs/app-service/php-fpm/Dockerfile .
	docker tag $(stack-family)/php-fpm:latest $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/php-fpm:latest
	docker push $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/php-fpm:latest
	docker build -t $(stack-family)/nginx -f aws/ecs/app-service/nginx/Dockerfile .
	docker tag $(stack-family)/nginx:latest $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/nginx:latest
	docker push $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/nginx:latest

deploy-secrets-github:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/secrets-github.yml \
		--stack-name $(stack-family)-secrets-github \
		--parameter-overrides StackFamily=$(stack-family) AccessToken=$(access-token) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-secrets-docker:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/secrets-docker.yml \
		--stack-name $(stack-family)-secrets-docker \
		--parameter-overrides StackFamily=$(stack-family) Username=$(username) AccessToken=$(access-token) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-code-deploy:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/code-deploy.yml \
		--stack-name $(stack-family)-code-deploy \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset
	make deploy-code-deploy-app profile=$(profile)
	make deploy-code-deploy-group profile=$(profile)

deploy-code-deploy-app:
	aws --profile $(profile) deploy create-application \
		--application-name $(stack-family)-app \
		--compute-platform ECS

deploy-code-deploy-group: cache-listener-arn cache-deploy-role-arn
	$(eval listener-arn := $(shell cat .cache/listener-arn.txt))
	$(eval deploy-role-arn := $(shell cat .cache/deploy-role-arn.txt))
	cat aws/cloud-formation/code-deploy-group.json | \
		sed -e "s!<LISTENER_ARN>!$(listener-arn)!g" -e "s!<DEPLOY_ROLE_ARN>!$(deploy-role-arn)!g" \
		> .cache/code-deploy-group.json
	aws --profile $(profile) deploy create-deployment-group \
		--cli-input-json file://.cache/code-deploy-group.json

deploy-code-pipeline:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/code-pipeline.yml \
		--stack-name $(stack-family)-code-pipeline \
		--parameter-overrides StackFamily=$(stack-family) GitHubOwner=$(github-owner) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset

cache-account-id:
	mkdir -p .cache
	aws --profile=$(profile) sts get-caller-identity \
		--query 'Account' | tr -d '"' > .cache/account-id.txt

cache-region:
	mkdir -p .cache
	aws --profile=$(profile) configure get region > .cache/region.txt
	if [ ! -s .cache/region.txt ]; then aws configure get region > .cache/region.txt; fi
	if [ ! -s .cache/region.txt ]; then echo $(region) > .cache/region.txt; fi

cache-listener-arn:
	mkdir -p .cache
	aws --profile=$(profile) cloudformation describe-stack-resource \
		--stack-name=$(stack-family)-load-balancer \
		--logical-resource-id=ListenerHTTP \
		--query 'StackResourceDetail.PhysicalResourceId' | tr -d '"' > .cache/listener-arn.txt

cache-deploy-role-name:
	aws --profile=$(profile) cloudformation describe-stack-resource \
		--stack-name=$(stack-family)-code-deploy \
		--logical-resource-id=DeployRole \
		--query 'StackResourceDetail.PhysicalResourceId' | tr -d '"' > .cache/deploy-role-name.txt

cache-deploy-role-arn: cache-account-id cache-deploy-role-name
	$(eval account-id := $(shell cat .cache/account-id.txt))
	$(eval deploy-role := $(shell cat .cache/deploy-role-name.txt))
	echo 'arn:aws:iam::$(account-id):role/$(deploy-role)' > .cache/deploy-role-arn.txt

# task-scheduler

deploy-task-scheduler-ecs-ecr:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/task-scheduler/ecs-ecr.yml \
		--stack-name $(stack-family)-task-scheduler-ecs-ecr \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-task-scheduler-ecs-service:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/task-scheduler/ecs-service.yml \
		--stack-name $(stack-family)-task-scheduler-ecs-service \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset

push-task-scheduler-docker-images: cache-account-id cache-region
	$(eval account-id := $(shell cat .cache/account-id.txt))
	$(eval region := $(shell cat .cache/region.txt))
	aws --profile $(profile) ecr get-login-password --region $(region) | docker login --username AWS --password-stdin $(account-id).dkr.ecr.$(region).amazonaws.com
	docker build -t $(stack-family)/task-scheduler -f aws/ecs/task-scheduler/Dockerfile .
	docker tag $(stack-family)/task-scheduler:latest $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/task-scheduler:latest
	docker push $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/task-scheduler:latest

deploy-task-scheduler-code-pipeline:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/task-scheduler/code-pipeline.yml \
		--stack-name $(stack-family)-task-scheduler-code-pipeline \
		--parameter-overrides StackFamily=$(stack-family) GitHubOwner=$(github-owner) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset

# queue-worker

deploy-queue-worker-ecs-ecr:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/queue-worker/ecs-ecr.yml \
		--stack-name $(stack-family)-queue-worker-ecs-ecr \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset

deploy-queue-worker-ecs-service:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/queue-worker/ecs-service.yml \
		--stack-name $(stack-family)-queue-worker-ecs-service \
		--parameter-overrides StackFamily=$(stack-family) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset

push-queue-worker-docker-images: cache-account-id cache-region
	$(eval account-id := $(shell cat .cache/account-id.txt))
	$(eval region := $(shell cat .cache/region.txt))
	aws --profile $(profile) ecr get-login-password --region $(region) | docker login --username AWS --password-stdin $(account-id).dkr.ecr.$(region).amazonaws.com
	docker build -t $(stack-family)/queue-worker -f aws/ecs/queue-worker/Dockerfile .
	docker tag $(stack-family)/queue-worker:latest $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/queue-worker:latest
	docker push $(account-id).dkr.ecr.$(region).amazonaws.com/$(stack-family)/queue-worker:latest

deploy-queue-worker-code-pipeline:
	aws --profile $(profile) cloudformation deploy \
		--template ./aws/cloud-formation/queue-worker/code-pipeline.yml \
		--stack-name $(stack-family)-queue-worker-code-pipeline \
		--parameter-overrides StackFamily=$(stack-family) GitHubOwner=$(github-owner) \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset


# Misc

stop-all:
	make stop-ecs-task-scheduler profile=$(profile)
	make stop-ecs-services profile=$(profile)
	make stop-nat-instances profile=$(profile)

stop-ecs-task-scheduler:
	aws --profile $(profile) events disable-rule --name RunScheduledTask

stop-ecs-services:
	aws --profile $(profile) ecs update-service \
		--cluster $(stack-family) \
		--service $(stack-family)-app \
		--desired-count 0 \
		--query 'service.{ desiredCount: desiredCount, runningCount: runningCount, pendingCount: pendingCount }'

stop-nat-instances: cache-nat-instance-ids
	$(eval nat-instance-ids := $(shell cat .cache/nat-instance-ids.txt))
	aws --profile $(profile) ec2 stop-instances \
		--instance-ids $(nat-instance-ids) \
		--query 'StoppingInstances[].InstanceId'

start-all:
	make start-nat-instances profile=$(profile)
	make start-ecs-services profile=$(profile)
	make start-ecs-task-scheduler profile=$(profile)

start-ecs-task-scheduler:
	aws --profile $(profile) events enable-rule --name RunScheduledTask

start-ecs-services:
	aws --profile $(profile) ecs update-service \
		--cluster $(stack-family) \
		--service $(stack-family)-app \
		--desired-count 1 \
		--query 'service.{ desiredCount: desiredCount, runningCount: runningCount, pendingCount: pendingCount }'

start-nat-instances: cache-nat-instance-ids
	$(eval nat-instance-ids := $(shell cat .cache/nat-instance-ids.txt))
	aws --profile $(profile) ec2 start-instances \
		--instance-ids $(nat-instance-ids) \
		--query 'StartingInstances[].InstanceId'

cache-nat-instance-ids:
	aws --profile $(profile) ec2 describe-instances \
		--filter Name=tag:Group,Values=NAT \
		--query 'Reservations[].Instances[].InstanceId' \
		 | tr -d '" [],' > .cache/nat-instance-ids.txt
