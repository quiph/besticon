build:
	go get github.com/mat/besticon/...

test_all: build test test_bench
	go test -v github.com/mat/besticon/besticon/iconserver

test:
	go test -v github.com/mat/besticon/ico
	go test -v github.com/mat/besticon/besticon
	go test -v github.com/mat/besticon/lettericon
	go test -v github.com/mat/besticon/colorfinder

test_race:
	go test -v -race github.com/mat/besticon/ico
	go test -v -race github.com/mat/besticon/besticon
	go test -v -race github.com/mat/besticon/besticon/iconserver
	go test -v -race github.com/mat/besticon/lettericon
	go test -v -race github.com/mat/besticon/colorfinder

test_bench:
	go test github.com/mat/besticon/lettericon -bench .
	go test github.com/mat/besticon/colorfinder -bench .

deploy:
	git push heroku master
	heroku config:set DEPLOYED_AT=`date +%s`

install:
	go get ./...

run_server:
	go build -o bin/iconserver ./besticon/iconserver
	PORT=3000 DEPLOYED_AT=`date +%s` HOST_ONLY_DOMAINS=* POPULAR_SITES=bing.com,github.com,instagram.com,reddit.com ./bin/iconserver

coverage_besticon:
	go test -coverprofile=coverage.out -covermode=count github.com/mat/besticon/besticon && go tool cover -html=coverage.out && unlink coverage.out

coverage_ico:
	go test -coverprofile=coverage.out -covermode=count github.com/mat/besticon/ico && go tool cover -html=coverage.out && unlink coverage.out

coverage_iconserver:
	go test -coverprofile=coverage.out -covermode=count github.com/mat/besticon/besticon/iconserver && go tool cover -html=coverage.out && unlink coverage.out

test_websites:
	go get ./...
	cat besticon/testdata/websites.txt | xargs -P 10 -n 1  besticon

minify_css:
	curl -X POST -s --data-urlencode 'input@besticon/iconserver/assets/main.css' http://cssminifier.com/raw > besticon/iconserver/assets/main-min.css

update_assets:
	go-bindata -pkg assets -ignore assets.go -o besticon/iconserver/assets/assets.go besticon/iconserver/assets/

gotags:
	gotags -tag-relative=true -R=true -sort=true -f="tags" -fields=+l .

#
## Building ##
#

clean:
	rm -rf bin/*
	rm -f iconserver*.zip

build_darwin_amd64:
	GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -a -installsuffix cgo -o bin/darwin_amd64/iconserver -ldflags "-X github.com/mat/besticon/besticon.BuildDate=`date +'%Y-%m-%d'`" github.com/mat/besticon/besticon/iconserver

build_linux_amd64:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -a -installsuffix cgo -o bin/linux_amd64/iconserver -ldflags "-X github.com/mat/besticon/besticon.BuildDate=`date +'%Y-%m-%d'`" ./besticon/iconserver

build_windows_amd64:
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -a -installsuffix cgo -o bin/windows_amd64/iconserver.exe -ldflags "-X github.com/mat/besticon/besticon.BuildDate=`date +'%Y-%m-%d'`" github.com/mat/besticon/besticon/iconserver

build_all_platforms: build_darwin_amd64 build_linux_amd64 build_windows_amd64
	find bin/ -type file | xargs file

github_package: clean build_all_platforms
	zip -o -j iconserver_darwin-amd64 bin/darwin_amd64/* Readme.markdown LICENSE
	zip -o -j iconserver_linux_amd64 bin/linux_amd64/* Readme.markdown LICENSE
	zip -o -j iconserver_windows_amd64 bin/windows_amd64/* Readme.markdown LICENSE
	file iconserver*.zip
	ls -alht iconserver*.zip

## Docker ##
push_to_docker: perform_ecr_login docker_build_image docker_push_image_latest

# prod should always be opinionated.
push_to_docker_prod: perform_ecr_login_prod docker_build_image_prod docker_push_images_all_prod

## Staging ##
perform_ecr_login:
	aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 892481148093.dkr.ecr.us-east-2.amazonaws.com/iconserver

docker_build_image:
	docker build -t iconserver:latest -t iconserver:`cat VERSION` .
	docker tag iconserver:latest 892481148093.dkr.ecr.us-east-2.amazonaws.com/iconserver:latest
	docker tag iconserver:`cat VERSION` 892481148093.dkr.ecr.us-east-2.amazonaws.com/iconserver:`cat VERSION`
	# docker build -t matthiasluedtke/iconserver:latest -t matthiasluedtke/iconserver:`cat VERSION` .

docker_push_images_all: docker_push_image_latest docker_push_image_version

docker_push_image_latest:
	docker push 892481148093.dkr.ecr.us-east-2.amazonaws.com/iconserver:latest

docker_push_image_version:
	docker push 892481148093.dkr.ecr.us-east-2.amazonaws.com/iconserver:`cat VERSION`

## Production ##
perform_ecr_login_prod:
	aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 892481148093.dkr.ecr.ap-south-1.amazonaws.com/iconserver
	
docker_build_image_prod:
	docker build -t iconserver:latest -t iconserver:`cat VERSION` .
	docker tag iconserver:latest 892481148093.dkr.ecr.ap-south-1.amazonaws.com/iconserver:latest
	docker tag iconserver:`cat VERSION` 892481148093.dkr.ecr.ap-south-1.amazonaws.com/iconserver:`cat VERSION`
	# docker build -t matthiasluedtke/iconserver:latest -t matthiasluedtke/iconserver:`cat VERSION` .

docker_push_images_all_prod: docker_push_image_latest_prod docker_push_image_version_prod

docker_push_image_latest_prod:
	docker push 892481148093.dkr.ecr.ap-south-1.amazonaws.com/iconserver:latest

docker_push_image_version_prod:
	docker push 892481148093.dkr.ecr.ap-south-1.amazonaws.com/iconserver:`cat VERSION`

# Other docker commands

docker_run:
	docker run -p 3000:8080 --env-file docker_run.env matthiasluedtke/iconserver:latest

new_release: bump_version rewrite-version.go git_tag_version

bump_version:
	vi VERSION

rewrite-version.go:
	echo "package besticon\n\n// Version string, same as VERSION, generated my Make\nconst VersionString = \"`cat VERSION`\"" > besticon/version.go

git_tag_version:
	git commit VERSION besticon/version.go -m "Release `cat VERSION`"
	git tag `cat VERSION`
