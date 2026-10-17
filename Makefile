# aphelion build, test and check targets. POSIX make (tested with GNU make).
.POSIX:

GO = go

# Version stamped into the binary. Override it: make build VERSION=v0.1.0
VERSION = dev

# Tool pins. These are dependency versions, not tunable values; bump each in
# its own PR after reading the release notes.
# golangci-lint: latest v2 release on 2026-10-17. .claude/hooks/post-edit-go.sh
# reads this line, so keep the "NAME = value" form.
GOLANGCI_LINT_VERSION = v2.15.0
# OpenSpec: the version pinned at bootstrap (ADR 0004, verified in the 05 PoC).
OPENSPEC_VERSION = 1.14.2

GOLANGCI_LINT = $(GO) run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
# OpenSpec sends telemetry by default; OPENSPEC_TELEMETRY=0 turns it off (ADR 0004).
OPENSPEC = OPENSPEC_TELEMETRY=0 npx -y @fission-ai/openspec@$(OPENSPEC_VERSION)

.PHONY: all build test lint fmt fmt-check vet check-file-length check-specs validate-specs check clean

all: build

# Static binary with cgo off (ADR 0002).
build:
	CGO_ENABLED=0 $(GO) build -ldflags "-X main.version=$(VERSION)" -o bin/aphelion ./cmd/aphelion

# The race detector needs cgo, so tests do not set CGO_ENABLED=0.
test:
	$(GO) test -race -coverprofile=coverage.out ./...

lint:
	$(GOLANGCI_LINT) run ./...

# Rewrites files with the formatters enabled in .golangci.yml (gofmt, gofumpt).
fmt:
	$(GOLANGCI_LINT) fmt

# Fails if any file would be reformatted.
fmt-check:
	@out=$$($(GOLANGCI_LINT) fmt --diff) || exit 1; \
	if [ -n "$$out" ]; then printf '%s\n' "$$out"; echo "fmt-check: run make fmt" >&2; exit 1; fi

vet:
	$(GO) vet ./...

check-file-length:
	scripts/check-file-length.sh

# Living specs change only together with an archived change (ADR 0004).
# Needs origin/main; skipped outside a clone that has it.
check-specs:
	@if git rev-parse --verify --quiet origin/main >/dev/null 2>&1; then \
		scripts/check-specs.sh origin/main HEAD; \
	else \
		echo "check-specs: skipped, no origin/main in this clone"; \
	fi

validate-specs:
	$(OPENSPEC) validate --all --strict --no-interactive

# Everything CI runs. Run it before pushing.
check: fmt-check vet lint test check-file-length check-specs validate-specs

clean:
	rm -rf bin coverage.out
