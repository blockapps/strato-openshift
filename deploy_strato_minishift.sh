#!/usr/bin/env bash

# minishift v1.33.0+ba29431 compatible (recent at Apr 23rd 2019)

STRATO_VERSION=4.3.0

set -e

# SET PERMISSIONS FOR 'developer' USER
oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin developer

username=developer

PROJECT_NAME=${PROJECT_NAME:-strato}
PUBLIC_IP=$(minishift ip)
UI_PASSWORD=admin

if $(oc get project ${PROJECT_NAME} 2>&1 > /dev/null); then
  read -p "project \"${PROJECT_NAME}\" exists, delete? (y/n): " REMOVE
  if [[ ${REMOVE} = "y" ]]; then
    echo "Deleting the project - this may take up to few minutes..."
    oc delete project ${PROJECT_NAME}
  else
    echo "Project ${PROJECT_NAME} exists, please delete ('oc delete project ${PROJECT_NAME}') and re-run this script"
    exit 1
  fi
fi

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
docker pull registry-aws.blockapps.net:5000/blockapps-repo/vault-wrapper:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/strato:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/postgrest:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/nginx:${STRATO_VERSION}
docker pull registry-aws.blockapps.net:5000/blockapps-repo/prometheus:${STRATO_VERSION}
docker pull swaggerapi/swagger-ui:v3.22.1
docker pull redis:3.2
docker pull postgres:9.6
docker pull wurstmeister/zookeeper:3.4.6
docker pull wurstmeister/kafka:1.1.0

# SETUP IMAGES
export ocr_ip=$(minishift openshift registry)
docker login -u $(oc whoami) -p $(oc whoami -t) ${ocr_ip}

## tag images
for image in $(docker images --format {{.Repository}}:{{.Tag}} | grep registry-aws.blockapps.net:5000/blockapps-repo | grep ${STRATO_VERSION})
do
  image_name=${image##*/}              ## getting last part of the image name:tag
  image_name=${image_name%%:*}         ## extracting name from name:tag
  echo tag image: $image as ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-${image_name}:latest
  docker tag $image ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-${image_name}:latest
done

for image in swaggerapi/swagger-ui:v3.22.1 redis:3.2 postgres:9.6 wurstmeister/zookeeper:3.4.6 wurstmeister/kafka:1.1.0
do
 echo tag image: $image
 image_name=${image%%:*} # extracting name from name:tag

 if [ "$image" = "swaggerapi/swagger-ui:v3.22.1" ]; then
   image_name="swagger-ui"
   echo $image_name
 fi

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
for image in postgres redis zookeeper kafka smd apex dappstore bloc swagger-ui vault-wrapper strato postgrest nginx prometheus
do
  echo push image: $image
  docker push ${ocr_ip}/${PROJECT_NAME}/blockapps-strato-$image:latest
done

#STARTUP
#oc create -f blockapps.yml
