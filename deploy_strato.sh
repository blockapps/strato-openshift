#!/usr/bin/env bash

STRATO_VERSION=3.0.0-SMDv0.4

set -e

read -p "Enter Openshift project name for the deployment (e.g. \"strato1\"): " PROJECT_NAME

read -p "Enter the Openshift username (the one you use to login to web console'): " USERNAME

read -sp "Enter the Openshift user password: " PASSWORD
echo "
"

read -p "Enter the cluster load balancer hostname (e.g. \"123.123.123.111.nip.io\" or \"openshift.example.com\"): " PUBLIC_HOSTNAME

read -sp "Enter the new password for STRATO dashboard access: " UI_PASSWORD
echo "
"

cp blockapps.tpl.yml blockapps.yml
sed -i -e 's/__project_name__/'"${PROJECT_NAME}"'/g' blockapps.yml
sed -i -e 's/__hostname__/'"${PUBLIC_HOSTNAME}"'/g' blockapps.yml
sed -i -e 's/__ui_password__/'"${UI_PASSWORD}"'/g' blockapps.yml

# GRANT PERMISSIONS, LOGIN
oc login -u system:admin
oc project default
oc adm policy add-scc-to-user anyuid -n ${PROJECT_NAME} -z default
oc adm policy add-role-to-user admin ${USERNAME}
# Unnecessary permissions - we keep here just in case
#oc adm policy add-role-to-user system:image-builder ${username}
#oc adm policy add-role-to-user system:registry ${username}

oc login -u ${USERNAME} -p ${PASSWORD}

oc new-project ${PROJECT_NAME}

#GET IMAGES
sudo docker login -u blockapps-repo -p P@ssw0rd registry-aws.blockapps.net:5000
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/smd:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/apex:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/dappstore:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/bloc:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/cirrus:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/strato:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/postgrest:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/nginx:${STRATO_VERSION}
sudo docker pull registry-aws.blockapps.net:5000/blockapps-repo/docs:${STRATO_VERSION}
sudo docker pull redis:3.2
sudo docker pull postgres:9.6
sudo docker pull spotify/kafka:latest

# SETUP IMAGES
export ocr_ip="$(oc get svc -n default | grep docker-registry | awk '{print $2}'):5000"
sudo docker login -u $(oc whoami) -p $(oc whoami -t) ${ocr_ip}

## tag images
for image in $(sudo docker images --format {{.Repository}}:{{.Tag}} | grep registry-aws.blockapps.net:5000/blockapps-repo | grep ${STRATO_VERSION})
do
  image_name=${image##*/}              ## getting last part of the image name:tag
  image_name=${image_name%%:*}         ## extracting name from name:tag
  echo tag image: $image as ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-${image_name}:latest
  sudo docker tag $image ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-${image_name}:latest
done

for image in redis:3.2 postgres:9.6 spotify/kafka:latest
do
 echo tag image: $image
 image_name=${image%%:*} # extracting name from name:tag

 if [ "$image" = "spotify/kafka:latest" ]; then
   image_name="kafka"
   echo $image_name
 fi

  sudo docker tag $image ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-$image_name:latest
done

#push images
for image in postgres redis kafka smd apex dappstore bloc docs cirrus strato nginx postgrest
do
  echo push image: $image
  sudo docker push ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-$image:latest
done

#STARTUP
oc create -f blockapps.yml