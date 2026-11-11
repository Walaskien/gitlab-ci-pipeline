GCL_VERSION ?= 4.77.1
GCL         := .tools/gcl/node_modules/.bin/gitlab-ci-local
IMAGE       ?= notes
TAG         ?= local
JOBS        ?= lint:python lint:yaml lint:dockerfile lint:shell 'test: [3.9]' 'test: [3.12]'

VENV := .venv/bin

.PHONY: venv lint test image gcl-install gcl-preview gcl

venv:
	python3 -m venv .venv
	$(VENV)/pip install -r requirements-dev.txt

lint:
	$(VENV)/ruff check .
	$(VENV)/ruff format --check .
	$(VENV)/yamllint -s .

test:
	$(VENV)/pytest -q --cov=app --cov-report=term

# what build:image does before the push, minus dind
image:
	docker build --build-arg APP_VERSION=$(TAG) -t $(IMAGE):$(TAG) .
	scripts/container-smoke.sh $(IMAGE):$(TAG) $(TAG)

# needs node and npm on the PATH. The package goes into .tools/, not global.
# gitlab-ci-local only sees files that git knows about: git add new files first.
gcl-install:
	npm install --no-audit --no-fund --prefix .tools/gcl gitlab-ci-local@$(GCL_VERSION)

gcl-preview:
	$(GCL) --preview

# jobs with an image: run in docker on the local daemon
gcl:
	$(GCL) $(JOBS)
