# SQLServerFTSAnalyzer

This procedure is intended to gather information about all full-text catalogs on a database instance into a single table. This makes it easier to diagnose problems with FTS directories. An additional function of this procedure is the ability to generate content to create metrics for the Dynatrace application.

## Sample results
![image](https://user-images.githubusercontent.com/39556305/221586641-60ca88ce-fc00-4ea9-8dc2-78f0e48d2c01.png)

## Dynatrace output - parameter @DynatraceOutput = 1
![image](https://user-images.githubusercontent.com/39556305/221587413-c05679c7-ac6d-4633-aeb2-9406e919509e.png)

## An example dashboard in Dynatrace
![image](https://user-images.githubusercontent.com/39556305/221588119-0fe98305-b550-432d-8a48-f6e3772577d9.png)
