.PHONY: init plan apply destroy test clean install update-deps lint

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

# Terraform commands
init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

destroy:
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
