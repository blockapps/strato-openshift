# STRATO-OpenShift

These commands basically get the images from the BlockApps repo and then push them to OpenShift repo. Then we create a project called `strato` (the name is fixed for now) and spin up deployments.

## Openshift cluster

#### Domain name prerequsites
When running on custom domain name (not using `nip.io`) - add the `*.<subdomain>` record in your DNS settings (e.g. `*.openshift` in my `example.com` domain settings) to point to "OPENSHIFT INFRA LOAD BALANCER" IP address

#### Deploy STRATO 

1. ssh to OpenShift master node.

2. clone this repo and from the repo directory run:
 ```
 ./deploy_strato.sh
 ```

3. Follow the white rabbit.

## Minishift local

1. Run minishift VM, set docker and oc environment for the terminal session with commands:
 ```
 eval $(minishift oc-env)
 eval $(minishift docker-env)
 ```

2. clone this repo and from the repo directory run:
 ```
 ./deploy_strato_minishift.sh
 ```
 
Minishift console: `https://<Minishift_VM_IP_address>:8443`

Minishift dev user credentials: `developer/developer`

To get your STRATO node address:

- Choose your STRATO project -> Overview -> Expand the "nginx" deployment -> Check the route (should look like: `http://node-<project_name>.<Minishift_VM_IP_address>.nip.io`)

## Dashboard
Visit the nginx hostname in your browser to open STRATO Dashboard (in Openshift Console select `STRATO` project, then Applications > Routes).

Credentials to access the Dashboard:

Openshift cluster: `admin/<password_you_set_on_deployment>`

Minishift local (won't show your projects): `admin/admin` 
