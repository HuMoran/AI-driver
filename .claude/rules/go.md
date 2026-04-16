# Go Rules

## Format
- Tool: `gofmt -w .`

## Lint
- Tool: `golangci-lint run`

## Test
- Command: `go test ./...`
- Coverage: `go test -coverprofile=coverage.out ./...`

## Build
- Command: `go build ./...`

## Project Structure
- cmd/: application entry points
- internal/: private packages
- pkg/: public packages
- go.mod: module definition
