# Solution Concept of MetaPub

## What this is? Why this has come?

- A metadata registry or data catalog with powerful extended features CUSTOMIZED for our company
  - Customized UX for our main use cases
  - Customized data availability criteria that we use
  - Customized data governance criteria that we use
  - Customized verification API for our AI-automated pipeline development

Customized UX can be created for various data users e.g. pipeline developers
and domain analysts. Meanwhile generic tools such as DataHub, Open-Metadata or Atlas offers
UXs that focuses on omni-functionality throughout all domains and result in sub-optimal UX for
most users. 

Some companies have data-mesh style data architecture where several domain-specific data-pipelines 
are operated other than the one by central data-engineering team. For example, While DE team 
operates large-scale cost-effective pipeline with various expert tools like Flink and Spark. 
Business Teams operates simple periodic SQL callers or even manualy updated tables.
This means that not only the data consumption experience, but also the data production experience
can be customized for best user experience. And it is very hard for generic solution to offer
both simple usability and deep information.

Things are becoming more complicated because AI-coding SHOULD be introduced. AI coding in data
pipeline requires 2-fold change in data infrastucture. Firstly, the access control and dev/prod 
environment architecture should be overhauled to support AI agents to do their jobs without ruining 
data pipeline. Secondly, a new infrastructure is required to validate data developed by AI agents
without scanning all previous data or writing all anomaly-detection models for each time the 
pipeline is modified. This second role is most likely to be covered by extending functionality of
metadata registry(or data catalog). Generalization in this aspect? This will be very hard to
achieve.

(Footnote. Some companies are already implementing this customization although sometimes they are not called 
data catalog. Sometimes they are called customer data platform(CDP) although it is in fact closer to 
the concept of metadata registry rather than the real CDP. Sometimes, the implementation is called 
feature store although it is in fact closer to metadata registry again.)

In conclusion, a perfect generalization is not achievable, in fact, previous solutions that
pursue generality are not even close to the 'good' level for individual companies. So, if 
customization is possible, it should be done. and nowadays, even small companies can have luxary
of building customized solution using AI coding.

## Who uses this? (Use Cases)

- Data analysts and AI(DA)-agents can use this as data catalog
  - Schema, column meanings
  - Relationship between datasets (ancestors and descendants in lineage)
  - Data availability in various metric (date ranges, product types, user cohorts, ...)
  - Data statistics and samples (mean and sd for numeric variables, cardinality and entropy for categorical columns)
  - SQL samples (e.g. frequently used standard SQL from SQL-engine logs)
- Data engineers and stewards will use this as data availability monitor
  - To set data arrival frequency and quantity check rules and monitor
  - To check usage statistics
- Data engineers and stewards will use this as data consistency and integrity monitor
  - To set column-specific quality check rules and monitor
  - To set timeseries anomaly detection rules on timeseries data
- Data engineers and AI(DE)-agents can use this as data-pipeline validation side-note
  - To check the modified pipeline's result is consistent with previous samples
  - To check the modified pipeline's result is within boundary of checking rules
- Information security 
  - To monitor about access levels
  - To monitor about Privacy levels of data

# How is this designed?

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