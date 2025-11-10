# OpenAPI Tools Makefile
# Generates test clients and validates specs

# OpenAPI Generator Docker image
GENERATOR_IMAGE := openapitools/openapi-generator-cli:latest
VALIDATOR_IMAGE := stoplight/spectral:latest

# Output directories
OUTPUT_DIR := generated
ELIXIR_CLIENT_DIR := $(OUTPUT_DIR)/elixir_clients

# All spec files
SPECS := user_svc.yaml job_svc.yaml email_svc.yaml image_svc.yaml

.PHONY: help validate generate-clients generate-elixir clean test-clients

help:
	@echo "OpenAPI Tools"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  validate         - Validate all OpenAPI specs"
	@echo "  generate-clients - Generate test clients for all services"
	@echo "  generate-elixir  - Generate Elixir test clients"
	@echo "  test-clients     - Run integration tests using generated clients"
	@echo "  clean            - Remove generated files"
	@echo ""
	@echo "Examples:"
	@echo "  make validate               # Check all specs are valid"
	@echo "  make generate-clients       # Generate all test clients"

# Validate all OpenAPI specs
validate:
	@echo "Validating OpenAPI specifications..."
	@for spec in $(SPECS); do \
		echo "→ Validating $$spec"; \
		docker run --rm -v $(PWD):/local $(GENERATOR_IMAGE) validate -i /local/$$spec || exit 1; \
	done
	@echo "✓ All specs are valid"

# Generate test clients for all services
generate-clients: generate-elixir
	@echo "✓ All clients generated"

# Generate Elixir test clients
generate-elixir:
	@echo "Generating Elixir test clients..."
	@mkdir -p $(ELIXIR_CLIENT_DIR)
	@for spec in $(SPECS); do \
		service=$$(basename $$spec .yaml); \
		echo "→ Generating Elixir client for $$service"; \
		docker run --rm \
			-v $(PWD):/local \
			$(GENERATOR_IMAGE) generate \
			-i /local/$$spec \
			-g elixir \
			-o /local/$(ELIXIR_CLIENT_DIR)/$$service \
			--additional-properties=packageName=$${service}_client; \
	done
	@echo "✓ Elixir clients generated in $(ELIXIR_CLIENT_DIR)"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -rf $(OUTPUT_DIR)
	@echo "✓ Cleaned"

# Run integration tests (requires services to be running)
test-clients:
	@echo "Testing generated clients..."
	@echo "Note: Start services first with: ../dev.sh start user_svc"
	@cd ../apps/user_svc && mix test test/integration/

# Install spectral for better validation (optional)
install-spectral:
	npm install -g @stoplight/spectral-cli
