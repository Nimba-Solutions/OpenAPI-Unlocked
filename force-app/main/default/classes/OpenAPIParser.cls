/**
 * Utility class for parsing OpenAPI pseudo-annotations from Apex comments
 * Contains ONLY utility methods for parsing - no direct processing
 */
public with sharing class OpenAPIParser {
    
    public class OpenAPIParserException extends Exception {}
    
    // Schema registry to track all extracted type definitions
    // Without this, we would have to parse the same classes multiple times
    // and end up with a lot of duplicate definitions in the final OpenAPI spec
    public static Map<String, Map<String, Object>> schemaRegistry = new Map<String, Map<String, Object>>();
    
    /**
     * Entry point for generating full OpenAPI spec
     * Delegates to the batch process - no direct processing
     * @param namespace Optional namespace to filter classes
     * @return Map<String, Object> with batch job status
     */
    public static Map<String, Object> parseClasses(String namespace) {
        // Always use batch processing to avoid governor limits
        System.debug('Starting batch processing of Apex classes for OpenAPI documentation');
        Id batchJobId = Database.executeBatch(new OpenAPIParserBatch(namespace), 200);
        
        System.debug('Batch job started with ID: ' + batchJobId);
        System.debug('The OpenAPI specification will be generated asynchronously');
        System.debug('When complete, it will be available as a Static Resource named "OPENAPI_SPEC"');
        
        // Return an empty map since the actual processing happens asynchronously
        Map<String, Object> result = new Map<String, Object>{
            'status' => 'processing',
            'message' => 'OpenAPI specification generation started. Check Static Resources for OPENAPI_SPEC when complete.',
            'batchJobId' => batchJobId
        };
        
        return result;
    }
    
    /**
     * Overloaded method to support calling without a namespace
     */
    public static Map<String, Object> parseClasses() {
        return parseClasses(null);
    }
    
    /**
     * Parses a single method's OpenAPI documentation
     * @param doc The method documentation to parse
     * @return Map<String, Object> containing the method's OpenAPI information
     */
    public static Map<String, Object> parseMethod(String doc) {
        Map<String, Object> methodInfo = new Map<String, Object>();
        
        // Extract basic method info
        methodInfo.put('operationId', extractOperationId(doc));
        methodInfo.put('summary', extractSummary(doc));
        methodInfo.put('description', extractDescription(doc));
        
        // Extract tags
        List<String> tags = extractTags(doc);
        if (!tags.isEmpty()) {
            methodInfo.put('tags', tags);
        }
        
        // Extract security requirements
        List<Map<String, List<String>>> security = extractSecurity(doc);
        if (!security.isEmpty()) {
            methodInfo.put('security', security);
        }
        
        // Extract parameters
        List<Map<String, Object>> parameters = extractParameters(doc);
        if (!parameters.isEmpty()) {
            methodInfo.put('parameters', parameters);
        }
        
        // Extract request body - now with type references
        Map<String, Object> requestBody = extractRequestBody(doc);
        if (!requestBody.isEmpty()) {
            methodInfo.put('requestBody', requestBody);
        }
        
        // Extract responses - now with type references
        Map<String, Object> responses = extractResponses(doc);
        methodInfo.put('responses', responses);
        
        return methodInfo;
    }
    
    /**
     * Get the schema registry containing all extracted types
     * @return Map<String, Map<String, Object>> with type name to schema mapping
     */
    public static Map<String, Map<String, Object>> getSchemaRegistry() {
        return schemaRegistry;
    }
    
    /**
     * Reset the schema registry (used between batch runs)
     */
    public static void resetSchemaRegistry() {
        schemaRegistry = new Map<String, Map<String, Object>>();
    }
    
    /**
     * Register a schema in the central registry and return a reference
     * @param typeName The name of the type to register
     * @param typeDefinition The schema definition
     * @return Map<String, Object> reference to the schema
     */
    public static Map<String, Object> registerSchemaAndGetReference(String typeName, Map<String, Object> typeDefinition) {
        if (String.isBlank(typeName)) {
            return typeDefinition; // Can't register without a name
        }
        
        // Register only if not already registered
        if (!schemaRegistry.containsKey(typeName)) {
            // Debug message to track registration
            System.debug('Registering schema for ' + typeName);
            schemaRegistry.put(typeName, typeDefinition);
        } else {
            System.debug('Schema already registered for ' + typeName);
        }
        
        // Return a reference
        Map<String, Object> ref = new Map<String, Object>{
            '$ref' => '#/components/schemas/' + typeName
        };
        
        System.debug('Created schema reference: ' + ref.get('$ref'));
        return ref;
    }
    
    /**
     * Extract parameters from method documentation
     * @param doc The method documentation string
     * @return List of parameter objects
     */
    public static List<Map<String, Object>> extractParameters(String doc) {
        List<Map<String, Object>> parameters = new List<Map<String, Object>>();
        Pattern paramPattern = Pattern.compile('@param\\s+(\\w+)\\s+(\\w+)\\s+(\\w+)\\s+(.*?)(?=\\n|$)');
        Matcher paramMatcher = paramPattern.matcher(doc);
        while (paramMatcher.find()) {
            String paramName = paramMatcher.group(1);
            String paramIn = paramMatcher.group(2);
            String paramType = paramMatcher.group(3);
            String paramDesc = paramMatcher.group(4).trim();
            
            // Convert Apex type to OpenAPI type
            String openApiType = 'string'; // default
            if (paramType.equalsIgnoreCase('Boolean')) {
                openApiType = 'boolean';
            } else if (paramType.equalsIgnoreCase('Integer') || paramType.equalsIgnoreCase('Decimal') || paramType.equalsIgnoreCase('Double')) {
                openApiType = 'number';
            }
            
            Map<String, Object> param = new Map<String, Object>{
                'name' => paramName,
                'in' => paramIn,
                'required' => true,
                'description' => paramDesc,
                'schema' => new Map<String, Object>{
                    'type' => openApiType
                }
            };
            parameters.add(param);
        }
        return parameters;
    }
    
    /**
     * Extract operation ID from method documentation
     */
    public static String extractOperationId(String doc) {
        Pattern opPattern = Pattern.compile('@operation\\s+(\\w+)');
        Matcher opMatcher = opPattern.matcher(doc);
        return opMatcher.find() ? opMatcher.group(1) : null;
    }
    
    /**
     * Extract summary from method documentation
     */
    public static String extractSummary(String doc) {
        Pattern summaryPattern = Pattern.compile('@summary\\s+(.*?)(?=\\n|$)');
        Matcher summaryMatcher = summaryPattern.matcher(doc);
        return summaryMatcher.find() ? summaryMatcher.group(1).trim() : null;
    }
    
    /**
     * Extract description from method documentation
     */
    public static String extractDescription(String doc) {
        Pattern descPattern = Pattern.compile('@description\\s+(.*?)(?=\\n|$)');
        Matcher descMatcher = descPattern.matcher(doc);
        return descMatcher.find() ? descMatcher.group(1).trim() : null;
    }
    
    /**
     * Extract tags from method documentation
     */
    public static List<String> extractTags(String doc) {
        List<String> tags = new List<String>();
        Pattern tagPattern = Pattern.compile('@tag\\s+(.*?)(?=\\n|$)');
        Matcher tagMatcher = tagPattern.matcher(doc);
        while (tagMatcher.find()) {
            tags.add(tagMatcher.group(1).trim());
        }
        return tags;
    }
    
    /**
     * Extract security requirements from method documentation
     */
    public static List<Map<String, List<String>>> extractSecurity(String doc) {
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
        }
        return security;
    }
    
    /**
     * Extract responses from method documentation and register schemas
     * Always uses references instead of embedding schemas directly
     */
    public static Map<String, Object> extractResponses(String doc) {
        Map<String, Object> responses = new Map<String, Object>();
        Pattern responsePattern = Pattern.compile('@response\\s+(\\d+)\\s+\\{(.*?)\\}(?=\\n|$)');
        Matcher responseMatcher = responsePattern.matcher(doc);
        
        while (responseMatcher.find()) {
            String code = responseMatcher.group(1);
            String responseJson = responseMatcher.group(2);
            
            // Parse the JSON-like format into a Map
            Map<String, Object> response = new Map<String, Object>();
            Pattern fieldPattern = Pattern.compile('(\\w+):\\s*"([^"]*)"|(\\w+):\\s*\\{(.*?)\\}|(\\w+):\\s*(true|false)');
            Matcher fieldMatcher = fieldPattern.matcher(responseJson);
            
            while (fieldMatcher.find()) {
                String key = fieldMatcher.group(1) != null ? fieldMatcher.group(1) : 
                           (fieldMatcher.group(3) != null ? fieldMatcher.group(3) : fieldMatcher.group(5));
                String value = fieldMatcher.group(2) != null ? fieldMatcher.group(2) : 
                             (fieldMatcher.group(4) != null ? fieldMatcher.group(4) : fieldMatcher.group(6));
                response.put(key, value);
            }
            
            // If type is specified, add a schema reference
            if (response.containsKey('type')) {
                String typeName = (String)response.get('type');
                System.debug('Response schema type: ' + typeName);
                
                try {
                    // Check if this is a nested class
                    List<String> typeNameParts = typeName.split('\\.');
                    boolean isNestedClass = (typeNameParts.size() == 2);
                    
                    Map<String, Object> extractedSchema;
                    
                    // Extract and register the schema if needed
                    if (!schemaRegistry.containsKey(typeName)) {
                        if (isNestedClass) {
                            extractedSchema = extractNestedClassSchema(typeNameParts[0], typeNameParts[1]);
                        } else {
                            extractedSchema = extractClassSchema(typeName);
                        }
                        System.debug('Extracted schema for response type ' + typeName + ': ' + (extractedSchema != null));
                    }
                    
                    // Get a reference to the schema
                    Map<String, Object> schemaRef = registerSchemaAndGetReference(typeName, schemaRegistry.get(typeName));
                    
                    // Add the schema reference to the response
                    response.put('content', new Map<String, Object>{
                        'application/json' => new Map<String, Object>{
                            'schema' => schemaRef
                        }
                    });
                    
                    System.debug('Added schema reference for ' + typeName + ' to response ' + code);
                } catch (Exception e) {
                    System.debug('Error generating schema reference for type ' + typeName + ': ' + e.getMessage());
                }
                
                // Remove type as it's not part of OpenAPI spec
                response.remove('type');
            }
            
            responses.put(code, response);
        }
        return responses;
    }
    
    /**
     * Extract request body information and register schemas
     * Always uses references instead of embedding schemas directly
     */
    public static Map<String, Object> extractRequestBody(String doc) {
        Map<String, Object> requestBody = new Map<String, Object>();
        Pattern requestBodyPattern = Pattern.compile('@requestBody\\s+\\{([^}]*)\\}(?=\\n|$)');
        Matcher requestBodyMatcher = requestBodyPattern.matcher(doc);
        
        if (requestBodyMatcher.find()) {
            String requestBodyJson = requestBodyMatcher.group(1);
            Map<String, Object> parsedJson = parseJsonLikeStructure(requestBodyJson);
            
            // Create the base request body structure
            requestBody.put('required', true);
            requestBody.put('description', parsedJson.get('description'));
            
            // Create the content structure
            Map<String, Object> content = new Map<String, Object>();
            Map<String, Object> jsonContent = new Map<String, Object>();
            
            // If type is specified, extract schema and use a reference
            if (parsedJson.containsKey('type')) {
                String typeName = (String)parsedJson.get('type');
                System.debug('Request body schema type: ' + typeName);
                
                try {
                    // Check if this is a nested class
                    List<String> typeNameParts = typeName.split('\\.');
                    boolean isNestedClass = (typeNameParts.size() == 2);
                    
                    Map<String, Object> extractedSchema;
                    
                    // Extract and register the schema if needed
                    if (!schemaRegistry.containsKey(typeName)) {
                        if (isNestedClass) {
                            extractedSchema = extractNestedClassSchema(typeNameParts[0], typeNameParts[1]);
                        } else {
                            extractedSchema = extractClassSchema(typeName);
                        }
                        System.debug('Extracted schema for request body type ' + typeName + ': ' + (extractedSchema != null));
                    }
                    
                    // Get a reference to the schema
                    Map<String, Object> schemaRef = registerSchemaAndGetReference(typeName, schemaRegistry.get(typeName));
                    
                    jsonContent.put('schema', schemaRef);
                    content.put('application/json', jsonContent);
                    requestBody.put('content', content);
                    
                    System.debug('Added schema reference for ' + typeName + ' to request body');
                    return requestBody;
                } catch (Exception e) {
                    System.debug('Error generating schema for type ' + typeName + ': ' + e.getMessage());
                }
            } else if (parsedJson.containsKey('content')) {
                // If content is specified directly in the annotation, preserve it
                Map<String, Object> contentJson = (Map<String, Object>)parsedJson.get('content');
                if (contentJson.containsKey('application/json')) {
                    Map<String, Object> jsonSchemaObj = (Map<String, Object>)((Map<String, Object>)contentJson.get('application/json')).get('schema');
                    if (jsonSchemaObj != null) {
                        jsonContent.put('schema', jsonSchemaObj);
                        content.put('application/json', jsonContent);
                        requestBody.put('content', content);
                        return requestBody;
                    }
                }
            }
            
            // If we get here, create an empty schema
            Map<String, Object> emptySchemaObj = new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>()
            };
            jsonContent.put('schema', emptySchemaObj);
            content.put('application/json', jsonContent);
            requestBody.put('content', content);
        }
        
        return requestBody;
    }
    
    public static Map<String, Object> extractClassSchema(String className) {
        // First check if this schema is already in the registry
        if (schemaRegistry.containsKey(className)) {
            System.debug('Using previously registered schema for ' + className);
            return schemaRegistry.get(className);
        }
        
        Map<String, Object> schemaObj = new Map<String, Object>();
        
        try {
            // First try to get the SObject describe for the type
            List<String> types = new List<String>{className};
            List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(types);
            
            if (!results.isEmpty()) {
                // This is an SObject
                Map<String, Object> properties = extractSObjectProperties(results[0]);
                if (!properties.isEmpty()) {
                    schemaObj.put('type', 'object');
                    schemaObj.put('properties', properties);
                    
                    // Always register the schema
                    System.debug('Registering SObject schema for ' + className);
                    schemaRegistry.put(className, schemaObj);
                    
                    return schemaObj;
                }
            } 
        } catch (Exception e) {
            // Not an SObject, try Apex class
            List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :className LIMIT 1];
            if (!classes.isEmpty()) {
                Map<String, Object> properties = extractPropertiesFromClassBody(classes[0].Body);
                if (!properties.isEmpty()) {
                    schemaObj.put('type', 'object');
                    schemaObj.put('properties', properties);
                    
                    // Always register the schema
                    System.debug('Registering Apex class schema for ' + className);
                    schemaRegistry.put(className, schemaObj);
                    
                    return schemaObj;
                }
            }
        }
        
        System.debug('WARNING: Could not extract schema for ' + className);
        
        // If we couldn't extract anything, create a minimal schema
        // This avoids broken references in the OpenAPI spec
        if (schemaObj.isEmpty()) {
            schemaObj.put('type', 'object');
            schemaObj.put('properties', new Map<String, Object>());
            schemaObj.put('description', 'Schema could not be extracted for type: ' + className);
            
            // Register even the minimal schema
            schemaRegistry.put(className, schemaObj);
        }
        
        return schemaObj;
    }
    
    public static Map<String, Object> extractNestedClassSchema(String outerClassName, String innerClassName) {
        Map<String, Object> schemaObj = new Map<String, Object>();
        String fullClassName = outerClassName + '.' + innerClassName;
        
        // First check if this schema is already registered
        if (schemaRegistry.containsKey(fullClassName)) {
            System.debug('Using already registered schema for ' + fullClassName);
            return schemaRegistry.get(fullClassName);
        }
        
        // Find the outer class
        List<ApexClass> classes = [SELECT Id, Body FROM ApexClass WHERE Name = :outerClassName LIMIT 1];
        if (!classes.isEmpty()) {
            String classBody = classes[0].Body;
            
            // Find the inner class definition
            Pattern innerClassPattern = Pattern.compile('(?:public|global|private|protected)?\\s+class\\s+' + innerClassName + '\\s*\\{([^}]*?)\\}');
            Matcher innerClassMatcher = innerClassPattern.matcher(classBody);
            
            if (innerClassMatcher.find()) {
                String innerClassBody = innerClassMatcher.group(1);
                Map<String, Object> properties = extractPropertiesFromClassBody(innerClassBody);
                if (!properties.isEmpty()) {
                    schemaObj.put('type', 'object');
                    schemaObj.put('properties', properties);
                    
                    // Register this nested class schema
                    System.debug('Registering nested class schema for ' + fullClassName);
                    schemaRegistry.put(fullClassName, schemaObj);
                    
                    return schemaObj;
                }
            }
        }
        
        System.debug('WARNING: Could not extract schema for nested class ' + fullClassName);
        return schemaObj;
    }
    
    public static Map<String, Object> extractSObjectProperties(Schema.DescribeSObjectResult describe) {
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
        
        return properties;
    }
    
    public static Map<String, Object> parseJsonLikeStructure(String json) {
        Map<String, Object> result = new Map<String, Object>();
        
        // Remove outer braces if present
        json = json.trim();
        if (json.startsWith('{') && json.endsWith('}')) {
            json = json.substring(1, json.length() - 1).trim();
        }
        
        // Split into key-value pairs
        List<String> pairs = new List<String>();
        Integer braceCount = 0;
        Integer startPos = 0;
        
        for (Integer i = 0; i < json.length(); i++) {
            String c = json.substring(i, i + 1);
            if (c == '{') braceCount++;
            if (c == '}') braceCount--;
            if (c == ',' && braceCount == 0) {
                pairs.add(json.substring(startPos, i).trim());
                startPos = i + 1;
            }
        }
        if (startPos < json.length()) {
            pairs.add(json.substring(startPos).trim());
        }
        
        for (String pair : pairs) {
            if (pair.contains(':')) {
                List<String> parts = pair.split(':', 2);
                String key = parts[0].trim();
                String value = parts[1].trim();
                
                // Remove quotes if present
                if (value.startsWith('"') && value.endsWith('"')) {
                    value = value.substring(1, value.length() - 1);
                }
                
                // Handle nested objects
                if (value.startsWith('{') && value.endsWith('}')) {
                    result.put(key, parseJsonLikeStructure(value));
                } else {
                    result.put(key, value);
                }
            }
        }
        
        return result;
    }
    
    public static String getOpenAPIType(Schema.DisplayType fieldType) {
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
     * Extract the URL mapping from @RestResource annotation
     * @param classBody The class body to inspect
     * @return The URL mapping string or empty string if not found
     */
    public static String extractRestResourceUrlMapping(String classBody) {
        Pattern restResourcePattern = Pattern.compile('@RestResource\\s*\\(\\s*urlMapping\\s*=\\s*[\'"]([^\'"]*)[\'"]\\s*\\)');
        Matcher matcher = restResourcePattern.matcher(classBody);
        if (matcher.find()) {
            String urlMapping = matcher.group(1);
            System.debug('Found REST resource URL mapping: ' + urlMapping);
            // Remove trailing /* if present
            if (urlMapping.endsWith('/*')) {
                urlMapping = urlMapping.substring(0, urlMapping.length() - 2);
            }
            // Ensure it starts with /
            if (!urlMapping.startsWith('/')) {
                urlMapping = '/' + urlMapping;
            }
            return urlMapping;
        }
        return '';
    }
    
    /**
     * Utility method to construct RESTful API paths based on method information
     * @param baseUrlMapping The base URL mapping from @RestResource
     * @param httpMethod The HTTP method (get, post, put, delete)
     * @param methodName The method name
     * @param pathParams List of path parameter names
     * @return Properly formatted RESTful API path
     */
    public static String constructApiPath(String baseUrlMapping, String httpMethod, String methodName, List<String> pathParams) {
        // Format path according to true RESTful API standards
        String path = baseUrlMapping;
        
        // Extract resource name from the baseUrlMapping
        // This gives us the resource type (e.g., "account" or "contact")
        String resourceName = '';
        if (String.isNotBlank(baseUrlMapping)) {
            List<String> pathParts = baseUrlMapping.split('/');
            if (pathParts.size() > 0) {
                resourceName = pathParts[pathParts.size() - 1];
            }
        }
        
        // Apply RESTful patterns based on HTTP method and method name
        if (httpMethod == 'get') {
            if (methodName.toLowerCase().startsWith('get') && pathParams.size() == 1) {
                // GET single resource by ID: /resource/{id}
                path = path + '/{' + pathParams[0] + '}';
            } else if (methodName.toLowerCase().startsWith('list') || 
                       methodName.toLowerCase().startsWith('getall') ||
                       methodName.toLowerCase().startsWith('findall')) {
                // GET collection: /resource
                // Path already has the base resource path
            } else if (methodName.toLowerCase().contains('by')) {
                // GET with filter: /resource/by{Field}/{value}
                String[] parts = methodName.split('(?i)by');
                if (parts.size() > 1 && pathParams.size() > 0) {
                    path = path + '/by' + parts[1] + '/{' + pathParams[0] + '}';
                } else {
                    // Fallback: use method name as a subresource
                    path = path + '/' + methodName;
                    for (String paramName : pathParams) {
                        path = path + '/{' + paramName + '}';
                    }
                }
            } else {
                // For other GET operations, use method name as subresource
                path = path + '/' + methodName;
                for (String paramName : pathParams) {
                    path = path + '/{' + paramName + '}';
                }
            }
        } else if (httpMethod == 'post') {
            if (methodName.toLowerCase().startsWith('create')) {
                // POST to create: /resource (no method name needed)
                // Path already has the base resource path
            } else {
                // For other POST operations (actions/procedures)
                path = path + '/' + methodName;
                for (String paramName : pathParams) {
                    path = path + '/{' + paramName + '}';
                }
            }
        } else if (httpMethod == 'put' || httpMethod == 'patch') {
            if (methodName.toLowerCase().startsWith('update') && pathParams.size() > 0) {
                // PUT/PATCH to update: /resource/{id} (no method name needed)
                path = path + '/{' + pathParams[0] + '}';
            } else {
                // For other update operations
                path = path + '/' + methodName;
                for (String paramName : pathParams) {
                    path = path + '/{' + paramName + '}';
                }
            }
        } else if (httpMethod == 'delete') {
            if (methodName.toLowerCase().startsWith('delete') && pathParams.size() > 0) {
                // DELETE: /resource/{id} (no method name needed)
                path = path + '/{' + pathParams[0] + '}';
            } else {
                // For other delete operations
                path = path + '/' + methodName;
                for (String paramName : pathParams) {
                    path = path + '/{' + paramName + '}';
                }
            }
        } else {
            // For all other operations
            path = path + '/' + methodName;
            for (String paramName : pathParams) {
                path = path + '/{' + paramName + '}';
            }
        }
        
        return path;
    }
    
    /**
     * Stores the OpenAPI specification as a Static Resource
     * @param spec The OpenAPI specification to store
     * @param resourceName The name of the Static Resource
     */
    public static void storeAsStaticResource(Map<String, Object> spec, String resourceName) {
        // Delegate to the queueable class to avoid mixed DML operations
        System.enqueueJob(new OpenAPIStorageQueueable(spec, resourceName));
    }
    
    public static Map<String, Object> extractPropertiesFromClassBody(String classBody) {
        Map<String, Object> properties = new Map<String, Object>();
        Pattern propertyPattern = Pattern.compile('(public|global)\\s+(\\w+)\\s+(\\w+)\\s*;');
        Matcher propertyMatcher = propertyPattern.matcher(classBody);
        
        while (propertyMatcher.find()) {
            String fieldType = propertyMatcher.group(2);
            String fieldName = propertyMatcher.group(3);
            
            // Convert Apex type to OpenAPI type
            String openApiType = 'string';
            if (fieldType.equalsIgnoreCase('Boolean')) {
                openApiType = 'boolean';
            } else if (fieldType.equalsIgnoreCase('Integer') || fieldType.equalsIgnoreCase('Decimal') || fieldType.equalsIgnoreCase('Double')) {
                openApiType = 'number';
            }
            
            properties.put(fieldName, new Map<String, Object>{
                'type' => openApiType
            });
        }
        
        return properties;
    }
}