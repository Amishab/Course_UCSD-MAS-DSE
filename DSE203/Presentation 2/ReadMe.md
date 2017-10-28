# Presentation 2 

### Data Exploration: 
* Describe the Data Exploration API that you support. 
* Give use cases from the other groups that would use them. 
* The exploration API should be per source and cover all sources.

* Your task by the end of the quarter will be to give multiple Python APIs to other teams (query capability and ML teams to be specific) using which they can explore the data. 
* You will be computing a whole bunch of aggregate functions, in addition to other statistical queries such as those related to sampling and creating histograms. The output of your team is an API available to other teams.
* The expectation for the next presentation is to have at least a few APIs ready that others can use. You can try to create a list of functions that you plan on supporting. This might not be exhaustive.
* Note that the visualizations are not really required but may be used as "hyper" unit tests, or for suggesting features to the ML team, but this comes in later and will only be an add-on for your team.

### Schema Integration: 
* Present the Integrated Schema that would support the ML Group. 
* List sample integrated queries and your plan of supporting them.

* Give the concrete integrated schema and justify why you chose this schema. Provide an ER diagram, maybe? Note that there can be multiple kinds of final target schemas. Come up with all such global schemas for different use-cases. You need to make sure that the proposed schemas are computable.
* You may add new calculations while computing the target schema. For example, you may want to help by converting a string column having the comma-separated pair of "Latitude, Longitude" to two different columns, both of float type. Again, this is just an example.
* Define all the mappings and start documenting them. This would be stuff like "Product ID in Postgres maps to PID" in the final integrated schema. Many of these mappings will not be simple and generic, including the one for example above.
* Work with Query Processing/Capability team to provide some complex queries that you want to execute on the data. This may come from the ML team, or you may propose a few. Also, define how you would decompose these complex queries into multiple queries (say, into 3 simpler queries).

### Query Processing: 
* Take the integrated queries described in the previous point and logically break them up into queries against the sources.
* Work with the integrated schema team and get the high-level query. This can be something like - "Get all features for products in the category Education".
* You may not have the features right now, so that is fine. From the set of decomposed queries, you must decide which query goes into which data source. Note that these queries can be dependent or independent of each other. Dependent queries will require a joining mechanism which may have to take place in an in-memory database. 
* Try to come up with various nested queries (by talking to the integrated schema team, and by yourselves). Make sure to cover diverse use-cases.
* Your next job (for next presentation) will be to write database wrappers. This is the planning and architecture formation for it. We can talk about it after the next lecture. 

### Machine Learning: 
* What queries do you have on the integrated schema? 
* What processing are you doing yourself? 
* What is the implementation architecture?

* Discuss the architecture that you plan on using, in addition to the points stated previously in this post.
* How would you make the ML task scalable?
* What are the training/testing regimes (eg - k-fold validations) that you are looking to incorporate?
* Provide queries to the integrated schema team. Also, make sure you know how you want the data (do you need training, validation, test sets or do you just need one training set and then will do k-fold validation on it?), the sampling you are going to use etc.
