
current codes `dev_env_old` directory have some flaws and should be rewritten in `dev_env` directory.

it should be changed as follows.

## archiutecture

- Kubernetes namespace: datahub
  - detahub components
  - mysql, elasticsearch, kafka, zookeeper, neo4j - dedicated for datahub
- Kubernetes namespace: dataspoke
  - the solution that will be developped in the future
- Kubernetes namespace: dataspoke-example
  - datasources such as mysql, kafka that will be registered to datahub/dataspoke for testing in development phase

## write following items in dev_env directory

- README.md
  - a guide to install dev-env
- install scripts to do...
  - setup namespaces if not exists
  - setup environment variables that will be used both dev and production env setup
    - write .env file fo dev-environment
  - setup datahub in datahub namespaces
    - read datahub installation document and follow
    - fix datahub version to 1.3.0
    - kubernetes secrets if required.
    - including neo4j (neo4j is by default excluded. should be included)
- helm charts that will be executed by install scripts 

## note on the local minikube

- dev_env will be installed in the local minikube cluster and it's maximum capacity will be like: cpu 6, memory 16G, storage 150G
- total size of dev_env installations in datahub and dataspoke-example namespaces should be around 50% of the cluster capacity
