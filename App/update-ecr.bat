@echo off

set REPO_NAME=docker_ecr_repo
set TAG=docker_ecr_repo

for /f "tokens=*" %%i in ('aws sts get-caller-identity --query "Account" --output text') do set AWS_ACCOUNT_ID=%%i
for /f "tokens=*" %%i in ('aws configure get region') do set AWS_REGION=%%i

set ECR_REPO=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/%REPO_NAME%

aws ecr get-login-password --region "%AWS_REGION%" | docker login --password-stdin -u AWS "%ECR_REPO%"
docker build -t "%TAG%" .
docker tag "%TAG%:latest" "%ECR_REPO%:latest"
docker push "%ECR_REPO%:latest"
