Basic thought on FE, API and BE

- Strict of separation of frontend, backend and API.
  - API will be RESTful API or GraphQL
  - Although API documentation can be offered as a side-product of BE. It should also be standalone
    in a separated directory. This is for two reasons: First, to facilitate the coding and checking 
    iteration of AI agents. Second, to build a sample API documentation without mocking API server.
- For backend, python API server is preferred.
  - It is because of its rubustness in accessing various data storage types and using various 
    statistic models that can be used in data validations.
- For frontend, typescript-based frameworks (e.g. next.js) are preffered.
  - Because they are popular.
  - Chart libraries (e.g. Highcharts) should be used to display charts.

Thought on integration with other systems: orchestration, storage, communication

- Backend Framework: Python (FastAPI)
- Orchestration: Temporal (workflow mgmt) or Airflow
- DataHub Communication: DataHub Python SDK (acryl-datahub)
- Vector DB: Qdrant or Weaviate
- Message Broker: Kafka (subscription to DataHub's change event)

Thought on final repo structure

- based on the spec, the repository root directory have following directories
  - `docker-images`: build custom docker images to avoid countinus downloading from public dockerhub
  - `helm-charts`: install the whole system in a kubernetes cluster e.g. EKS
  - `docs`: installation and operation guide
  - `api`: standalone api documentation
  - `src`: source codes in various programming languages
  - ...
