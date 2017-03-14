# Makefile for Todolist : Go-200
# -----------------------------------------------------------------
#
#        ENV VARIABLE
#
# -----------------------------------------------------------------

# go env vars
GO=$(firstword $(subst :, ,$(GOPATH)))
# list of pkgs for the project without vendor
PKGS=$(shell go list ./... | grep -v /vendor/)
DOCKER_IP=$(shell if [ -z "$(DOCKER_MACHINE_NAME)" ]; then echo 'localhost'; else docker-machine ip $(DOCKER_MACHINE_NAME); fi)
export GO15VENDOREXPERIMENT=1


# -----------------------------------------------------------------
#        Version
# -----------------------------------------------------------------

# version
VERSION=0.0.1
BUILDDATE=$(shell date -u '+%s')
BUILDHASH=$(shell git rev-parse --short HEAD)
VERSION_FLAG=-ldflags "-X main.Version=$(VERSION) -X main.GitHash=$(BUILDHASH) -X main.BuildStmp=$(BUILDDATE)"

# -----------------------------------------------------------------
#        Main targets
# -----------------------------------------------------------------

all: clean build

help:
	@echo
	@echo "----- BUILD ------------------------------------------------------------------------------"
	@echo "all                  clean and build the project"
	@echo "clean                clean the project"
	@echo "build                build all libraries and binaries"
	@echo "----- TESTS && LINT ----------------------------------------------------------------------"
	@echo "test                 test all packages"
	@echo "format               format all packages"
	@echo "lint                 lint all packages"
	@echo "----- SERVERS AND DEPLOYMENTS ------------------------------------------------------------"
	@echo "start                start process on localhost"
	@echo "stop                 stop all process on localhost"
	@echo "dockerBuild          build the docker image"
	@echo "dockerClean          remove latest image"
	@echo "dockerUp             start microservice infrastructure on docker"
	@echo "dockerStop           stop microservice infrastructure on docker"
	@echo "dockerBuildUp        stop, build and start microservice infrastructure on docker"
	@echo "dockerWatch          starts a watch of docker ps command"
	@echo "dockerLogs           show logs of microservice infrastructure on docker"
	@echo "----- OTHERS -----------------------------------------------------------------------------"
	@echo "help                 print this message"

clean:
	@go clean
	@rm -Rf .tmp
	@rm -Rf *.log
	@rm -Rf *.out
	@rm -Rf *.mem
	@rm -Rf *.test
	@rm -Rf build

build: format
	@go build -v $(VERSION_FLAG) -o $(GO)/bin/todolist todolist.go

format:
	@go fmt $(PKGS)

teardownTest:
	@$(shell docker kill todolist-mongo-test 2&>/dev/null 1&>/dev/null)
	@$(shell docker rm todolist-mongo-test 2&>/dev/null 1&>/dev/null)

setupTest: teardownTest
	@docker run -d --name todolist-mongo-test -p "27017:27017" mongo:3.3

test: setupTest
	@export MONGODB_SRV=mongodb://$(DOCKER_IP)/tasks; go test -v $(PKGS); make teardownTest

bench:
	@go test -v -run TestTaskHandlerGet -bench=. -memprofile=prof.mem github.com/Sfeir/golang-200/web

benchTool: bench
	@echo "### TIP : type 'top 5' and 'list the first item'"
	@go tool pprof --alloc_space web.test prof.mem

lint:
	@golint dao/...
	@golint model/...
	@golint web/...
	@golint utils/...
	@golint ./.
	@go vet $(PKGS)

start:
	@todolist -port 8020 -logl debug -logf text -statd 15s -db mongodb://$(DOCKER_IP)/tasks

stop:
	@killall todolist

# -----------------------------------------------------------------
#        Docker targets
# -----------------------------------------------------------------

dockerBuild:
	docker build -t sfeir/todolist:latest .

dockerClean:
	docker rmi -f sfeir/todolist:latest

dockerUp:
	docker-compose up -d

dockerStop:
	docker-compose stop
	docker-compose kill
	docker-compose rm

dockerBuildUp: dockerStop dockerBuild dockerUp

dockerWatch:
	@watch -n1 'docker ps | grep todolist'

dockerLogs:
	docker-compose logs -f

.PHONY: all test clean teardownTest setupTest
