.PHONY: init plan apply destroy test clean install update-deps lint clean_secrets decrypt encrypt

# Development setup
install:
	uv sync

update-deps:
	uv sync --upgrade --all-extras

# Testing
test:
	uv run pytest

test-cov:
	uv run pytest --cov=email_infra --cov-report=html --cov-report=term

# Linting
lint:
	uv run pylint email_infra tests

# Secret management
clean_secrets:
	@rm -f terraform/secrets.yaml

decrypt: clean_secrets
	@aws kms decrypt \
		--ciphertext-blob $$(cat terraform/secrets.yaml.encrypted) \
		--output text \
		--query Plaintext \
		--encryption-context target=email-infra | base64 -d > terraform/secrets.yaml

encrypt:
	@aws kms encrypt \
		--key-id alias/generic \
		--plaintext fileb://terraform/secrets.yaml \
		--encryption-context target=email-infra \
		--output text \
		--query CiphertextBlob > terraform/secrets.yaml.encrypted
	@rm -f terraform/secrets.yaml

# Terraform commands
init:
	cd terraform && terraform init

plan: decrypt
	cd terraform && terraform plan

apply: decrypt
	cd terraform && terraform apply

destroy: decrypt
	cd terraform && terraform destroy

# Clean up generated files
clean:
	rm -f terraform/dmarc_processor.zip
	rm -f terraform/.terraform.lock.hcl
	rm -rf terraform/.terraform/
	rm -rf .coverage htmlcov/ .pytest_cache/ __pycache__/ email_infra/__pycache__/ tests/__pycache__/

# Package lambda for manual testing
package-lambda:
	zip -j lambda.zip email_infra/handler.py email_infra/__init__.py
