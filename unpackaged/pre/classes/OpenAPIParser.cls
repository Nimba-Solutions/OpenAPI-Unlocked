/**
 * Utility class for parsing OpenAPI pseudo-annotations from Apex comments
 */
public with sharing class OpenAPIParser {
    
    public class OpenAPIParserException extends Exception {}
    
    /**
     * Parses OpenAPI information from a class's comments
     * @param className The name of the class to parse
     * @return Map<String, Object> containing the parsed OpenAPI information
     */
    public static Map<String, Object> parseClass(String className) {
        // Query the ApexClass sObject to get the actual class body
        List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :className LIMIT 1];
        if (classes.isEmpty()) {
            System.debug('No ApexClass found with name: ' + className);
            return null;
        }
        
        String classBody = classes[0].Body;
        System.debug('Class body length: ' + classBody.length());
        System.debug('First 200 chars of class body: ' + classBody.substring(0, Math.min(200, classBody.length())));
        
        Map<String, Object> result = new Map<String, Object>();
        
        // Extract class-level OpenAPI annotations
        Pattern classPattern = Pattern.compile('/\\*\\*\\s*\\n\\s*\\*\\s*@openapi\\s*\\n\\s*\\*\\s*@title\\s+(.*?)\\n\\s*\\*\\s*@description\\s+(.*?)\\n\\s*\\*\\s*@version\\s+(.*?)\\n\\s*\\*/');
        Matcher classMatcher = classPattern.matcher(classBody);
        
        if (classMatcher.find()) {
            System.debug('Found class-level OpenAPI annotation');
            Map<String, Object> info = new Map<String, Object>{
                'title' => classMatcher.group(1).trim(),
                'description' => classMatcher.group(2).trim(),
                'version' => classMatcher.group(3).trim()
            };
            result.put('info', info);
        } else {
            System.debug('No class-level OpenAPI annotation found');
        }
        
        // Extract method-level OpenAPI annotations
        Map<String, Object> paths = parseMethods(classBody);
        System.debug('Found paths: ' + JSON.serializePretty(paths));
        result.put('paths', paths);
        
        return result;
    }
    
    /**
     * Parses OpenAPI paths from method documentation
     * @param classBody The class body to parse
     * @return Map<String, Object> containing the paths section
     */
    private static Map<String, Object> parseMethods(String classBody) {
        Map<String, Object> paths = new Map<String, Object>();
        
        // Find all method documentation blocks
        Pattern methodPattern = Pattern.compile('/\\*\\*\\s*\\n\\s*\\*\\s*@openapi\\s*\\n(\\s*\\*\\s*@[^\\n]*\\n)*\\s*\\*/\\s*@(Http\\w+)\\s+.*?\\s+(\\w+)\\s*\\([^)]*\\)');
        Matcher methodMatcher = methodPattern.matcher(classBody);
        
        System.debug('Searching for methods with pattern: ' + methodPattern.pattern());
        
        while (methodMatcher.find()) {
            System.debug('Found method match at position: ' + methodMatcher.start());
            String methodDoc = methodMatcher.group(0);
            String httpMethod = methodMatcher.group(2).toLowerCase().replace('http', '');
            String methodName = methodMatcher.group(3);
            
            System.debug('Method name: ' + methodName);
            System.debug('HTTP method: ' + httpMethod);
            System.debug('Method doc: ' + methodDoc);
            
            Map<String, Object> pathInfo = parseMethod(methodDoc);
            if (!paths.containsKey(methodName)) {
                paths.put(methodName, new Map<String, Object>());
            }
            ((Map<String, Object>)paths.get(methodName)).put(httpMethod, pathInfo);
        }
        
        return paths;
    }
    
    /**
     * Parses a single method's OpenAPI documentation
     * @param doc The method documentation to parse
     * @return Map<String, Object> containing the method's OpenAPI information
     */
    private static Map<String, Object> parseMethod(String doc) {
        Map<String, Object> methodInfo = new Map<String, Object>();
        
        // Extract operation ID
        Pattern opPattern = Pattern.compile('@operation\\s+(\\w+)');
        Matcher opMatcher = opPattern.matcher(doc);
        if (opMatcher.find()) {
            methodInfo.put('operationId', opMatcher.group(1));
            System.debug('Found operation ID: ' + opMatcher.group(1));
        }
        
        // Extract summary
        Pattern summaryPattern = Pattern.compile('@summary\\s+(.*?)(?=\\n|$)');
        Matcher summaryMatcher = summaryPattern.matcher(doc);
        if (summaryMatcher.find()) {
            methodInfo.put('summary', summaryMatcher.group(1).trim());
            System.debug('Found summary: ' + summaryMatcher.group(1).trim());
        }
        
        // Extract description
        Pattern descPattern = Pattern.compile('@description\\s+(.*?)(?=\\n|$)');
        Matcher descMatcher = descPattern.matcher(doc);
        if (descMatcher.find()) {
            methodInfo.put('description', descMatcher.group(1).trim());
            System.debug('Found description: ' + descMatcher.group(1).trim());
        }
        
        // Extract tags
        List<String> tags = new List<String>();
        Pattern tagPattern = Pattern.compile('@tag\\s+(.*?)(?=\\n|$)');
        Matcher tagMatcher = tagPattern.matcher(doc);
        while (tagMatcher.find()) {
            tags.add(tagMatcher.group(1).trim());
            System.debug('Found tag: ' + tagMatcher.group(1).trim());
        }
        if (!tags.isEmpty()) {
            methodInfo.put('tags', tags);
        }
        
        // Extract security requirements
        List<Map<String, List<String>>> security = new List<Map<String, List<String>>>();
        Pattern securityPattern = Pattern.compile('@security\\s+(\\w+)(?:\\s+(.*?))?(?=\\n|$)');
        Matcher securityMatcher = securityPattern.matcher(doc);
        while (securityMatcher.find()) {
            String scheme = securityMatcher.group(1);
            String scopes = securityMatcher.group(2);
            Map<String, List<String>> securityItem = new Map<String, List<String>>();
            List<String> scopeList = new List<String>();
            if (scopes != null) {
                scopeList = scopes.split('\\s+');
            }
            securityItem.put(scheme, scopeList);
            security.add(securityItem);
            System.debug('Found security: ' + scheme + ' with scopes: ' + scopeList);
        }
        if (!security.isEmpty()) {
            methodInfo.put('security', security);
        }
        
        // Extract parameters
        List<Map<String, Object>> parameters = new List<Map<String, Object>>();
        Pattern paramPattern = Pattern.compile('@param\\s+(\\w+)\\s+(\\w+)\\s+(\\w+)\\s+(.*?)(?=\\n|$)');
        Matcher paramMatcher = paramPattern.matcher(doc);
        while (paramMatcher.find()) {
            Map<String, Object> param = new Map<String, Object>{
                'name' => paramMatcher.group(1),
                'in' => paramMatcher.group(2),
                'type' => paramMatcher.group(3),
                'description' => paramMatcher.group(4).trim(),
                'required' => true
            };
            parameters.add(param);
            System.debug('Found parameter: ' + JSON.serializePretty(param));
        }
        if (!parameters.isEmpty()) {
            methodInfo.put('parameters', parameters);
        }
        
        // Extract request body
        Pattern requestBodyPattern = Pattern.compile('@requestBody\\s+\\{(.*?)\\}(?=\\n|$)');
        Matcher requestBodyMatcher = requestBodyPattern.matcher(doc);
        if (requestBodyMatcher.find()) {
            String requestBodyJson = requestBodyMatcher.group(1);
            Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped('{' + requestBodyJson + '}');
            methodInfo.put('requestBody', requestBody);
            System.debug('Found request body: ' + JSON.serializePretty(requestBody));
        }
        
        // Extract responses
        Map<String, Object> responses = new Map<String, Object>();
        Pattern responsePattern = Pattern.compile('@response\\s+(\\d+)\\s+\\{(.*?)\\}(?=\\n|$)');
        Matcher responseMatcher = responsePattern.matcher(doc);
        while (responseMatcher.find()) {
            String code = responseMatcher.group(1);
            String responseJson = responseMatcher.group(2);
            Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped('{' + responseJson + '}');
            
            // If type is specified, add openApiSchema
            if (response.containsKey('type')) {
                String type = (String)response.get('type');
                Map<String, Object> openApiSchema = new Map<String, Object>();
                
                try {
                    // Get the SObject describe for the type
                    List<String> types = new List<String>{type};
                    List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(types);
                    
                    if (!results.isEmpty()) {
                        Schema.DescribeSObjectResult describe = results[0];
                        
                        // Build openApiSchema properties
                        Map<String, Object> properties = new Map<String, Object>();
                        for (Schema.SObjectField field : describe.fields.getMap().values()) {
                            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                            String fieldName = fieldDescribe.getName();
                            String fieldType = getOpenAPIType(fieldDescribe.getType());
                            
                            Map<String, Object> property = new Map<String, Object>{
                                'type' => fieldType
                            };
                            
                            if (fieldDescribe.getLabel() != null) {
                                property.put('description', fieldDescribe.getLabel());
                            }
                            
                            properties.put(fieldName, property);
                        }
                        
                        openApiSchema.put('type', 'object');
                        openApiSchema.put('properties', properties);
                        
                        response.put('content', new Map<String, Object>{
                            'application/json' => new Map<String, Object>{
                                'schema' => openApiSchema
                            }
                        });
                    }
                } catch (Exception e) {
                    System.debug('Error generating openapi schema for type ' + type + ': ' + e.getMessage());
                }
                
                // Remove type as it's not part of OpenAPI spec
                response.remove('type');
            }
            
            responses.put(code, response);
            System.debug('Found response: ' + code + ' - ' + JSON.serializePretty(response));
        }
        
        methodInfo.put('responses', responses);
        
        return methodInfo;
    }
    
    private static String getOpenAPIType(Schema.DisplayType fieldType) {
        switch on fieldType {
            when STRING, TEXTAREA, PICKLIST, MULTIPICKLIST, EMAIL, PHONE, URL, ID, REFERENCE {
                return 'string';
            }
            when INTEGER, CURRENCY, DOUBLE, PERCENT {
                return 'number';
            }
            when BOOLEAN {
                return 'boolean';
            }
            when DATE {
                return 'string';
            }
            when DATETIME {
                return 'string';
            }
            when else {
                return 'string';
            }
        }
    }
    
    /**
     * Stores the OpenAPI specification as a Static Resource
     * @param spec The OpenAPI specification to store
     * @param resourceName The name of the Static Resource
     */
    public static void storeAsStaticResource(Map<String, Object> spec, String resourceName) {
        // Convert spec to JSON string
        String jsonSpec = JSON.serializePretty(spec);
        
        // First try to get the existing Static Resource
        HttpRequest getReq = new HttpRequest();
        getReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/query?q=SELECT+Id+FROM+StaticResource+WHERE+Name=\'' + resourceName + '\'');
        getReq.setMethod('GET');
        getReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        
        Http http = new Http();
        HttpResponse getRes = http.send(getReq);
        
        String resourceId = null;
        if (getRes.getStatusCode() == 200) {
            Map<String, Object> queryResult = (Map<String, Object>)JSON.deserializeUntyped(getRes.getBody());
            List<Object> records = (List<Object>)queryResult.get('records');
            if (!records.isEmpty()) {
                Map<String, Object> record = (Map<String, Object>)records[0];
                resourceId = (String)record.get('Id');
            }
        }
        
        // Create or update the Static Resource
        HttpRequest req = new HttpRequest();
        if (resourceId != null) {
            // Update existing
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/StaticResource/' + resourceId);
            req.setMethod('PATCH');
        } else {
            // Create new
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/StaticResource');
            req.setMethod('POST');
        }
        
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        
        // Create the Static Resource body with correct field names
        Map<String, Object> body = new Map<String, Object>{
            'Name' => resourceName,
            'ContentType' => 'application/json',
            'CacheControl' => 'Public',
            'Metadata' => new Map<String, Object>{
                'content' => jsonSpec
            }
        };
        
        req.setBody(JSON.serialize(body));
        
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 201 && res.getStatusCode() != 204) {
            throw new OpenAPIParserException('Failed to ' + (resourceId != null ? 'update' : 'create') + ' Static Resource: ' + res.getBody());
        }
    }
    
    /**
     * Parses OpenAPI information from all classes in the default namespace
     * @return Map<String, Object> containing the combined OpenAPI information
     */
    public static Map<String, Object> parseClasses() {
        return parseClasses(null);
    }
    
    /**
     * Parses OpenAPI information from all classes in a namespace
     * @param namespace The namespace to parse (null for default namespace)
     * @return Map<String, Object> containing the combined OpenAPI information
     */
    public static Map<String, Object> parseClasses(String namespace) {
        // Query all Apex classes in the namespace
        String query = 'SELECT Id, Name, Body FROM ApexClass';
        if (namespace != null) {
            query += ' WHERE NamespacePrefix = :namespace';
        }
        List<ApexClass> classes = Database.query(query);
        
        System.debug('Found ' + classes.size() + ' classes in namespace: ' + (namespace == null ? 'default' : namespace));
        
        Map<String, Object> combinedSpec = new Map<String, Object>();
        Map<String, Object> combinedPaths = new Map<String, Object>();
        String combinedTitle = 'Salesforce REST API';
        String combinedDescription = 'Combined REST API documentation';
        String combinedVersion = '1.0.0';
        
        for (ApexClass apexClass : classes) {
            System.debug('Processing class: ' + apexClass.Name);
            Map<String, Object> classSpec = parseClass(apexClass.Name);
            
            if (classSpec != null) {
                // Merge info section
                if (classSpec.containsKey('info')) {
                    Map<String, Object> info = (Map<String, Object>)classSpec.get('info');
                    if (info.containsKey('title')) {
                        combinedTitle = (String)info.get('title');
                    }
                    if (info.containsKey('description')) {
                        combinedDescription = (String)info.get('description');
                    }
                    if (info.containsKey('version')) {
                        combinedVersion = (String)info.get('version');
                    }
                }
                
                // Merge paths
                if (classSpec.containsKey('paths')) {
                    Map<String, Object> paths = (Map<String, Object>)classSpec.get('paths');
                    for (String path : paths.keySet()) {
                        if (!combinedPaths.containsKey(path)) {
                            combinedPaths.put(path, paths.get(path));
                        } else {
                            // Merge HTTP methods for the same path
                            Map<String, Object> existingMethods = (Map<String, Object>)combinedPaths.get(path);
                            Map<String, Object> newMethods = (Map<String, Object>)paths.get(path);
                            for (String method : newMethods.keySet()) {
                                existingMethods.put(method, newMethods.get(method));
                            }
                        }
                    }
                }
            }
        }
        
        // Set the combined info
        combinedSpec.put('info', new Map<String, Object>{
            'title' => combinedTitle,
            'description' => combinedDescription,
            'version' => combinedVersion
        });
        
        // Set the combined paths
        combinedSpec.put('paths', combinedPaths);
        
        System.debug('Combined OpenAPI specification: ' + JSON.serializePretty(combinedSpec));
        
        // Store as Static Resource
        storeAsStaticResource(combinedSpec, 'openapi_spec');
        
        return combinedSpec;
    }
} 