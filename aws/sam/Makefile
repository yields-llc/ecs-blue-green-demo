env=default

invoke-local:
	sam build --use-container --config-env=$(env) $(function) && \
	sam local invoke --profile=$(profile) --env-vars=env.json --event=events/event.json $(function)

deploy:
	sam build --use-container --config-env=$(env) $(function) && \
	sam deploy --profile=$(profile) --config-env=$(env) $(function)
