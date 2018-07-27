#!/usr/bin/env bash

STRATO_VERSION=3.1.2

set -e
set -x

# SET PERMISSIONS FOR 'developer' USER
oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin developer

username=developer

read -p "Enter Openshift project name for the deployment (e.g. \"strato1\"): " PROJECT_NAME

read -p "Enter minishift VM IP (e.g. 192.168.64.1):  " PUBLIC_IP

UI_PASSWORD=admin

cp blockapps.tpl.yml blockapps.yml
sed -i -e 's/__project_name__/'"${PROJECT_NAME}"'/g' blockapps.yml
# using nip.io to enable sub-domain wildcards for IP (like "*.111.222.123.123"):
sed -i -e 's/__hostname__/'"${PUBLIC_IP}"'.nip.io/g' blockapps.yml
sed -i -e 's/__ui_password__/'"${UI_PASSWORD}"'/g' blockapps.yml

#LOGIN
oc login -u ${username}

oc new-project ${PROJECT_NAME}

oc adm policy add-scc-to-user anyuid -n ${PROJECT_NAME} -z default
oc adm policy add-role-to-user system:image-builder ${username}
oc adm policy add-role-to-user system:registry ${username}
oc adm policy add-role-to-user admin ${username}
oc adm policy add-role-to-user cluster-admin ${username}

#GET IMAGES
docker login -u blockapps-repo -p P@ssw0rd registry-aws.blockapps.net:5000
docker pull registry-aws.blockapps.net:5000/blockapps-repo/smd:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/apex:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/dappstore:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/bloc:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/cirrus:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/strato:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/postgrest:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/nginx:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/docs:${STRATO_VERSION}
docker pull redis:3.2
docker pull postgres:9.6
sudo docker pull wurstmeister/zookeeper:3.4.6
sudo docker pull wurstmeister/kafka:1.1.0

# SETUP IMAGES
export ocr_ip="$(oc get svc -n default | grep docker-registry | awk '{print $2}'):5000"
docker login -u $(oc whoami) -p $(oc whoami -t) ${ocr_ip}

## tag images
for image in $(docker images --format {{.Repository}}:{{.Tag}} | grep registry-aws.blockapps.net:5000/blockapps-repo | grep ${STRATO_VERSION})
do
  image_name=${image##*/}              ## getting last part of the image name:tag
  image_name=${image_name%%:*}         ## extracting name from name:tag
  echo tag image: $image as ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-${image_name}:latest
  docker tag $image ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-${image_name}:latest
done

for image in redis:3.2 postgres:9.6 wurstmeister/zookeeper:3.4.6 wurstmeister/kafka:1.1.0
do
 echo tag image: $image
 image_name=${image%%:*} # extracting name from name:tag

  if [ "$image" = "wurstmeister/zookeeper:3.4.6" ]; then
   image_name="zookeeper"
   echo $image_name
 fi

 if [ "$image" = "wurstmeister/kafka:1.1.0" ]; then
   image_name="kafka"
   echo $image_name
 fi

  docker tag $image ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-$image_name:latest
done

#push images
for image in postgres redis zookeeper kafka smd apex dappstore bloc docs cirrus strato nginx postgrest
do
  echo push image: $image
  docker push ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-$image:latest
done

#STARTUP
oc create -f blockapps.yml